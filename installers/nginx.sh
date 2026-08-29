#!/usr/bin/env bash
# installers/nginx.sh — instala e configura o Nginx
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"; source "${OB_HOME}/bootstrap/utils.sh"
require_root
log_step "Instalando Nginx"

if command_exists nginx; then
    log_ok "Nginx ja instalado: $(nginx -v 2>&1)"
else
    pkg_install nginx
fi

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Remove confs com placeholders nao substituidos (__VAR__) — evita
# "invalid port in upstream 127.0.0.1:__PORT__" e quebra o nginx -t.
# Isso limpa restos de versoes antigas do hadix-websocket.conf.
_clean_nginx_placeholders() {
    local found=""
    found="$(grep -rl '__[A-Z0-9_]*__' /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled 2>/dev/null || true)"
    if [ -n "$found" ]; then
        echo "  ${YELLOW}${WARN}${NC} Removendo confs Nginx com placeholders (versao antiga):"
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo "    - $f"
            rm -f "$f"
        done <<< "$found"
        # remove symlinks quebrados em sites-enabled
        find /etc/nginx/sites-enabled -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    fi
}
_clean_nginx_placeholders

# garante que sites-enabled seja incluido (RHEL/Oracle Linux nao inclui por padrao)
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
    sed -i '/http {/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf || true
fi

systemctl enable --now nginx
if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
    log_ok "Nginx instalado e rodando."
else
    echo "  ${YELLOW}${WARN}${NC} nginx -t falhou — veja detalhes abaixo:" >&2
    nginx -t 2>&1 | head -10 >&2
    log_ok "Nginx instalado (config pendente de correcao)."
fi
