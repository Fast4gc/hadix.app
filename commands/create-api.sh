#!/usr/bin/env bash
# commands/create-api.sh — cria uma API Node/Express com nginx + pm2
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome da API" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"

DOMAIN="$(ask "Dominio (ex: api.exemplo.com, vazio = apenas IP)" "")"
PORT="$(next_free_port 3000)"
PORT="$(ask "Porta" "$PORT")"
APP_PATH="${OB_APPS_DIR}/${NAME}"

log_step "Criando API '${NAME}' em ${APP_PATH}"

if [ -d "$APP_PATH" ]; then
    log_error "Diretorio ${APP_PATH} ja existe."
    exit 1
fi

mkdir -p "$APP_PATH"
cat > "${APP_PATH}/package.json" << PKG
{
  "name": "${NAME}",
  "version": "1.0.0",
  "private": true,
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "express": "^4.19.2" }
}
PKG

cat > "${APP_PATH}/index.js" << 'JS'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/', (req, res) => res.json({ message: 'API rodando via oracle-bootstrap' }));

app.listen(PORT, () => console.log(`API ouvindo na porta ${PORT}`));
JS

echo "PORT=${PORT}" > "${APP_PATH}/.env"

command_exists node || bash "${OB_HOME}/installers/node.sh"
(cd "$APP_PATH" && npm install --production --silent)

command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
(cd "$APP_PATH" && pm2 start index.js --name "$NAME" --env production)
pm2 save

if [ -n "$DOMAIN" ] && command_exists nginx; then
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__PORT__/${PORT}/g" -e "s/__APP_NAME__/${NAME}/g" \
        "${OB_HOME}/templates/nginx/api.conf" > "/etc/nginx/sites-available/${NAME}.conf"
    ln -sf "/etc/nginx/sites-available/${NAME}.conf" "/etc/nginx/sites-enabled/${NAME}.conf"
    nginx -t && systemctl reload nginx
    log_ok "Nginx configurado para ${DOMAIN} -> 127.0.0.1:${PORT}"
fi

ob_apps_add "$NAME" "api" "$PORT" "$DOMAIN" "$APP_PATH"

log_ok "API '${NAME}' criada e rodando na porta ${PORT}."
[ -n "$DOMAIN" ] && echo "Rode: bootstrap ssl ${DOMAIN}   (para ativar HTTPS)"
