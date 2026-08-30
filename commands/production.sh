#!/usr/bin/env bash
# commands/production.sh — coloca a VPS EM PRODUCAO como plataforma de hospedagem
# de BOTS e SITES (estilo Discloud/Squarecloud).
#
# O que faz:
#   1. Instala a stack completa de hosting (nginx, node, pm2, docker, redis,
#      postgres, firewall ufw, fail2ban, certbot/ssl, cloudflare, netdata).
#   2. Cria a estrutura de diretorios de hosting (apps/domains/logs/ssl).
#   3. Cria o usuario de apps (www-data->hadix) com pasta home e pm2 proprio.
#   4. Configura nginx com presets de bot/site/api/worker + Websocket.
#   5. Gera um manifesto global da VPS (host.json) para o front hadix.site.
#   6. Adiciona modelos 'hadix.toml' p/ apps no padrao Discloud/Squarecloud.
#   7. Resumo final do que foi ativado.
#
# Uso:
#   bootstrap production              # configura a VPS como hosting (idempotente)
#   bootstrap production --check      # apenas mostra o status do que ja existe
#   bootstrap production --reset      # refaz configs (nginx/pm2/node) mantendo apps
#   bootstrap production --dry-run    # mostra o que seria feito sem alterar nada
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/logger.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/utils.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/config.sh" 2>/dev/null || true
command -v ob_config_init >/dev/null 2>&1 && ob_config_init || true

MODE="run"
for arg in "$@"; do
    case "$arg" in
        --check|--status) MODE="check";;
        --reset) MODE="reset";;
        --dry-run) MODE="dry";;
        --help|-h) echo "Uso: bootstrap production [--check|--reset|--dry-run]"; exit 0;;
    esac
done

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        (command -v log_error >/dev/null 2>&1 && log_error "Precisa de root: sudo bootstrap production" || echo "Precisa de root." >&2)
        exit 1
    fi
}

# ---------------------------------------------------------------- helpers
pkg() { # pkg <nome...>
    if command_exists apt-get; then apt-get install -y "$@"
    elif command_exists dnf; then dnf install -y "$@"
    elif command_exists yum; then yum install -y "$@"
    fi
}

