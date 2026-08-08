#!/usr/bin/env bash
# installers/node.sh — instala Node.js LTS via NodeSource
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Node.js (LTS)"

NODE_MAJOR="${NODE_MAJOR:-22}"

if command_exists node; then
    log_ok "Node ja instalado: $(node -v)"
else
    if command_exists apt-get; then
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
        apt-get install -y nodejs
    else
        curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
        pkg_install nodejs
    fi
    log_ok "Node instalado: $(node -v) / npm $(npm -v)"
fi
