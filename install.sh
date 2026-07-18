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

# --- checagens iniciais -----------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Este instalador precisa ser executado como root (use sudo)." >&2
    exit 1
fi

echo "=========================================="
echo "  oracle-bootstrap — instalador"
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
    echo "==> Clonando oracle-bootstrap para ${OB_HOME}..."
    rm -rf "$OB_HOME"
    if ! git clone --depth 1 "$REPO_URL" "$OB_HOME" 2>/dev/null; then
        echo "==> git clone falhou, baixando ZIP do branch main..."
        TMP_ZIP="$(mktemp -d)/hadix.zip"
        curl -fsSL "https://github.com/Fast4gc/hadix.app/archive/refs/heads/main.zip" -o "$TMP_ZIP"
        unzip -q "$TMP_ZIP" -d "$(dirname "$TMP_ZIP")"
        mkdir -p "$OB_HOME"
        cp -r "$(dirname "$TMP_ZIP")"/hadix.app-main/* "$OB_HOME"/
    fi
fi

chmod +x "$OB_HOME"/*.sh
chmod +x "$OB_HOME"/bootstrap/*.sh
chmod +x "$OB_HOME"/installers/*.sh
chmod +x "$OB_HOME"/commands/*.sh

# --- symlink global ----------------------------------------------------------
echo "==> Criando comando global 'bootstrap'..."
cat > "$BIN_LINK" << WRAPPER
#!/usr/bin/env bash
export OB_HOME="${OB_HOME}"
exec bash "${OB_HOME}/bootstrap/bootstrap.sh" "\$@"
WRAPPER
chmod +x "$BIN_LINK"

# --- config inicial -----------------------------------------------------------
mkdir -p "$OB_HOME/config" /var/www /var/log/oracle-bootstrap
for f in apps users domains; do
    [ -f "$OB_HOME/config/${f}.json" ] || echo '{}' > "$OB_HOME/config/${f}.json"
done

echo ""
echo "=========================================="
echo "  Instalacao concluida!"
echo "=========================================="
echo ""
echo "  Rode 'bootstrap' para abrir o menu interativo,"
echo "  ou 'bootstrap --help' para ver todos os comandos."
echo ""

read -r -p "Deseja abrir o menu agora? [s/N]: " OPEN_NOW
case "$OPEN_NOW" in
    [sSyY]*) exec bash "$OB_HOME/bootstrap/bootstrap.sh" ;;
    *) ;;
esac