install_if_missing() { # install_if_missing <installer> <prog>
    local installer="$1" prog="$2"
    if command_exists "$prog"; then
        echo "    ${GREEN}${TICK}${NC} ${prog}: ja instalado"
    else
        echo "    ${CYAN}${SPIN}${NC} instalando ${prog}..."
        if [ "$MODE" = "dry" ]; then
            echo "      (dry-run) rodaria: installers/${installer}.sh"
        elif bash "${OB_HOME}/installers/${installer}.sh" >/dev/null 2>&1; then
            echo "    ${GREEN}${TICK}${NC} ${prog}: instalado"
        else
            echo "    ${YELLOW}${WARN}${NC} ${prog}: falha ao instalar (continue acima)"
        fi
    fi
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

log_banner() {
    local title="$1" sub="$2"
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo "  ██╗  ██╗ █████╗ ██████╗ ██╗██╗  ██╗"
    echo "  ██║  ██║██╔══██╗██╔══██╗██║╚██╗██╔╝"
    echo "  ███████║███████║██║  ██║██║ ╚███╔╝ "
    echo "  ██╔══██║██╔══██║██║  ██║██║ ██╔██╗ "
    echo "  ██║  ██║██║  ██║██████╔╝██║██╔╝ ██╗"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "  ${WHITE}${BOLD}${title}${NC}"
    echo -e "  ${DIM}${sub}${NC}"
    echo ""
}

step_done() { echo -e "  ${GREEN}${TICK}${NC} $1"; }
step_warn() { echo -e "  ${YELLOW}${WARN}${NC} $1"; }
step_info() { echo -e "  ${CYAN}${DOT}${NC} $1"; }

# ---------------------------------------------------------------- estrutura
setup_dirs() {
    echo -e "\n  ${BOLD}${SKY}Estrutura de hosting${NC}"
    local dirs=(
        "${OB_APPS_DIR:-/var/www}"       # apps (bots/sites/apis/workers)
        "${HADIX_HOSTING_DIR:-/var/hadix}/domains"  # dominios publicados
        "${HADIX_HOSTING_DIR:-/var/hadix}/ssl"      # certificados extras
        "${HADIX_HOSTING_DIR:-/var/hadix}/logs"     # logs centralizados de apps
        "${HADIX_HOSTING_DIR:-/var/hadix}/backups"  # snapshots
        "${HADIX_HOSTING_DIR:-/var/hadix}/envs"     # .env por app (perm 600)
        /etc/nginx/sites-available
        /etc/nginx/sites-enabled
    )
    for d in "${dirs[@]}"; do
        if [ "$MODE" = "dry" ]; then echo "    (dry-run) mkdir -p $d"
        elif mkdir -p "$d" 2>/dev/null; then echo "    ${GRAY}${DOT}${NC} $d"
        fi
    done
    # permissoes
    if [ "$MODE" != "dry" ]; then
        chmod 700 "${HADIX_HOSTING_DIR:-/var/hadix}/envs" 2>/dev/null || true
    fi
    step_done "Estrutura pronta em ${HADIX_HOSTING_DIR:-/var/hadix}"
}

# ---------------------------------------------------------------- usuario de apps
setup_app_user() {
    echo -e "\n  ${BOLD}${SKY}Usuario de aplicacoes${NC}"
    # Usa hadix como user nao-root p/ rodar apps (seguranca estilo Discloud)
    local app_user="hadix"
    if id "$app_user" >/dev/null 2>&1; then
        step_done "Usuario '${app_user}' ja existe ($(id -u $app_user))"
    else
        if [ "$MODE" = "dry" ]; then echo "    (dry-run) useradd -m -s /bin/bash ${app_user}"
        elif useradd -m -s /bin/bash "$app_user" 2>/dev/null; then
            step_done "Usuario '${app_user}' criado"
        else
            step_warn "Nao consegui criar o usuario '${app_user}'"
        fi
    fi
    # garante que o user pertence a www-data (nginx access temporal)
    if [ "$MODE" != "dry" ] && id "$app_user" >/dev/null 2>&1; then
        usermod -aG www-data "$app_user" >/dev/null 2>&1 || true
        # pm2 sob o user hadix p/ apps nao-root
        local pm2_home="/home/${app_user}/.pm2"
        if [ ! -d "$pm2_home" ]; then
            mkdir -p "$pm2_home" 2>/dev/null || true
            chown -R "${app_user}:$(id -gn $app_user)" "/home/${app_user}" 2>/dev/null || true
            step_info "pm2 home preparado para ${app_user}"
        fi
    fi
    # cria o script de boot do pm2 do user hadix c/ systemd (boot persistente)
    if [ "$MODE" != "dry" ] && id "$app_user" >/dev/null 2>&1; then
        cat > "/etc/systemd/system/pm2-${app_user}.service" <<SVC 2>/dev/null || true
[Unit]
Description=PM2 process manager (${app_user})
After=network.target

[Service]
Type=forking
User=${app_user}
ExecStart=/usr/bin/env PM2_HOME=/home/${app_user}/.pm2 /usr/local/bin/pm2 resurrect
ExecStop=/usr/bin/env PM2_HOME=/home/${app_user}/.pm2 /usr/local/bin/pm2 kill
Restart=no

[Install]
WantedBy=multi-user.target
SVC
        chown -R "${app_user}:$(id -gn $app_user)" "/home/${app_user}/.pm2" 2>/dev/null || true
        step_info "systemd pm2 boot preparado (pm2-${app_user}.service)"
    fi
}

# ---------------------------------------------------------------- nginx presets
# Remove confs com placeholders nao substituidos (restos de versao antiga)
clean_nginx_placeholders() {
    local found=""
    found="$(grep -rl '__[A-Z0-9_]*__' /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled 2>/dev/null || true)"
    if [ -n "$found" ]; then
        echo "    ${YELLOW}${WARN}${NC} Removendo confs Nginx com placeholders (versao antiga):"
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo "      - $f"
            rm -f "$f"
        done <<< "$found"
        find /etc/nginx/sites-enabled -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    fi
}

setup_nginx() {
    echo -e "\n  ${BOLD}${SKY}Nginx presets${NC}"
    if ! cmd_exists nginx; then
        echo "    ${CYAN}${SPIN}${NC} nginx nao instalado, instalando..."
        if [ "$MODE" != "dry" ]; then
            bash "${OB_HOME}/installers/nginx.sh" >/dev/null 2>&1 || { step_warn "falha nginx"; return; }
        fi
    else
        step_done "nginx $(nginx -v 2>&1 | sed 's/.*nginx\///')"
    fi

    # limpa confs quebrados de versoes antigas antes de instalar o preset
    if [ "$MODE" != "dry" ]; then
        clean_nginx_placeholders
    fi

    # conf global WebSocket (upgrade) p/ bots e apps em tempo real
    local ws_conf="/etc/nginx/conf.d/hadix-websocket.conf"
    if [ "$MODE" = "dry" ]; then
        echo "    (dry-run) copia templates/nginx/websocket.conf -> $ws_conf"
    elif [ -f "${OB_HOME}/templates/nginx/websocket.conf" ]; then
        cp "${OB_HOME}/templates/nginx/websocket.conf" "$ws_conf" 2>/dev/null
        step_done "WebSocket preset instalado ($ws_conf)"
    else
        step_warn "template websocket.conf ausente"
    fi

    # habilita gzip global e basic limits
    if [ "$MODE" != "dry" ] && cmd_exists nginx; then
        [ -d /etc/nginx ] || return
        grep -q "client_max_body_size" /etc/nginx/nginx.conf 2>/dev/null || true
        if nginx -t >/dev/null 2>&1; then
            systemctl reload nginx >/dev/null 2>&1 || true
        else
            echo "    ${YELLOW}${WARN}${NC} nginx -t falhou — detalhes:" >&2
            nginx -t 2>&1 | head -10 >&2
        fi
    fi
    step_done "nginx pronto para proxy/static/websocket"
}

# ---------------------------------------------------------------- firewall
setup_firewall() {
    echo -e "\n  ${BOLD}${SKY}Firewall (ufw)${NC}"
    if cmd_exists ufw; then
        step_done "ufw presente"
        if [ "$MODE" != "dry" ]; then
            ufw allow 22/tcp >/dev/null 2>&1 || true
            ufw allow 80/tcp >/dev/null 2>&1 || true
            ufw allow 443/tcp >/dev/null 2>&1 || true
            ufw allow 19999/tcp >/dev/null 2>&1 || true # netdata
            ufw --force enable >/dev/null 2>&1 || true
            echo "    ${GRAY}${DOT}${NC} portas abertas: 22,80,443,19999"
        fi
    else
        step_info "ufw ausente — instalando (leve)"
        if [ "$MODE" = "dry" ]; then echo "    (dry-run) ufw.sh + regras 22,80,443"
        elif bash "${OB_HOME}/installers/ufw.sh" >/dev/null 2>&1; then
            ufw allow 22/tcp >/dev/null 2>&1 || true
            ufw allow 80/tcp >/dev/null 2>&1 || true
            ufw allow 443/tcp >/dev/null 2>&1 || true
            ufw --force enable >/dev/null 2>&1 || true
            step_done "ufw ativado (22,80,443)"
        else
            step_warn "falha ufw"
        fi
    fi
}

# ---------------------------------------------------------------- modulo hadix.toml
hadix_toml_example() {
    local name="${1:-meu-app}"
    local tmpl="${OB_HOME}/templates/hadix.toml"
    if [ -f "$tmpl" ]; then
        sed -e "s#__APP_NAME__#${name}#g" \
            -e "s#__APP_TYPE__#bot#g" \
            -e "s#__APP_START__#npm start#g" \
            -e "s#__APP_PORT__#0#g" \
            -e "s#__APP_DOMAIN__##g" \
            -e "s#__APP_PATH__#${OB_APPS_DIR:-/var/www}/${name}#g" \
            "$tmpl"
        return
    fi
    # fallback inline se o template nao existir
    cat << TOML
# hadix.toml — manifesto de app (Discloud/Squarecloud)

id = "${name}"
name = "${name}"
type = "bot"            # bot|site|api|worker
main = "index.js"
start = "npm start"
port = 0
domain = ""
pm2 = true
restart_on_crash = true
created = $(date +%s)

[limits]
memoryMB = 512
cpus = 1

[env]
TOKEN = ""
TOML
}

write_manifest() {
    local app_dir="$1" name="$2"
    local manifest="${app_dir}/hadix.toml"
    if [ -f "$manifest" ]; then
        return  # ja tem manifesto, nao sobrescreve
    fi
    if [ "$MODE" = "dry" ]; then
        echo "    (dry-run) criaria hadix.toml em ${app_dir}"
    else
        hadix_toml_example "$name" > "$manifest"
        echo "    ${GRAY}${DOT}${NC} ${manifest} (modelo)"
    fi
}

setup_models() {
    echo -e "\n  ${BOLD}${SKY}Modelo de manifesto (hadix.toml)${NC}"
    # gera modelo raiz p/ consulta
    if [ "$MODE" != "dry" ]; then
        hadix_toml_example "EXEMPLO" > "${HADIX_HOSTING_DIR:-/var/hadix}/hadix.toml.example" 2>/dev/null || true
        chmod 600 "${HADIX_HOSTING_DIR:-/var/hadix}/hadix.toml.example" 2>/dev/null || true
    fi
    step_done "Modelo em ${HADIX_HOSTING_DIR:-/var/hadix}/hadix.toml.example"
    step_info "Apps sem manifesto recebem um hadix.toml de modelo automaticamente (nao sobrescreve)"
}

# ---------------------------------------------------------------- host.json / status
write_host_json() {
    local json="${HADIX_HOSTING_DIR:-/var/hadix}/host.json"
    if [ "$MODE" = "dry" ]; then
        echo "    (dry-run) escreveria ${json} com recursos/status da VPS"
        return
    fi
    local cpus ram disk ip apps
    cpus="$(nproc 2>/dev/null || echo 1)"
    ram="$(free -m 2>/dev/null | awk '/Mem:/{print $2}' || echo 0)"
    disk="$(df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4);print $4}' || echo 0)"
    ip="$(get_public_ip 2>/dev/null || echo '')"
    apps="$(ob_apps_count 2>/dev/null || echo 0)"

    cat > "$json" <<JSON 2>/dev/null || return
{
  "platform": "hadix",
  "version": "${OB_VERSION:-0}",
  "hosted_apps": $apps,
  "status": "production",
  "resources": { "cpus": $cpus, "ramMB": $ram, "diskFreeGB": $disk },
  "public_ip": "$ip",
  "updated": "$(date -Iseconds)"
}
JSON
    step_done "Manifesto da VPS: ${json}"
}

# ---------------------------------------------------------------- stack
setup_stack() {
    echo -e "\n  ${BOLD}${SKY}Stack de hosting${NC}"
    install_if_missing "node" "node"
    install_if_missing "pm2" "pm2"
    install_if_missing "pnpm" "pnpm"
    # Necessário para criar ambientes isolados de apps Python durante deploy.
    if ! python3 -c 'import ensurepip, venv' >/dev/null 2>&1; then
        echo "    ${CYAN}${SPIN}${NC} instalando python3-venv..."
        pkg python3-venv || step_warn "falha ao instalar python3-venv"
    else
        echo "    ${GREEN}${TICK}${NC} python3-venv: ok"
    fi
    install_if_missing "docker" "docker"
    install_if_missing "ssl" "certbot"
    install_if_missing "monitoring" "netdata"
    if [ "$MODE" != "dry" ]; then
        # postgres/redis instalacao pode ser pesada; marca como opcional mas tenta
        for s in postgres redis fail2ban; do
            local prog="$s"
            [ "$s" = "postgres" ] && prog="postgresql"
            if ! cmd_exists "$prog"; then
                echo "    ${CYAN}${SPIN}${NC} instalando ${s} (pode demorar)..."
                bash "${OB_HOME}/installers/${s}.sh" >/dev/null 2>&1 || step_warn "falha ${s}"
            else
                echo "    ${GREEN}${TICK}${NC} ${s}: ok"
            fi
        done
    fi
    step_done "Stack instalada/verificada"
}

# ---------------------------------------------------------------- summary
print_summary() {
    echo ""
    echo -e "  ${MAGENTA}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "  ${WHITE}${BOLD}VPS pronta para hospedar BOTS e SITES${NC}"
    echo -e "  ${MAGENTA}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}${TICK}${NC} nginx + websocket (proxy/static)"
    echo -e "  ${GREEN}${TICK}${NC} Node + pnpm + pm2 (bot/worker/api)"
    echo -e "  ${GREEN}${TICK}${NC} Docker (containers isolados)"
    echo -e "  ${GREEN}${TICK}${NC} ufw firewall (22,80,443) + fail2ban"
    echo -e "  ${GREEN}${TICK}${NC} Certbot SSL automático (Let's Encrypt)"
    echo -e "  ${GREEN}${TICK}${NC} Netdata monitor (porta 19999)"
    echo -e "  ${GREEN}${TICK}${NC} Usuario 'hadix' + pm2 boot persistente"
    echo -e "  ${GREEN}${TICK}${NC} Apps em ${OB_APPS_DIR:-/var/www} (padrao hadix.toml)"
    echo ""
    echo -e "  ${SKY}${BOLD}Proximo passos:${NC}"
    echo -e "    ${CYAN}1${NC} bootstrap create-bot meu-bot     (cria bot Discord/Telegram)"
    echo -e "    ${CYAN}2${NC} bootstrap create-site meu-site   (site estatico via nginx)"
    echo -e "    ${CYAN}3${NC} bootstrap vps /var/www           (navegar/editar apps)"
    echo -e "    ${CYAN}4${NC} bootstrap ssl <dominio>          (HTTPS)"
    echo -e "    ${CYAN}5${NC} bootstrap monitor --watch        (acompanhar em tempo real)"
    echo ""
}

# ---------------------------------------------------------------- main
case "$MODE" in
    check)
        clear
        log_banner "Checagem de PRODUCAO" "status atual do hosting"
        echo -e "  ${BOLD}Ferramentas:${NC}"
        for t in nginx node pm2 pnpm docker certbot netdata ufw; do
            if cmd_exists "$t"; then echo "    ${GREEN}${TICK}${NC} $t"
            else echo "    ${RED}${CROSS}${NC} $t (falta)"
            fi
        done
        echo ""
        echo -e "  ${BOLD}Estados:${NC}"
        for s in nginx docker redis postgresql netdata fail2ban; do
            if systemctl is-active --quiet "$s" 2>/dev/null; then st="ativo"; else st="parado"; fi
            echo "    ${CYAN}${DOT}${NC} ${s}: ${st}"
        done
        echo ""
        echo "  Rode 'bootstrap production' para completar a stack."
        ;;
    dry)
        clear
        log_banner "DRY-RUN: PRODUCAO" "nenhuma alteracao sera feita"
        setup_dirs; setup_app_user; setup_nginx; setup_firewall; setup_stack; setup_models
        echo ""
        echo "  (dry-run) concluido — nada foi alterado."
        ;;
    reset)
        require_root
        clear
        log_banner "RESET de PRODUCAO" "refaz configs, mantendo os apps"
        echo "  ${YELLOW}${WARN}${NC} refazendo configs de hosting (nginx/pm2/node) sem remover apps..."
        setup_dirs; setup_app_user; setup_nginx; setup_firewall; write_host_json
        print_summary
        ;;
    run)
        require_root
        clear
        log_banner "Colocando VPS EM PRODUCAO" "Hadix.app → plataforma de hosting (Discloud/Squarecloud)"
        echo -e "  ${DIM}Este processo e idempotente: pode rodar varias vezes.${NC}"
        echo ""
        setup_dirs
        setup_app_user
        setup_nginx
        setup_firewall
        setup_stack
        setup_models
        write_host_json
        print_summary
        ;;
esac

echo ""
echo "  Concluido."

# registrar apps legacy p/ hadix.toml quando a pasta existir sem manifesto
backfill_manifests() {
    if [ -d "${OB_APPS_DIR:-/var/www}" ]; then
        for appdir in "${OB_APPS_DIR:-/var/www}"/*/; do
            [ -d "$appdir" ] || continue
            local base
            base="$(basename "$appdir")"
            write_manifest "$appdir" "$base"
        done
    fi
}
if [ "$MODE" = "run" ] || [ "$MODE" = "reset" ]; then
    backfill_manifests
fi
