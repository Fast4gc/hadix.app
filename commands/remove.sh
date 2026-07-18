#!/usr/bin/env bash
# commands/remove.sh — remove um app (pm2/docker + nginx + arquivos, com confirmacao)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome do app" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }

INFO="$(ob_apps_get "$NAME")"
if [ "$INFO" = "null" ]; then
    log_warn "App '${NAME}' nao esta no registro, mas vou tentar limpar mesmo assim."
fi

if ! confirm "Tem certeza que deseja remover '${NAME}' (processo + nginx + arquivos)?"; then
    echo "Cancelado."
    exit 0
fi

command_exists pm2 && pm2 delete "$NAME" >/dev/null 2>&1 && log_ok "Processo pm2 removido."
command_exists docker && docker rm -f "$NAME" >/dev/null 2>&1 && log_ok "Container docker removido."

if [ -f "/etc/nginx/sites-enabled/${NAME}.conf" ] || [ -f "/etc/nginx/sites-available/${NAME}.conf" ]; then
    rm -f "/etc/nginx/sites-enabled/${NAME}.conf" "/etc/nginx/sites-available/${NAME}.conf"
    nginx -t 2>/dev/null && systemctl reload nginx
    log_ok "Configuracao nginx removida."
fi

APP_PATH="${OB_APPS_DIR}/${NAME}"
if [ -d "$APP_PATH" ]; then
    if confirm "Remover tambem os arquivos em ${APP_PATH}?"; then
        rm -rf "$APP_PATH"
        log_ok "Arquivos removidos."
    fi
fi

ob_apps_remove "$NAME"
log_ok "App '${NAME}' removido do registro."
