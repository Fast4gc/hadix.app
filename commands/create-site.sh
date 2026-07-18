#!/usr/bin/env bash
# commands/create-site.sh — cria um site estatico servido pelo nginx
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome do site" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"
DOMAIN="$(ask "Dominio" "")"
[ -z "$DOMAIN" ] && { log_error "Dominio obrigatorio para sites estaticos."; exit 1; }

APP_PATH="${OB_APPS_DIR}/${NAME}"
[ -d "$APP_PATH" ] && { log_error "Diretorio ${APP_PATH} ja existe."; exit 1; }
mkdir -p "$APP_PATH"

cat > "${APP_PATH}/index.html" << HTML
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>${NAME}</title></head>
<body><h1>${NAME} esta no ar 🚀</h1><p>Site criado via oracle-bootstrap.</p></body>
</html>
HTML

command_exists nginx || bash "${OB_HOME}/installers/nginx.sh"

sed -e "s#__DOMAIN__#${DOMAIN}#g" -e "s#__ROOT_PATH__#${APP_PATH}#g" -e "s#__APP_NAME__#${NAME}#g" \
    "${OB_HOME}/templates/nginx/static.conf" > "/etc/nginx/sites-available/${NAME}.conf"
ln -sf "/etc/nginx/sites-available/${NAME}.conf" "/etc/nginx/sites-enabled/${NAME}.conf"
nginx -t && systemctl reload nginx

ob_apps_add "$NAME" "site" "0" "$DOMAIN" "$APP_PATH"

log_ok "Site '${NAME}' publicado em http://${DOMAIN}"
echo "Rode: bootstrap ssl ${DOMAIN}   (para ativar HTTPS)"
