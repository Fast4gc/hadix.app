#!/usr/bin/env bash
# uninstall.sh — remove o oracle-bootstrap (apps criados NAO sao removidos)
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh" 2>/dev/null
source "${OB_HOME}/bootstrap/logger.sh" 2>/dev/null
source "${OB_HOME}/bootstrap/utils.sh" 2>/dev/null

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root." >&2
    exit 1
fi

echo "Isso vai remover o oracle-bootstrap de ${OB_HOME} e o comando 'bootstrap'."
echo "Os apps ja criados (em /var/www, pm2, docker, nginx) NAO serao removidos."
read -r -p "Confirmar remocao? [s/N]: " CONFIRM
case "$CONFIRM" in
    [sSyY]*) ;;
    *) echo "Cancelado."; exit 0 ;;
esac

rm -f /usr/local/bin/bootstrap
rm -rf "$OB_HOME"

echo "oracle-bootstrap removido. Configuracoes de apps continuam em /var/www."
