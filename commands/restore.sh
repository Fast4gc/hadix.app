#!/usr/bin/env bash
# commands/restore.sh — restaura um app a partir de um arquivo .tar.gz gerado pelo backup.sh
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

FILE="${1:-$(ask "Caminho do arquivo de backup (.tar.gz)" "")}"
[ -f "$FILE" ] || { log_error "Arquivo nao encontrado: ${FILE}"; exit 1; }

log_step "Restaurando ${FILE}"
tar -xzf "$FILE" -C "$OB_APPS_DIR"
NAME="$(basename "$FILE" | sed -E 's/-[0-9]{8}-[0-9]{6}\.tar\.gz$//')"

log_ok "Restaurado em ${OB_APPS_DIR}/${NAME}"
log_info "Se o app usa pm2/docker, reinicie com: bootstrap restart ${NAME}"
