#!/usr/bin/env bash
# installers/ufw.sh — configura firewall (ufw no Debian/Ubuntu, firewalld no RHEL/Oracle Linux)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Configurando firewall"

if command_exists apt-get; then
    pkg_install ufw
    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    ufw status verbose
else
    pkg_install firewalld
    systemctl enable --now firewalld
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    firewall-cmd --list-all
fi

log_ok "Firewall configurado (portas 22, 80, 443 liberadas)."
