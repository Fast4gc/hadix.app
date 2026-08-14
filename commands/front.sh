#!/usr/bin/env bash
# commands/front.sh — exporta e valida o front Hadix (https://hadix.site)
#
# Uso:
#   bootstrap front                  painel do front (status + menu prod/dev)
#   bootstrap front status           apenas o ping/status da VPS + site
#   bootstrap front prod             build e publica em producao
#   bootstrap front dev              sobe em modo desenvolvimento
#   bootstrap front stop             derruba front prod/dev
#   bootstrap front log              acompanha logs (pm2)
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"; source "${OB_HOME}/bootstrap/ui.sh"
ob_config_init

FRONT_URL="${OB_FRONT_URL:-https://hadix.site}"
FRONT_DIR="${OB_FRONT_DIR:-/var/www/hadix-front}"
FRONT_REPO="${OB_FRONT_REPO:-https://github.com/Fast4gc/hadix-front.git}"
FRONT_PORT="${OB_FRONT_PORT:-3001}"
FRONT_NAME="hadix-front"

PING_TIMEOUT=6
DELAY_MS=800

# --- helpers ---------------------------------------------------------------

# Mede latencia ate a URL do front. Imprime "ms" (0 = sem resposta).
front_latency() {
    local code ms
    local result
    result="$(curl -o /dev/null -s -w '%{time_total} %{http_code}' --max-time "$PING_TIMEOUT" -k "$FRONT_URL" 2>/dev/null)"
    ms="$(awk '{print $1}' <<< "$result")"
    code="$(awk '{print $2}' <<< "$result")"
    if [ -z "$ms" ] || [ -z "$code" ] || [ "$code" = "000" ]; then
        echo "0"
    else
        awk -v t="$ms" 'BEGIN { printf "%.0f", t*1000 }'
    fi
}

# Classifica a latencia: ok / delay / offline
ping_status() {
    local ms="${1:-0}"
    if [ "$ms" -le 0 ]; then
        echo "offline"
    elif [ "$ms" -lt "$DELAY_MS" ]; then
        echo "ok"
    else
        echo "delay"
    fi
}

ping_icon() {
    local status="$1"
    case "$status" in
        ok)      echo "${GREEN}${TICK}${NC}" ;;
        delay)   echo "${YELLOW}${WARN}${NC}" ;;
        offline) echo "${RED}${CROSS}${NC}" ;;
        *)       echo "${GRAY}${DOT}${NC}" ;;
    esac
}

# Rótulo de status formatado (usado pelo menu e pela tela)
front_status_line() {
    local ms="${1:-$(front_latency)}"
    local status
    status="$(ping_status "$ms")"
    local icon
    icon="$(ping_icon "$status")"
    case "$status" in
        ok)      printf "%s ${GREEN}%s${NC} %s %sms" "$icon" "VPS OK" "${DIM}latencia${NC}" "$ms" ;;
        delay)   printf "%s ${YELLOW}%s${NC} %s %sms" "$icon" "VPS COM DELAY" "${DIM}latencia${NC}" "$ms" ;;
        offline) printf "%s ${RED}%s${NC} %s" "$icon" "VPS OFFLINE" "${DIM}(sem resposta do ${FRONT_URL})${NC}" ;;
    esac
}

front_ready() {
    [ -d "$FRONT_DIR" ] && [ -f "${FRONT_DIR}/package.json" ]
}

ensure_front() {
    if ! front_ready; then
        log_step "Clonando front para ${FRONT_DIR}"
        mkdir -p "$(dirname "$FRONT_DIR")"
        git clone --depth 1 "$FRONT_REPO" "$FRONT_DIR" 2>/dev/null \
            || { log_error "Falha ao clonar ${FRONT_REPO}"; exit 1; }
    fi
}

ensure_node() { command_exists node || bash "${OB_HOME}/installers/node.sh"; }

front_build_script() {
    # Detecta o gerenciador de pacotes do front
    if [ -f "${FRONT_DIR}/pnpm-lock.yaml" ]; then echo "pnpm"
    elif [ -f "${FRONT_DIR}/bun.lockb" ] || [ -f "${FRONT_DIR}/bun.lock" ]; then echo "bun"
    else echo "npm"; fi
}

