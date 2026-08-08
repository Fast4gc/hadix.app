#!/usr/bin/env bash
# commands/logs.sh — mostra logs de um app (detecta pm2, docker ou nginx)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

NAME="${1:-$(ask "Nome do app" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }

if command_exists pm2 && pm2 describe "$NAME" >/dev/null 2>&1; then
    pm2 logs "$NAME" --lines 100
elif command_exists docker && docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    docker logs -f --tail 100 "$NAME"
elif [ -f "/var/log/nginx/${NAME}.error.log" ]; then
    tail -n 100 -f "/var/log/nginx/${NAME}.access.log" "/var/log/nginx/${NAME}.error.log"
else
    log_error "Nao encontrei logs para '${NAME}' (pm2/docker/nginx)."
    exit 1
fi
