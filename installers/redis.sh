#!/usr/bin/env bash
# installers/redis.sh — instala Redis
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Redis"

if command_exists redis-server || command_exists redis-cli; then
    log_ok "Redis ja instalado."
else
    if command_exists apt-get; then
        pkg_install redis-server
    else
        pkg_install redis
    fi
fi

systemctl enable --now redis || systemctl enable --now redis-server
log_ok "Redis pronto."