install_deps() {
    local pm
    pm="$(front_build_script)"
    case "$pm" in
        pnpm) (cd "$FRONT_DIR" && pnpm install --frozen-lockfile) ;;
        bun)  (cd "$FRONT_DIR" && bun install --frozen-lockfile) ;;
        *)    (cd "$FRONT_DIR" && npm ci || npm install) ;;
    esac
}

front_has_build() {
    [ -d "${FRONT_DIR}/dist" ] || [ -d "${FRONT_DIR}/.next" ] || [ -d "${FRONT_DIR}/build" ] || [ -d "${FRONT_DIR}/out" ]
}

front_build_out() {
    # Caminho do artefato estatico gerado (dist/.next/out/build)
    if [ -d "${FRONT_DIR}/dist" ]; then echo "${FRONT_DIR}/dist"
    elif [ -d "${FRONT_DIR}/out" ]; then echo "${FRONT_DIR}/out"
    elif [ -d "${FRONT_DIR}/build" ]; then echo "${FRONT_DIR}/build"
    elif [ -d "${FRONT_DIR}/.next" ]; then echo "${FRONT_DIR}/.next"
    else echo ""; fi
}

publish_nginx() {
    # Publica o build estatico do front no dominio oficial via nginx
    local root="$1"
    command_exists nginx || bash "${OB_HOME}/installers/nginx.sh"
    sed -e "s#__DOMAIN__#${FRONT_URL#https://}#g" -e "s#__ROOT_PATH__#${root}#g" -e "s#__APP_NAME__#${FRONT_NAME}#g" \
        "${OB_HOME}/templates/nginx/static.conf" > "/etc/nginx/sites-available/${FRONT_NAME}.conf"
    ln -sf "/etc/nginx/sites-available/${FRONT_NAME}.conf" "/etc/nginx/sites-enabled/${FRONT_NAME}.conf"
    nginx -t && systemctl reload nginx
}

# --- acoes -----------------------------------------------------------------

cmd_status() {
    local ms
    ms="$(front_latency)"
    echo ""
    printf "  %s  %s\n" "${SKY}${RIGHT}${NC}" "$(front_status_line "$ms")"
    printf "  %s  ${DIM}%s${NC}\n" "${GRAY}${DOT}${NC}" "URL: ${FRONT_URL}"
    printf "  %s  ${DIM}%s${NC}\n" "${GRAY}${DOT}${NC}" "Diretorio: ${FRONT_DIR}"
    if front_ready; then
        printf "  %s  ${DIM}%s${NC}\n" "${GRAY}${DOT}${NC}" "Front: sincronizado (package.json presente)"
    else
        printf "  %s  ${YELLOW}%s${NC}\n" "${GRAY}${DOT}${NC}" "Front: ainda nao clonado (rode 'bootstrap front prod/dev')"
    fi
    echo ""
}

cmd_prod() {
    require_root
    ensure_front
    ensure_node
    log_step "Front → PRODUCAO (${FRONT_URL})"
    echo -e "  ${DIM}Atualizando codigo...${NC}"
    (cd "$FRONT_DIR" && git pull --ff-only 2>/dev/null || true)
    log_step "Instalando dependencias"
    install_deps || { log_error "Falha nas dependencias"; exit 1; }
    log_step "Gerando build de producao"
    local pm
    pm="$(front_build_script)"
    local build_ok
    case "$pm" in
        pnpm) (cd "$FRONT_DIR" && pnpm build) ;;
        bun)  (cd "$FRONT_DIR" && bun run build) ;;
        *)    (cd "$FRONT_DIR" && npm run build) ;;
    esac
    build_ok=$?
    if [ "$build_ok" -ne 0 ]; then
        log_error "Build falhou."
        exit 1
    fi
    local out
    out="$(front_build_out)"
    if [ -n "$out" ]; then
        log_step "Publicando estatico no nginx (${out})"
        publish_nginx "$out"
        if command_exists pm2 && pm2 describe "$FRONT_NAME" >/dev/null 2>&1; then
            pm2 delete "$FRONT_NAME" >/dev/null 2>&1
        fi
        log_ok "Front publicado em ${FRONT_URL}"
    else
        log_step "Front roda via servidor Node → iniciando com pm2 na porta ${FRONT_PORT}"
        command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
        if command_exists pm2 && pm2 describe "$FRONT_NAME" >/dev/null 2>&1; then
            pm2 restart "$FRONT_NAME"
        else
            (cd "$FRONT_DIR" && PORT="$FRONT_PORT" pm2 start "npm run start -- -p ${FRONT_PORT}" --name "$FRONT_NAME")
        fi
        pm2 save
        log_ok "Front iniciado na porta ${FRONT_PORT}"
    fi
    echo ""
    log_step "Checando ping pos-deploy"
    sleep 2
    cmd_status
}

