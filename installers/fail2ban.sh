#!/usr/bin/env bash
# installers/fail2ban.sh — instala e configura fail2ban (protecao SSH basica)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando fail2ban"

pkg_install fail2ban

cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
JAIL

systemctl enable --now fail2ban
log_ok "fail2ban ativo, protegendo SSH."
