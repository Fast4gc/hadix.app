#!/usr/bin/env bash
# installers/bun.sh — instala o runtime Bun
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Bun"

if command_exists bun; then
    log_ok "Bun ja instalado: $(bun -v)"
else
    curl -fsSL https://bun.sh/install | bash
    ln -sf "${HOME}/.bun/bin/bun" /usr/local/bin/bun 2>/dev/null || true
    log_ok "Bun instalado."
fi
