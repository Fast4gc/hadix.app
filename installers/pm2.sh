#!/usr/bin/env bash
# installers/pm2.sh — instala PM2 (gerenciador de processos Node) globalmente
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando PM2"

if ! command_exists node; then
    log_warn "Node.js nao encontrado, instalando primeiro..."
    bash "${OB_HOME}/installers/node.sh"
fi

if command_exists pm2; then
    log_ok "PM2 ja instalado: $(pm2 -v)"
else
    npm install -g pm2
    log_ok "PM2 instalado: $(pm2 -v)"
fi

pm2 startup systemd -u "${SUDO_USER:-root}" --hp "${HOME}" >/dev/null 2>&1 || true
log_ok "PM2 configurado para iniciar no boot."
