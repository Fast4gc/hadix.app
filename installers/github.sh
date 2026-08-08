#!/usr/bin/env bash
# installers/github.sh — instala GitHub CLI e gera chave SSH de deploy
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando GitHub CLI"

if command_exists gh; then
    log_ok "GitHub CLI ja instalado: $(gh --version | head -n1)"
else
    if command_exists apt-get; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
        apt-get update -qq && apt-get install -y gh
    else
        dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
        dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true
        pkg_install gh
    fi
    log_ok "GitHub CLI instalado."
fi

KEY_PATH="/root/.ssh/oracle_bootstrap_deploy"
if [ ! -f "$KEY_PATH" ]; then
    mkdir -p /root/.ssh
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "oracle-bootstrap-deploy"
    log_ok "Chave de deploy gerada em ${KEY_PATH}.pub — adicione-a no GitHub (Deploy Keys) do repositorio."
    echo ""
    cat "${KEY_PATH}.pub"
    echo ""
fi

echo "Para autenticar o gh CLI: gh auth login"
