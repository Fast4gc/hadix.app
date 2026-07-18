#!/usr/bin/env bash
# commands/ssl.sh — emite/renova certificado SSL via certbot (nginx)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
require_root

DOMAIN="${1:-$(ask "Dominio" "")}"
[ -z "$DOMAIN" ] && { log_error "Dominio obrigatorio."; exit 1; }

command_exists certbot || bash "${OB_HOME}/installers/ssl.sh"

EMAIL="$(ask "Email para avisos de renovacao" "admin@${DOMAIN}")"

log_step "Emitindo certificado para ${DOMAIN}"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

systemctl list-timers | grep -q certbot || (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -

log_ok "SSL ativo para https://${DOMAIN} (renovacao automatica configurada)."
