#!/usr/bin/env bash
# installers/cloudflare.sh — instala cloudflared (Cloudflare Tunnel) e configura API opcional
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Cloudflare Tunnel (cloudflared)"

if command_exists cloudflared; then
    log_ok "cloudflared ja instalado: $(cloudflared -v)"
else
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64) CF_ARCH="amd64" ;;
        aarch64|arm64) CF_ARCH="arm64" ;;
        *) CF_ARCH="amd64" ;;
    esac
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    log_ok "cloudflared instalado: $(cloudflared -v)"
fi

echo ""
echo "Para autenticar rode: cloudflared tunnel login"
echo "Para criar um tunel:  cloudflared tunnel create <nome>"
echo ""
if confirm "Deseja salvar um Cloudflare API Token para uso pelos scripts (DNS/SSL)?"; then
    TOKEN="$(ask "Cole o token" "")"
    mkdir -p /etc/oracle-bootstrap
    echo "CF_API_TOKEN=${TOKEN}" > /etc/oracle-bootstrap/cloudflare.env
    chmod 600 /etc/oracle-bootstrap/cloudflare.env
    log_ok "Token salvo em /etc/oracle-bootstrap/cloudflare.env"
fi
