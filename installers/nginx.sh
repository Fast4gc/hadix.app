#!/usr/bin/env bash
# installers/nginx.sh — instala e configura o Nginx
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Nginx"

if command_exists nginx; then
    log_ok "Nginx ja instalado: $(nginx -v 2>&1)"
else
    pkg_install nginx
fi

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# garante que sites-enabled seja incluido (RHEL/Oracle Linux nao inclui por padrao)
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
    sed -i '/http {/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf || true
fi

systemctl enable --now nginx
nginx -t && systemctl reload nginx

log_ok "Nginx instalado e rodando."
