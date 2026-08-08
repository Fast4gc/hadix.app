#!/usr/bin/env bash
# installers/pnpm.sh — instala pnpm globalmente
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando pnpm"

if ! command_exists node; then
    log_warn "Node.js nao encontrado, instalando primeiro..."
    bash "${OB_HOME}/installers/node.sh"
fi

if command_exists pnpm; then
    log_ok "pnpm ja instalado: $(pnpm -v)"
else
    npm install -g pnpm
    log_ok "pnpm instalado: $(pnpm -v)"
fi
