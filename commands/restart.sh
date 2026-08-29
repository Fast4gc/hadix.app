#!/usr/bin/env bash
# commands/restart.sh — reinicia um app (detecta pm2, docker ou systemd)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome do app" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }

if command_exists pm2 && pm2 describe "$NAME" >/dev/null 2>&1; then
    pm2 restart "$NAME" && log_ok "'${NAME}' reiniciado via pm2."
elif command_exists docker && docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    docker restart "$NAME" && log_ok "'${NAME}' reiniciado via docker."
elif systemctl list-units --full -all | grep -q "${NAME}.service"; then
    systemctl restart "$NAME" && log_ok "'${NAME}' reiniciado via systemd."
else
    # app registrado mas sem processo: tenta subir via start.sh
    if command_exists jq && jq -e --arg n "$NAME" 'has($n)' "$OB_APPS_FILE" >/dev/null 2>&1; then
        log_info "App registrado mas sem processo — subindo via start.sh..."
        bash "${OB_HOME}/commands/start.sh" "$NAME"
    else
        log_error "Nao encontrei processo gerenciado para '${NAME}'."
        exit 1
    fi
fi
