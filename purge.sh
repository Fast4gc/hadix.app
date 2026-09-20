#!/usr/bin/env bash
# purge.sh — limpeza COMPLETA da VPS
# Remove o Hadix.app, todos os apps criados e toda a infraestrutura
# instalada pelos instaladores (node, pnpm, bun, pm2, docker, nginx,
# certbot, postgres, redis, fail2ban, ufw/firewalld, gh).
#
# Uso:
#   sudo bash purge.sh            (a partir do repositorio)
#   hadix purge                   (a partir da instalacao em /opt/oracle-bootstrap)
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"

# bootstrap do projeto (se existir); senao, fallback de log simples
if [ -f "${OB_HOME}/bootstrap/colors.sh" ]; then
    source "${OB_HOME}/bootstrap/colors.sh"
    source "${OB_HOME}/bootstrap/logger.sh" 2>/dev/null
    LOG_AVAILABLE=true
else
    LOG_AVAILABLE=false
    log_step()  { printf '\n==> %s\n' "$*"; }
    log_info()  { printf '  [i] %s\n' "$*"; }
    log_ok()    { printf '  [OK] %s\n' "$*"; }
    log_warn()  { printf '  [!] %s\n' "$*"; }
    log_error() { printf '  [X] %s\n' "$*" >&2; }
fi

if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script precisa ser executado como root (use sudo)."
    exit 1
fi

# --- detecta gerenciador de pacotes -----------------------------------------
if command -v dnf >/dev/null 2>&1; then PKG="dnf"
elif command -v yum >/dev/null 2>&1; then PKG="yum"
elif command -v apt-get >/dev/null 2>&1; then PKG="apt-get"
else
    log_error "Gerenciador de pacotes nao suportado. Suportado: dnf, yum, apt-get."
    exit 1
fi

pkg_purge() {
    case "$PKG" in
        apt-get) DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq "$@" >/dev/null 2>&1 || true ;;
        dnf)     dnf remove -y "$@" >/dev/null 2>&1 || true ;;
        yum)     yum remove -y "$@" >/dev/null 2>&1 || true ;;
    esac
}

svc_disable() {
    systemctl disable --now "$1" >/dev/null 2>&1 || true
}

echo "=========================================="
echo "  Hadix.app — LIMPEZA COMPLETA DA VPS"
echo "=========================================="
echo ""
log_warn "Isto vai remover DEFINITIVAMENTE:"
echo "  - O Hadix.app e os comandos 'hadix'/'bootstrap'"
echo "  - TODOS os apps criados (processos, arquivos em /var/www)"
echo "  - Docker (containers, imagens, volumes)"
echo "  - nginx, certbot e certificados SSL"
echo "  - PostgreSQL e Redis (com todos os dados)"
echo "  - Node.js, pnpm, bun, pm2, gh, fail2ban, ufw/firewalld"
echo "  - Logs e backups do projeto"
echo ""
log_error "NAO HA COMO REVERTER. Faca um backup antes se precisar."
echo ""
read -r -p "Digite PURGAR para confirmar a limpeza total da VPS: " CONFIRM
if [ "$CONFIRM" != "PURGAR" ]; then
    echo "Cancelado. Nada foi removido."
    exit 0
fi

# --- 1. apps pm2 -------------------------------------------------------------
log_step "Parando e removendo apps pm2..."
if command -v pm2 >/dev/null 2>&1; then
    pm2 delete all >/dev/null 2>&1 || true
    pm2 unstartup systemd >/dev/null 2>&1 || true
    pm2 kill >/dev/null 2>&1 || true
