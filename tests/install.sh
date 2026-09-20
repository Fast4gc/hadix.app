#!/usr/bin/env bash
# Testes isolados: nao instalam pacotes nem escrevem nos caminhos da VPS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_DIR"' EXIT
export FIXTURE="$TEST_DIR/source"
mkdir -p "$FIXTURE" "$TEST_DIR/mock"
cp -R "$ROOT/bootstrap" "$ROOT/commands" "$ROOT/installers" "$FIXTURE/"
cp "$ROOT/VERSION" "$ROOT/install.sh" "$FIXTURE/"
echo preserved > "$FIXTURE/.hidden"
for tool in id dnf; do
    printf '#!/usr/bin/env bash\necho 0\n' > "$TEST_DIR/mock/$tool"
done
cat > "$TEST_DIR/mock/git" <<'MOCK'
#!/usr/bin/env bash
if [ "${FAIL_DOWNLOAD:-0}" = 1 ]; then exit 1; fi
cp -R "$FIXTURE" "${@: -1}"
MOCK
cat > "$TEST_DIR/mock/curl" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$TEST_DIR/mock/"*
export PATH="$TEST_DIR/mock:$PATH"

for scenario in fresh reinstall failed_download; do
    install_dir="$TEST_DIR/$scenario"
    mkdir -p "$install_dir/config" "$install_dir/bin"
    if [ "$scenario" != fresh ]; then
        echo '{"existing":{"type":"bot"}}' > "$install_dir/config/apps.json"
        echo previous > "$install_dir/previous"
        echo 'Hadix AI — gerenciador do backend' > "$install_dir/other-project"
        ln -s "$install_dir/other-project" "$install_dir/bin/hadix"
        ln -s "$install_dir/other-project" "$install_dir/bin/bootstrap"
    fi
    # Substitui apenas destinos fixos; o fluxo executado e o instalador real.
    sed -e "s|/opt/oracle-bootstrap|$install_dir|g" \
        -e "s|/usr/local/bin|$install_dir/bin|g" \
        -e "s|/var/www|$install_dir/www|g" \
        -e "s|/var/log/oracle-bootstrap|$install_dir/log|g" \
        "$ROOT/install.sh" > "$TEST_DIR/install.sh"
    export FAIL_DOWNLOAD=0
    [ "$scenario" != failed_download ] || export FAIL_DOWNLOAD=1
    if bash "$TEST_DIR/install.sh" </dev/null > "$TEST_DIR/output" 2>&1; then
        [ "$scenario" != failed_download ]
        test -f "$install_dir/bootstrap/bootstrap.sh"
        test -f "$install_dir/.hidden"
        test -x "$install_dir/bin/bootstrap"
        test -f "$install_dir/bin/hadix"
        test ! -L "$install_dir/bin/hadix"
        cmp "$install_dir/bin/bootstrap" "$install_dir/bin/hadix"
        cmp "$install_dir/bin/bootstrap" "$install_dir/bin/hadix-app"
        grep -q 'bootstrap/bootstrap.sh' "$install_dir/bin/hadix"
        test "$(cat "$install_dir/config/nodes.json")" = '[]'
        test "$(cat "$install_dir/config/plans.json")" = '{}'
    else
        if [ "$scenario" != failed_download ]; then
            cat "$TEST_DIR/output"
            exit 1
        fi
        grep -q 'Hadix AI' "$install_dir/bin/bootstrap"
    fi
    if [ "$scenario" != fresh ]; then
        test "$(cat "$install_dir/config/apps.json")" = '{"existing":{"type":"bot"}}'
        test "$(cat "$install_dir/previous")" = previous
        test "$(cat "$install_dir/other-project")" = 'Hadix AI — gerenciador do backend'
    fi
    echo "OK: $scenario"
done
