#!/usr/bin/env bash
# installers/ssl.sh — instala dependencias para SSL (certbot + plugin nginx)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando suporte a SSL (Certbot)"

if command_exists apt-get; then
    pkg_install certbot python3-certbot-nginx
else
    pkg_install certbot python3-certbot-nginx
fi

log_ok "Certbot instalado. Use: bootstrap ssl <dominio>"
