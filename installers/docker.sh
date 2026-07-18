#!/usr/bin/env bash
# installers/docker.sh — instala Docker + Docker Compose plugin
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Docker"

if command_exists docker; then
    log_ok "Docker ja instalado: $(docker --version)"
else
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    systemctl enable --now docker
    log_ok "Docker instalado: $(docker --version)"
fi

if ! docker compose version >/dev/null 2>&1; then
    log_warn "Plugin docker compose nao encontrado, tentando instalar..."
    pkg_install docker-compose-plugin || true
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    usermod -aG docker "$SUDO_USER" && log_ok "Usuario '$SUDO_USER' adicionado ao grupo docker (relogin necessario)."
fi

log_ok "Docker pronto."
