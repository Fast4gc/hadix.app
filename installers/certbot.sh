#!/usr/bin/env bash
# installers/certbot.sh — alias/atalho, delega para ssl.sh (mesmo pacote)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
bash "${OB_HOME}/installers/ssl.sh"
