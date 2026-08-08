#!/usr/bin/env bash
# installers/monitoring.sh — instala Netdata para monitoramento em tempo real
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando monitoramento (Netdata)"

if command_exists netdata; then
    log_ok "Netdata ja instalado."
else
    curl -fsSL https://get.netdata.cloud/kickstart.sh -o /tmp/netdata-kickstart.sh
    sh /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry --non-interactive
fi

systemctl enable --now netdata 2>/dev/null || true

PUB_IP="$(get_public_ip)"
log_ok "Netdata instalado. Dashboard local: http://${PUB_IP}:19999"
log_warn "Considere restringir a porta 19999 no firewall/nginx a apenas seu IP."
