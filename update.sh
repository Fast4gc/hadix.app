#!/usr/bin/env bash
# update.sh — atualiza o oracle-bootstrap e componentes instalados
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"

require_root

log_step "Atualizando oracle-bootstrap"
if [ -d "$OB_HOME/.git" ]; then
    git -C "$OB_HOME" pull --ff-only && log_ok "Repositorio atualizado" || log_warn "Nao foi possivel atualizar via git"
else
    log_warn "Instalacao nao e um repositorio git; rode install.sh novamente para atualizar."
fi

chmod +x "$OB_HOME"/*.sh "$OB_HOME"/bootstrap/*.sh "$OB_HOME"/installers/*.sh "$OB_HOME"/commands/*.sh 2>/dev/null

if confirm "Atualizar pacotes do sistema (apt/dnf upgrade)?"; then
    log_step "Atualizando pacotes do sistema"
    pkg_update
fi

if command_exists pm2; then
    if confirm "Atualizar apps gerenciados pelo PM2?"; then
        pm2 update
    fi
fi

log_ok "Atualizacao concluida."
