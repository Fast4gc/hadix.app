#!/usr/bin/env bash
# commands/backup.sh — backup de um app (arquivos + banco, se detectado) ou de todos
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

BACKUP_DIR="/var/backups/oracle-bootstrap"
mkdir -p "$BACKUP_DIR"
TS="$(date +%Y%m%d-%H%M%S)"

backup_one() {
    local name="$1"
    local info path
    info="$(ob_apps_get "$name")"
    if [ "$info" = "null" ]; then
        log_error "App '${name}' nao encontrado."
        return 1
    fi
    path="$(echo "$info" | jq -r '.path')"
    local out="${BACKUP_DIR}/${name}-${TS}.tar.gz"
    log_step "Backup de '${name}' -> ${out}"
    tar --exclude="node_modules" --exclude=".git" --exclude="venv" -czf "$out" -C "$(dirname "$path")" "$(basename "$path")"
    log_ok "Backup salvo em ${out} ($(du -h "$out" | cut -f1))"
}

NAME="${1:-}"
if [ -z "$NAME" ]; then
    log_step "Backup de todos os apps"
    for app in $(ob_apps_list); do
        backup_one "$app"
    done
else
    backup_one "$NAME"
fi

log_info "Backups antigos (>14 dias) podem ser limpos manualmente em ${BACKUP_DIR}."