cmd_dev() {
    require_root
    ensure_front
    ensure_node
    command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
    log_step "Front → DESENVOLVIMENTO (porta ${FRONT_PORT})"
    (cd "$FRONT_DIR" && git pull --ff-only 2>/dev/null || true)
    install_deps || { log_error "Falha nas dependencias"; exit 1; }
    local pm
    pm="$(front_build_script)"
    case "$pm" in
        pnpm) (cd "$FRONT_DIR" && PORT="$FRONT_PORT" pm2 start "pnpm dev -- -p ${FRONT_PORT}" --name "$FRONT_NAME-dev") ;;
        bun)  (cd "$FRONT_DIR" && PORT="$FRONT_PORT" pm2 start "bun run dev -- -p ${FRONT_PORT}" --name "$FRONT_NAME-dev") ;;
        *)    (cd "$FRONT_DIR" && PORT="$FRONT_PORT" pm2 start "npm run dev -- -p ${FRONT_PORT}" --name "$FRONT_NAME-dev") ;;
    esac
    pm2 save
    log_ok "Dev server ativo: http://localhost:${FRONT_PORT}"
    log_info "Producao continua em ${FRONT_URL}"
}

cmd_stop() {
    require_root
    if command_exists pm2; then
        pm2 delete "$FRONT_NAME" >/dev/null 2>&1
        pm2 delete "$FRONT_NAME-dev" >/dev/null 2>&1
    fi
    [ -f "/etc/nginx/sites-enabled/${FRONT_NAME}.conf" ] && rm -f "/etc/nginx/sites-enabled/${FRONT_NAME}.conf"
    command_exists nginx && nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null
    log_ok "Front ${FRONT_NAME} parado."
}

cmd_clean() {
    require_root
    if [ ! -d "$FRONT_DIR" ]; then
        log_info "Front ainda nao existe em ${FRONT_DIR}."
        return 0
    fi
    log_step "Limpando caches e artefatos pesados do front"
    rm -rf "${FRONT_DIR}/node_modules" "${FRONT_DIR}/.next/cache" "${FRONT_DIR}/dist" "${FRONT_DIR}/build" "${FRONT_DIR}/out"
    if command_exists npm; then npm cache clean --force >/dev/null 2>&1 || true; fi
    if command_exists pnpm; then pnpm store prune >/dev/null 2>&1 || true; fi
    log_ok "Limpeza concluida. Rode 'bootstrap front prod' para reconstruir quando precisar."
}

cmd_log() {
    command_exists pm2 || { log_error "pm2 nao instalado."; exit 1; }
    pm2 logs "${FRONT_NAME}${2:+-$2}" --lines 50
}

cmd_panel() {
    clear
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC}       ${BOLD}Hadix.app — Front ${FRONT_URL}${NC}           ${MAGENTA}${BOLD}║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    local ms
    ms="$(front_latency)"
    echo -e "  ${BOLD}Status:${NC} $(front_status_line "$ms")"
    echo ""
    menu_item "1" "Exportar para producao" "build + nginx/pm2 → ${FRONT_URL}"
    menu_item "2" "Rodar em desenvolvimento" "dev server na porta ${FRONT_PORT}"
    menu_item "3" "Status / ping da VPS" "latencia ate ${FRONT_URL}"
    menu_item "4" "Parar front" "derruba prod e dev"
    menu_item "5" "Logs (pm2)"
    menu_item "6" "Limpar caches/build" "libera disco"
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    case "$choice" in
        1) cmd_prod ;;
        2) cmd_dev ;;
        3) cmd_status ;;
        4) cmd_stop ;;
        5) cmd_log ;;
        6) cmd_clean ;;
        0|*) return ;;
    esac
    echo ""
    read -r -p "Pressione ENTER para continuar..."
}

case "${1:-}" in
    ""|panel)   cmd_panel ;;
    status|ping) cmd_status ;;
    prod)       cmd_prod ;;
    dev)        cmd_dev ;;
    stop)       cmd_stop ;;
    log)        cmd_log ;;
    clean)      cmd_clean ;;
    *)          log_error "Uso: bootstrap front [status|prod|dev|stop|log|clean]" ;;
esac
