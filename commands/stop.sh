#!/usr/bin/env bash
# commands/stop.sh — para um app (PM2), estado STOPPED
# Uso: bootstrap stop <nome>
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

command_exists() { command -v "$1" >/dev/null 2>&1; }

NAME="${1:-}"
[ -z "$NAME" ] && { log_error "Nome do app obrigatorio."; exit 1; }

command_exists pm2 || { log_error "pm2 nao instalado."; exit 1; }

if pm2 describe "$NAME" >/dev/null 2>&1; then
    pm2 stop "$NAME" >/dev/null 2>&1
    log_ok "'${NAME}' parado (estado STOPPED)."
    # atualiza estado no apps.json
    if command_exists jq && [ -f "$OB_APPS_FILE" ]; then
        tmp="$(mktemp)"
        jq --arg n "$NAME" '.[$n].status = "stopped"' "$OB_APPS_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$OB_APPS_FILE" 2>/dev/null
    fi
else
    log_warn "'${NAME}' nao existe no pm2."
fi
