#!/usr/bin/env bash
# install.sh — instalador principal do oracle-bootstrap
#
# Uso remoto:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Fast4gc/hadix.app/main/install.sh)
#   bash <(wget -qO- https://raw.githubusercontent.com/Fast4gc/hadix.app/main/install.sh)
set -euo pipefail

REPO_URL="https://github.com/Fast4gc/hadix.app.git"
OB_HOME="/opt/oracle-bootstrap"
BIN_LINK="/usr/local/bin/bootstrap"
HADIX_LINK="/usr/local/bin/hadix"

# --- checagens iniciais -----------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Este instalador precisa ser executado como root (use sudo)." >&2
    exit 1
fi

echo "=========================================="
echo "  Hadix.app — instalador"
echo "=========================================="
echo ""

# --- detecta gerenciador de pacotes -----------------------------------------
if command -v dnf >/dev/null 2>&1; then PKG="dnf"
elif command -v yum >/dev/null 2>&1; then PKG="yum"
elif command -v apt-get >/dev/null 2>&1; then PKG="apt-get"
else
    echo "Gerenciador de pacotes nao suportado. Suportado: dnf, yum, apt-get." >&2
    exit 1
fi

echo "==> Atualizando indices de pacotes..."
if [ "$PKG" = "apt-get" ]; then
    apt-get update -qq
fi

echo "==> Instalando dependencias base (git, curl, wget, jq, unzip)..."
case "$PKG" in
    dnf|yum) $PKG install -y git curl wget jq unzip tar >/dev/null ;;
    apt-get) apt-get install -y git curl wget jq unzip tar >/dev/null ;;
esac

# --- baixa/atualiza o repositorio -------------------------------------------
if [ -d "$OB_HOME/.git" ]; then
    echo "==> Instalacao existente encontrada, atualizando..."
    git -C "$OB_HOME" pull --ff-only
else
    echo "==> Clonando Hadix.app para ${OB_HOME}..."
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf -- "$TMP_DIR"' EXIT
    SRC_DIR="$TMP_DIR/source"
    if ! git clone --depth 1 "$REPO_URL" "$SRC_DIR"; then
        echo "==> git clone falhou, baixando ZIP do branch main..."
        TMP_ZIP="$TMP_DIR/hadix.zip"
        curl -fsSL "https://github.com/Fast4gc/hadix.app/archive/refs/heads/main.zip" -o "$TMP_ZIP"
        unzip -q "$TMP_ZIP" -d "$TMP_DIR"
        SRC_DIR="$TMP_DIR/hadix.app-main"
    fi
    # Valida o download antes de tocar na instalacao existente.
    for required in bootstrap/bootstrap.sh bootstrap/config.sh VERSION; do
        if [ ! -f "$SRC_DIR/$required" ]; then
            echo "Download incompleto: faltando $required. Instalacao anterior preservada." >&2
            exit 1
        fi
    done
    mkdir -p "$OB_HOME"
    # config/ e estado da VPS: nunca substituir durante uma reinstalacao.
    # tar inclui os dotfiles, que eram perdidos no fallback ZIP.
    tar -C "$SRC_DIR" --exclude=./config -cf - . | tar -C "$OB_HOME" -xf -
fi

chmod +x "$OB_HOME"/*.sh
chmod +x "$OB_HOME"/bootstrap/*.sh
chmod +x "$OB_HOME"/installers/*.sh
chmod +x "$OB_HOME"/commands/*.sh

# --- symlink global ----------------------------------------------------------
echo "==> Criando comandos globais 'bootstrap', 'hadix' e 'hadix-app'..."
mkdir -p "$(dirname "$BIN_LINK")"
# Substitui o comando em si, sem escrever no destino de links de outro projeto.
for command_path in "$BIN_LINK" "$HADIX_LINK" "$(dirname "$BIN_LINK")/hadix-app"; do
WRAPPER_TMP="$(mktemp "${command_path}.XXXXXX")"
cat > "$WRAPPER_TMP" << WRAPPER
#!/usr/bin/env bash
export OB_HOME="${OB_HOME}"
exec bash "${OB_HOME}/bootstrap/bootstrap.sh" "\$@"
WRAPPER
chmod 755 "$WRAPPER_TMP"
mv -fT "$WRAPPER_TMP" "$command_path"
done

# --- config inicial -----------------------------------------------------------
mkdir -p "$OB_HOME/config" /var/www /var/log/oracle-bootstrap
for f in apps users domains plans; do
    [ -f "$OB_HOME/config/${f}.json" ] || echo '{}' > "$OB_HOME/config/${f}.json"
done
[ -f "$OB_HOME/config/nodes.json" ] || echo '[]' > "$OB_HOME/config/nodes.json"

# --- arquivo de versao --------------------------------------------------------
if [ -f "$OB_HOME/VERSION" ]; then
    OB_VERSION="$(tr -d '[:space:]' < "$OB_HOME/VERSION")"
else
    OB_VERSION="1.0.0"
fi

echo ""
echo "=========================================="
echo "  Instalacao concluida! (v${OB_VERSION})"
echo "=========================================="
echo ""
echo "  Rode 'bootstrap' ou 'hadix' para abrir o painel Hadix.app,"
echo "  ou 'bootstrap --help' para ver todos os comandos. Sem argumentos ele abre o painel por padrao."
echo ""

# Em pipes/automacao, EOF nao deve transformar uma instalacao concluida em erro.
if [ -t 0 ]; then
    if read -r -p "Deseja abrir o menu agora? [s/N]: " OPEN_NOW; then
        case "$OPEN_NOW" in
            [sSyY]*) bash "$OB_HOME/bootstrap/bootstrap.sh" ;;
            *) ;;
        esac
    fi
fi