fi
svc_disable pm2-root
rm -f /etc/systemd/system/pm2-*.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf /root/.pm2 /home/*/.pm2
log_ok "pm2 limpo."

# --- 2. docker ----------------------------------------------------------------
log_step "Removendo Docker (containers, imagens, volumes)..."
if command -v docker >/dev/null 2>&1; then
    docker stop $(docker ps -aq) >/dev/null 2>&1 || true
    docker rm $(docker ps -aq) >/dev/null 2>&1 || true
    docker system prune -af --volumes >/dev/null 2>&1 || true
    docker volume rm $(docker volume ls -q) >/dev/null 2>&1 || true
fi
svc_disable docker
svc_disable containerd
pkg_purge docker-ce docker-ce-cli containerd docker.io docker-compose docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras
rm -rf /var/lib/docker /var/lib/containerd /etc/docker /usr/local/bin/docker-compose
getent group docker >/dev/null 2>&1 && groupdel docker >/dev/null 2>&1 || true
rm -f /etc/apt/sources.list.d/docker.* /etc/yum.repos.d/docker*
log_ok "Docker removido."

# --- 3. nginx + certbot --------------------------------------------------------
log_step "Removendo nginx e certificados SSL..."
svc_disable nginx
rm -rf /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/nginx/conf.d
pkg_purge nginx nginx-common nginx-core certbot python3-certbot-nginx python3-certbot
rm -rf /etc/letsencrypt /var/log/letsencrypt /var/lib/letsencrypt /var/log/nginx
log_ok "nginx e SSL removidos."

# --- 4. postgres + redis --------------------------------------------------------
log_step "Removendo PostgreSQL e Redis (dados incluidos)..."
svc_disable postgresql
svc_disable redis-server
pkg_purge postgresql postgresql-contrib postgresql-server postgresql15 postgresql16 redis-server redis
rm -rf /var/lib/postgresql /var/lib/pgsql /etc/postgresql /etc/redis /var/log/postgresql
log_ok "Bancos de dados removidos."

# --- 5. node, pnpm, bun, pm2, gh --------------------------------------------------
log_step "Removendo Node.js, pnpm, bun, pm2 e gh..."
pkg_purge nodejs npm gh
rm -rf /usr/lib/node_modules /usr/local/lib/node_modules /usr/local/bin/pm2 \
       /usr/local/bin/pnpm /usr/local/bin/npx /usr/local/bin/node \
       /root/.bun /usr/local/bin/bun /usr/local/bin/bx /root/.npm /root/.cache \
       /home/*/.bun /home/*/.npm /home/*/.cache /home/*/.local/share/pnpm
rm -f /etc/apt/sources.list.d/nodesource.* /etc/yum.repos.d/nodesource* /etc/yum.repos.d/gh*
log_ok "Runtime e ferramentas removidos."

# --- 6. seguranca (fail2ban, ufw/firewalld) ----------------------------------------
log_step "Removendo fail2ban e firewall..."
svc_disable fail2ban
pkg_purge fail2ban
rm -rf /etc/fail2ban
if command -v ufw >/dev/null 2>&1; then
    ufw --force disable >/dev/null 2>&1 || true
    ufw --force reset >/dev/null 2>&1 || true
fi
pkg_purge ufw firewalld
rm -rf /etc/ufw /etc/firewalld /etc/sysconfig/iptables
log_ok "Seguranca resetada (firewall desligado — a VPS volta ao padrao do provedor)."

# --- 7. arquivos do projeto -----------------------------------------------------------
log_step "Removendo apps, arquivos e instalacao do Hadix.app..."
rm -rf /var/www
rm -rf /var/backups/oracle-bootstrap
rm -rf /var/log/oracle-bootstrap /tmp/oracle-bootstrap
for command_path in /usr/local/bin/hadix /usr/local/bin/hadix-app /usr/local/bin/bootstrap; do
    if grep -Fq "${OB_HOME}/bootstrap/bootstrap.sh" "$command_path" 2>/dev/null; then
        rm -f "$command_path"
    fi
done
rm -rf "$OB_HOME"
[ "$LOG_AVAILABLE" = true ] && OB_HOME="/tmp"   # nao ha mais logger depois daqui
log_ok "Hadix.app removido."

# --- 8. limpeza final do sistema ----------------------------------------------------------
log_step "Limpando pacotes orphan e caches..."
case "$PKG" in
    apt-get) apt-get autoremove --purge -y -qq >/dev/null 2>&1 || true
             apt-get autoclean -qq >/dev/null 2>&1 || true ;;
    dnf)     dnf autoremove -y >/dev/null 2>&1 || true
             dnf clean all >/dev/null 2>&1 || true ;;
    yum)     yum autoremove -y >/dev/null 2>&1 || true
             yum clean all >/dev/null 2>&1 || true ;;
esac

echo ""
echo "=========================================="
echo "  VPS limpa completamente."
echo "  Resta apenas o sistema operacional base."
echo "=========================================="
