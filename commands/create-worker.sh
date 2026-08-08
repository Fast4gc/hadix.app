#!/usr/bin/env bash
# commands/create-worker.sh — cria um worker/processo em background (sem porta HTTP)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome do worker" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"

APP_PATH="${OB_APPS_DIR}/${NAME}"
[ -d "$APP_PATH" ] && { log_error "Diretorio ${APP_PATH} ja existe."; exit 1; }
mkdir -p "$APP_PATH"

cat > "${APP_PATH}/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "main": "worker.js",
  "scripts": { "start": "node worker.js" }, "dependencies": {} }
PKG

cat > "${APP_PATH}/worker.js" << 'JS'
console.log('Worker iniciado via oracle-bootstrap.');

setInterval(() => {
    console.log(`[${new Date().toISOString()}] worker ativo...`);
}, 60_000);
JS

command_exists node || bash "${OB_HOME}/installers/node.sh"
command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
(cd "$APP_PATH" && pm2 start worker.js --name "$NAME")
pm2 save

ob_apps_add "$NAME" "worker" "0" "" "$APP_PATH"
log_ok "Worker '${NAME}' criado e rodando em background (pm2 logs ${NAME})."
