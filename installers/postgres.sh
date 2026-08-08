#!/usr/bin/env bash
# installers/postgres.sh — instala PostgreSQL e cria usuario/db opcional
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando PostgreSQL"

if command_exists psql; then
    log_ok "PostgreSQL ja instalado: $(psql --version)"
else
    if command_exists apt-get; then
        pkg_install postgresql postgresql-contrib
    else
        pkg_install postgresql-server postgresql-contrib
        [ -f /var/lib/pgsql/data/PG_VERSION ] || postgresql-setup --initdb
    fi
fi

systemctl enable --now postgresql

if confirm "Deseja criar um banco/usuario agora?"; then
    DB_NAME="$(ask "Nome do banco" "appdb")"
    DB_USER="$(ask "Usuario" "appuser")"
    DB_PASS="$(random_password 20)"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
    log_ok "Banco '${DB_NAME}' criado. Usuario: ${DB_USER} / Senha: ${DB_PASS}"
    echo "DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"
fi

log_ok "PostgreSQL pronto."
