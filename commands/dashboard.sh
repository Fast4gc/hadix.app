#!/usr/bin/env bash
# commands/dashboard.sh — painel central de gerenciamento Hadix.app
#
# Uso:
#   bootstrap dashboard                   abre o painel completo
#   bootstrap dashboard --refresh         atualiza status dos nodes e repinta
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
source "${OB_HOME}/bootstrap/version.sh"
source "${OB_HOME}/bootstrap/ui.sh"
ob_config_init

trap 'echo; echo -e "${YELLOW}Voltando ao painel Hadix.app...${NC}"; sleep 1' INT

FRONT_URL="${OB_FRONT_URL:-https://hadix.site}"
FRONT_DIR="${OB_FRONT_DIR:-/var/www/hadix-front}"

# ---------------------------------------------------------------------------
# Helpers locais
# ---------------------------------------------------------------------------

bytes_to_human() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN { split("B KB MB GB TB", u); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf "%.1f %s", b, u[i] }'
}

service_state() {
    local svc="$1"
    if ! command_exists systemctl; then
        echo "indisponivel"
    elif systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "ativo"
    else
        echo "parado"
    fi
}

service_state_color() {
    local state="$1"
    case "$state" in
        ativo)        echo -e "${GREEN}${TICK} ativo${NC}" ;;
        parado)       echo -e "${RED}${CROSS} parado${NC}" ;;
        indisponivel) echo -e "${GRAY}${DOT} indisponivel${NC}" ;;
    esac
}

# Ping da VPS ate o front
front_latency() {
    local code ms
    ms="$(curl -o /dev/null -s -w '%{time_total}' --max-time "${OB_PING_TIMEOUT:-6}" -k "$FRONT_URL" 2>/dev/null)"
    code="$(curl -o /dev/null -s -w '%{http_code}' --max-time "${OB_PING_TIMEOUT:-6}" -k "$FRONT_URL" 2>/dev/null)"
    if [ -z "$ms" ] || [ -z "$code" ] || [ "$code" = "000" ]; then
        echo "0"
    else
        awk -v t="$ms" 'BEGIN { printf "%.0f", t*1000 }'
    fi
}

front_status_line() {
    local ms="${1:-$(front_latency)}"
    if [ "$ms" -le 0 ]; then
        echo -e "${RED}${CROSS} OFFLINE${NC} ${DIM}(sem resposta)${NC}"
    elif [ "$ms" -lt "${OB_PING_DELAY:-800}" ]; then
        echo -e "${GREEN}${TICK} ONLINE${NC} ${DIM}${ms}ms${NC}"
    else
        echo -e "${YELLOW}${WARN} COM DELAY${NC} ${DIM}${ms}ms${NC}"
    fi
}

# ---------------------------------------------------------------------------
# Painel principal: visao geral
# ---------------------------------------------------------------------------

cmd_dashboard() {
    clear
    local w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90

    # --- Cabecalho ---
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    cat << 'ASCII'
   _   _           _ _            _       _
  | | | | __ _  __| (_)_  __   __| | __ _| |_ __ _
  | |_| |/ _` |/ _` | \ \/ /  / _` |/ _` | __/ _` |
  |  _  | (_| | (_| | |>  <  | (_| | (_| | || (_| |
  |_| |_|\__,_|\__,_|_/_/\_\  \__,_|\__,_|\__\__,_|
ASCII
    echo -e "${NC}"
    echo -e "  ${BOLD}${WHITE}Hadix.app${NC} ${GRAY}${DOT}${NC} ${SKY}Dashboard Central${NC} ${GRAY}${DOT}${NC} ${DIM}v${OB_VERSION}${NC}"
    echo -e "  ${DIM}$(date '+%d/%m/%Y %H:%M:%S')${NC}"

    # --- Servidor local ---
    dash_section "Servidor Local" "${DOT}"
    local hostname_uptime load cpu_line mem_line disk_line public_ip os_name kernel
    hostname_uptime="$(hostname 2>/dev/null || echo 'vps')"
    os_name="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-linux}" || echo 'linux')"
    kernel="$(uname -r 2>/dev/null || echo '?')"
    public_ip="$(get_public_ip 2>/dev/null || echo '?')"
    load="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || echo '?')"
    cpu_line="$(awk -F: '/model name/{gsub(/^ /,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null || echo '?')"
    mem_line="$(free -h 2>/dev/null | awk '/Mem:/ {print $3" / "$2" ("$7" livre)"}' || echo '?')"
    disk_line="$(df -h / 2>/dev/null | awk 'NR==2 {print $3" / "$2" usado ("$5")"}' || echo '?')"

    printf "  ${GRAY}%s${NC} ${BOLD}%s${NC}\n" "Host:" "$hostname_uptime"
    printf "  ${GRAY}%s${NC} %s ${GRAY}|${NC} %s ${GRAY}|${NC} ${SKY}%s${NC}\n" "Sistema:" "$os_name" "$kernel" "$public_ip"
    printf "  ${GRAY}%s${NC} %s\n" "CPU:" "$cpu_line"
    printf "  ${GRAY}%s${NC} %s\n" "RAM:" "$mem_line"
    printf "  ${GRAY}%s${NC} %s\n" "Disco:" "$disk_line"
    printf "  ${GRAY}%s${NC} %s\n" "Load:" "$load"

    # Servicos
    echo ""
    echo -e "  ${BOLD}Servicos${NC}"
    local svc_state svc_colored
    for svc in nginx docker redis postgresql fail2ban ufw; do
        svc_state="$(service_state "$svc")"
        svc_colored="$(service_state_color "$svc_state")"
        printf "    ${CYAN}%-12s${NC} %s\n" "$svc" "$svc_colored"
    done
    if command_exists pm2; then
        local pm2_count
        pm2_count="$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
        printf "    ${CYAN}%-12s${NC} ${GREEN}${TICK} ativo${NC} ${DIM}%s processos${NC}\n" "pm2" "$pm2_count"
    fi

    # --- Contas (usuarios do hadix.site) ---
    dash_section "Contas Hadix.site" "${INFO}"
    local total_users active_users expired_users expiring_users
    total_users="$(ob_users_count)"
    active_users="$(ob_users_active)"
    expired_users="$(ob_users_expired)"
    expiring_users="$(ob_users_expiring 7)"

    stat_pair "Total" "$total_users" "$WHITE" "Ativos" "$active_users" "$GREEN"
    stat_pair "Expirados" "$expired_users" "$RED" "Vencendo (7d)" "$expiring_users" "$YELLOW"

    # Usuarios por plano
    echo ""
    echo -e "  ${BOLD}Por plano${NC}"
    if [ "$(ob_plans_count)" -gt 0 ]; then
        while read -r plan_id; do
            local plan_name plan_count plan_price plan_currency
            plan_name="$(jq -r --arg p "$plan_id" '.[$p].name // $p' "$OB_PLANS_FILE")"
            plan_count="$(ob_users_by_plan "$plan_id")"
            plan_price="$(jq -r --arg p "$plan_id" '.[$p].price // 0' "$OB_PLANS_FILE")"
            plan_currency="$(jq -r --arg p "$plan_id" '.[$p].currency // "BRL"' "$OB_PLANS_FILE")"
            printf "    ${GRAY}%s${NC} ${BOLD}%d${NC} ${DIM}contas${NC} ${GRAY}— %s %s/mes${NC}\n" \
                "$plan_name" "$plan_count" "$plan_price" "$plan_currency"
        done <<< "$(ob_plans_list)"
    else
        echo -e "    ${DIM}Nenhum plano cadastrado${NC}"
    fi

    # --- Planos ---
    dash_section "Planos e Receita" "${INFO}"
    if [ "$(ob_plans_count)" -gt 0 ]; then
        while read -r plan_id; do
            local plan_name plan_price plan_currency plan_bots plan_sites plan_users plan_interval
            plan_name="$(jq -r --arg p "$plan_id" '.[$p].name // $p' "$OB_PLANS_FILE")"
            plan_price="$(jq -r --arg p "$plan_id" '.[$p].price // 0' "$OB_PLANS_FILE")"
            plan_currency="$(jq -r --arg p "$plan_id" '.[$p].currency // "BRL"' "$OB_PLANS_FILE")"
            plan_bots="$(jq -r --arg p "$plan_id" '.[$p].bots_limit // 0' "$OB_PLANS_FILE")"
            plan_sites="$(jq -r --arg p "$plan_id" '.[$p].sites_limit // 0' "$OB_PLANS_FILE")"
            plan_users="$(jq -r --arg p "$plan_id" '.[$p].active_users // 0' "$OB_PLANS_FILE")"
            plan_interval="$(jq -r --arg p "$plan_id" '.[$p].interval // "monthly"' "$OB_PLANS_FILE")"
            echo -e "  ${WHITE}${plan_name}${NC} ${GRAY}(${plan_interval})${NC}"
            printf "    ${GRAY}Preco:${NC} ${BOLD}%s %s${NC}  ${GRAY}Usuarios:${NC} ${BOLD}%d${NC}  ${GRAY}Bots:${NC} %d  ${GRAY}Sites:${NC} %d\n" \
                "$plan_price" "$plan_currency" "$plan_users" "$plan_bots" "$plan_sites"
            local revenue
            revenue="$(awk -v p="$plan_price" -v u="$plan_users" 'BEGIN { printf "%.2f", p*u }')"
            printf "    ${GREEN}Receita estimada:${NC} %s %s/mes\n" "$revenue" "$plan_currency"
        done <<< "$(ob_plans_list)"
    else
        echo -e "  ${DIM}Nenhum plano cadastrado ainda.${NC}"
        echo -e "  ${DIM}Use 'bootstrap dashboard add-plan' para cadastrar um plano.${NC}"
    fi
    local total_revenue
    total_revenue="$(ob_plans_total_revenue)"
    if [ "$total_revenue" -gt 0 ] 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}Total receita estimada: BRL ${total_revenue}/mes${NC}"
    fi

    # --- Bots e Sites hospedados ---
    dash_section "Bots e Sites Hospedados" "${DOT}"
    local total_apps bots_count sites_count api_count worker_count other_count
    total_apps="$(ob_apps_count)"
    bots_count="$(ob_apps_count_by_type "bot")"
    sites_count="$(ob_apps_count_by_type "site")"
    api_count="$(ob_apps_count_by_type "api" 2>/dev/null || echo 0)"
    worker_count="$(ob_apps_count_by_type "worker" 2>/dev/null || echo 0)"
    other_count="$(jq "[to_entries[] | select(.value.type != \"bot\" and .value.type != \"site\" and .value.type != \"api\" and .value.type != \"worker\")] | length" "$OB_APPS_FILE" 2>/dev/null || echo 0)"

    echo -e "  ${BOLD}Total: ${total_apps} apps${NC}"
    echo ""
    stat_pair "Bots" "$bots_count" "$MAGENTA" "Sites" "$sites_count" "$SKY"
    stat_pair "APIs" "$api_count" "$CYAN" "Workers" "$worker_count" "$ORANGE"
    [ "$other_count" -gt 0 ] && stat_pair "Outros" "$other_count" "$GRAY" "" "" ""

    # Uso vs limite
    local bots_used bots_limit sites_used sites_limit
    bots_used="$(ob_users_total_bots_used)"
    bots_limit="$(ob_users_total_bots_limit)"
    sites_used="$(ob_users_total_sites_used)"
    sites_limit="$(ob_users_total_sites_limit)"
    echo ""
    echo -e "  ${BOLD}Uso vs Limite${NC}"
    echo -ne "  ${GRAY}Bots: ${NC}"
    usage_bar "$bots_used" "$bots_limit" 20
    echo ""
    echo -ne "  ${GRAY}Sites:${NC}"
    usage_bar "$sites_used" "$sites_limit" 20
    echo ""

    # Top 5 apps
    if [ "$total_apps" -gt 0 ]; then
        echo ""
        echo -e "  ${BOLD}Top apps${NC}"
        local i=0
        while IFS= read -r line; do
            local app_name app_type app_status
            app_name="$(echo "$line" | jq -r '.key')"
            app_type="$(echo "$line" | jq -r '.value.type')"
            app_status="$(echo "$line" | jq -r '.value.status')"
            local status_color
            [ "$app_status" = "active" ] && status_color="$GREEN" || status_color="$RED"
            printf "    ${GRAY}%s${NC} ${CYAN}%-10s${NC} ${status_color}%-8s${NC}\n" \
                "$app_name" "$app_type" "$app_status"
            i=$((i + 1))
            [ "$i" -ge 8 ] && break
        done < <(jq -r 'to_entries | sort_by(.value.type) | .[] | @json' "$OB_APPS_FILE" 2>/dev/null | head -8)
        if [ "$total_apps" -gt 8 ]; then
            echo -e "    ${DIM}... e mais $((total_apps - 8)) apps${NC}"
        fi
    fi

    # --- Multi-VPS (Nodes) ---
    dash_section "Nodes Multi-VPS" "${DOT}"
    local nodes_total nodes_online nodes_offline
    nodes_total="$(ob_nodes_count)"
    nodes_online="$(ob_nodes_online)"
    nodes_offline="$(ob_nodes_offline)"

    if [ "$nodes_total" -gt 0 ]; then
        echo -e "  ${BOLD}Total: ${nodes_total} nodes${NC}  ${GREEN}Online: ${nodes_online}${NC}  ${RED}Offline: ${nodes_offline}${NC}"
        echo ""
        while read -r node_json; do
            local n_name n_ip n_region n_os n_status n_role n_apps n_cores n_ram n_disk
            n_name="$(echo "$node_json" | jq -r '.name')"
            n_ip="$(echo "$node_json" | jq -r '.ip')"
            n_region="$(echo "$node_json" | jq -r '.region')"
            n_os="$(echo "$node_json" | jq -r '.os')"
            n_status="$(echo "$node_json" | jq -r '.status')"
            n_role="$(echo "$node_json" | jq -r '.role')"
            n_apps="$(echo "$node_json" | jq -r '.apps_count // 0')"
            n_cores="$(echo "$node_json" | jq -r '.cpu_cores // 0')"
            n_ram="$(echo "$node_json" | jq -r '.ram_total // "?"')"
            n_disk="$(echo "$node_json" | jq -r '.disk_total // "?"')"
            echo -ne "  $(node_status_badge "$n_status") "
            echo -e "${WHITE}${n_name}${NC} ${GRAY}(${n_ip})${NC}"
            printf "    ${GRAY}%s${NC} ${CYAN}%s${NC} ${GRAY}Apps:${NC} ${BOLD}%s${NC} ${GRAY}CPU:${NC} %s ${GRAY}RAM:${NC} %s ${GRAY}Disco:${NC} %s\n" \
                "$n_region" "$n_os" "$n_apps" "$n_cores" "$n_ram" "$n_disk"
        done <<< "$(jq -c '.[]' "$OB_NODES_FILE" 2>/dev/null)"
    else
        echo -e "  ${DIM}Nenhum node configurado ainda.${NC}"
        echo -e "  ${DIM}Use 'bootstrap dashboard add-node' para adicionar uma VPS.${NC}"
    fi

    # --- Front ---
    dash_section "Front Hadix.site" "${SKY}"
    echo -ne "  ${GRAY}${RIGHT}${NC} ${FRONT_URL}  "
    echo -e "$(front_status_line)"
    if [ -d "$FRONT_DIR" ]; then
        echo -e "  ${GRAY}Dir:${NC} ${DIM}${FRONT_DIR}${NC}"
    fi
    echo ""

    # --- Footer ---
    separator
    echo -e "  ${DIM}Atualizado em $(date '+%d/%m/%Y %H:%M:%S') — 0 para voltar${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Submenu: gerenciamento rapido
# ---------------------------------------------------------------------------

cmd_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC}        ${BOLD}Hadix.app — Dashboard Gerenciamento${NC}               ${MAGENTA}${BOLD}║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    menu_item "1" "Ver dashboard completo" "visao geral"
    menu_item "2" "Gerenciar contas" "usuarios do hadix.site"
    menu_item "3" "Gerenciar planos" "planos de assinatura"
    menu_item "4" "Gerenciar nodes" "adicionar/remover VPS"
    menu_item "5" "Apps hospedados" "status, logs, restart"
    menu_item "6" "Navegar VPS" "arquivos e deploy"
    menu_item "7" "Monitorar VPS local" "--watch"
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    case "$choice" in
        1) cmd_dashboard ;;
        2) cmd_users ;;
        3) cmd_plans ;;
        4) cmd_nodes ;;
        5) cmd_apps ;;
        6) bash "${OB_HOME}/commands/vps.sh" ;;
        7) bash "${OB_HOME}/commands/monitor.sh" --watch ;;
        0|*) return ;;
    esac
    echo ""
    read -r -p "Pressione ENTER para continuar..."
}

# ---------------------------------------------------------------------------
# Submenu: gerenciar contas
# ---------------------------------------------------------------------------

cmd_users() {
    clear
    rule "Contas Hadix.site" "$SKY"
    echo ""
    local total active expired expiring
    total="$(ob_users_count)"
    active="$(ob_users_active)"
    expired="$(ob_users_expired)"
    expiring="$(ob_users_expiring 7)"
    echo -e "  ${BOLD}Total: ${total}${NC}  ${GREEN}Ativos: ${active}${NC}  ${RED}Expirados: ${expired}${NC}  ${YELLOW}Vencendo: ${expiring}${NC}"
    echo ""
    if [ "$total" -gt 0 ]; then
        printf "  ${GRAY}%-18s${NC} ${CYAN}%-12s${NC} %-10s %-14s${NC}\n" "USUARIO" "PLANO" "BOTS" "SITES"
        echo -e "  ${GRAY}$(repeat_char 60 "─")${NC}"
        while read -r line; do
            local uname uplan ubots_used ubots_limit usites_used usites_limit
            uname="$(echo "$line" | jq -r '.key')"
            uplan="$(echo "$line" | jq -r '.value.plan // "-"')"
            ubots_used="$(echo "$line" | jq -r '.value.bots_used // 0')"
            ubots_limit="$(echo "$line" | jq -r '.value.bots_limit // 0')"
            usites_used="$(echo "$line" | jq -r '.value.sites_used // 0')"
            usites_limit="$(echo "$line" | jq -r '.value.sites_limit // 0')"
            printf "  ${WHITE}%-18s${NC} ${CYAN}%-12s${NC} " "$uname" "$uplan"
            usage_bar "$ubots_used" "$ubots_limit" 8
            echo -ne "  "
            usage_bar "$usites_used" "$usites_limit" 8
            echo ""
        done < <(jq -r 'to_entries | sort_by(.key) | .[] | @json' "$OB_USERS_FILE" 2>/dev/null)
    else
        echo -e "  ${DIM}Nenhuma conta cadastrada.${NC}"
    fi
    echo ""
    echo -e "  ${DIM}Para adicionar: edite ${OB_USERS_FILE} ou use a API do hadix.site${NC}"
    echo -e "  ${DIM}Para editar: edite o JSON diretamente com 'hadix edit users'${NC}"
    echo ""
    menu_item "1" "Adicionar conta"
    menu_item "2" "Alterar status"
    menu_item "3" "Remover conta"
    menu_item "0" "Voltar"
    echo ""
    local choice
    choice="$(ask "Acao" "")"
    case "$choice" in
        1)
            local u n e d p bl sl
            u="$(slugify "$(ask "Usuario" "cliente")")"; n="$(ask "Nome" "$u")"; e="$(ask "Email" "")"; d="$(ask "Discord ID" "")"; p="$(ask "Plano" "starter")"
            bl="$(ask "Limite de bots" "1")"; sl="$(ask "Limite de sites" "1")"; ob_user_add "$u" "$n" "$e" "$d" "$p" "$bl" "$sl" ;;
        2) local u st; u="$(ask "Usuario" "")"; st="$(ask "Status (active/suspended)" "active")"; ob_user_set "$u" status "$st" ;;
        3) local u tmp; u="$(ask "Usuario" "")"; tmp="$(mktemp)"; jq --arg u "$u" 'del(.[$u])' "$OB_USERS_FILE" > "$tmp" && mv "$tmp" "$OB_USERS_FILE" ;;
        0|*) return ;;
    esac
}

# ---------------------------------------------------------------------------
# Submenu: gerenciar planos
# ---------------------------------------------------------------------------

cmd_plans() {
    clear
    rule "Planos Hadix.site" "$SKY"
    echo ""
    local total
    total="$(ob_plans_count)"
    echo -e "  ${BOLD}Total: ${total} planos${NC}"
    echo ""
    if [ "$total" -gt 0 ]; then
        while read -r plan_id; do
            local pname pprice pcurrency pinterval pbots psites pusers
            pname="$(jq -r --arg p "$plan_id" '.[$p].name // $p' "$OB_PLANS_FILE")"
            pprice="$(jq -r --arg p "$plan_id" '.[$p].price // 0' "$OB_PLANS_FILE")"
            pcurrency="$(jq -r --arg p "$plan_id" '.[$p].currency // "BRL"' "$OB_PLANS_FILE")"
            pinterval="$(jq -r --arg p "$plan_id" '.[$p].interval // "monthly"' "$OB_PLANS_FILE")"
            pbots="$(jq -r --arg p "$plan_id" '.[$p].bots_limit // 0' "$OB_PLANS_FILE")"
            psites="$(jq -r --arg p "$plan_id" '.[$p].sites_limit // 0' "$OB_PLANS_FILE")"
            pusers="$(jq -r --arg p "$plan_id" '.[$p].active_users // 0' "$OB_PLANS_FILE")"
            local revenue
            revenue="$(awk -v p="$pprice" -v u="$pusers" 'BEGIN { printf "%.2f", p*u }')"
            echo -e "  ${WHITE}${BOLD}${pname}${NC} ${GRAY}(${plan_id})${NC}"
            printf "    ${GRAY}Preco:${NC} ${BOLD}%s %s/%s${NC}  ${GRAY}Usuarios:${NC} ${BOLD}%d${NC}  ${GRAY}Bots:${NC} %d  ${GRAY}Sites:${NC} %d\n" \
                "$pprice" "$pcurrency" "$pinterval" "$pusers" "$pbots" "$psites"
            printf "    ${GREEN}Receita:${NC} %s %s/mes\n" "$revenue" "$pcurrency"
            echo ""
        done <<< "$(ob_plans_list)"
    else
        echo -e "  ${DIM}Nenhum plano cadastrado.${NC}"
    fi
    menu_item "1" "Adicionar plano"
    menu_item "2" "Remover plano"
    menu_item "0" "Voltar"
    echo ""
    local choice
    choice="$(ask "Acao" "")"
    case "$choice" in
        1) local id n pr c i bl sl f; id="$(slugify "$(ask "ID" "starter")")"; n="$(ask "Nome" "$id")"; pr="$(ask "Preco" "19.90")"; c="$(ask "Moeda" "BRL")"; i="$(ask "Intervalo" "monthly")"; bl="$(ask "Limite bots" "1")"; sl="$(ask "Limite sites" "1")"; f="$(ask "Features" "pm2,nginx,ssl")"; ob_plan_add "$id" "$n" "$pr" "$c" "$i" "$bl" "$sl" "$f" ;;
        2) local id; id="$(ask "ID do plano" "")"; ob_plan_remove "$id" ;;
        0|*) return ;;
    esac
}

# ---------------------------------------------------------------------------
# Submenu: gerenciar nodes
# ---------------------------------------------------------------------------

cmd_nodes() {
    clear
    rule "Nodes Multi-VPS" "$SKY"
    echo ""
    local total online offline
    total="$(ob_nodes_count)"
    online="$(ob_nodes_online)"
    offline="$(ob_nodes_offline)"
    echo -e "  ${BOLD}Total: ${total}${NC}  ${GREEN}Online: ${online}${NC}  ${RED}Offline: ${offline}${NC}"
    echo ""
    if [ "$total" -gt 0 ]; then
        local i=1
        while read -r node_json; do
            local n_name n_ip n_region n_os n_status n_role n_apps
            n_name="$(echo "$node_json" | jq -r '.name')"
            n_ip="$(echo "$node_json" | jq -r '.ip')"
            n_region="$(echo "$node_json" | jq -r '.region')"
            n_os="$(echo "$node_json" | jq -r '.os')"
            n_status="$(echo "$node_json" | jq -r '.status')"
            n_role="$(echo "$node_json" | jq -r '.role')"
            n_apps="$(echo "$node_json" | jq -r '.apps_count // 0')"
            echo -e "  $(node_status_badge "$n_status") ${WHITE}${BOLD}${n_name}${NC} ${GRAY}(${n_ip})${NC}"
            printf "    ${GRAY}Regiao:${NC} %s  ${GRAY}SO:${NC} %s  ${GRAY}Apps:${NC} %s  ${GRAY}Funcao:${NC} %s\n" \
                "$n_region" "$n_os" "$n_apps" "$n_role"
            i=$((i+1))
        done < <(jq -c '.[]' "$OB_NODES_FILE" 2>/dev/null)
    else
        echo -e "  ${DIM}Nenhum node configurado.${NC}"
    fi
    echo ""
    menu_item "1" "Adicionar node"
    menu_item "2" "Atualizar status"
    menu_item "3" "Remover node"
    menu_item "0" "Voltar"
    echo ""
    local choice
    choice="$(ask "Acao" "")"
    case "$choice" in
        1) local n ip r o role; n="$(slugify "$(ask "Nome" "node-1")")"; ip="$(ask "IP" "")"; r="$(ask "Regiao" "br")"; o="$(ask "Sistema" "linux")"; role="$(ask "Funcao" "worker")"; ob_node_add "$n" "$ip" "$r" "$o" "$role" ;;
        2) local n st; n="$(ask "Node" "")"; st="$(ask "Status (online/offline/pending)" "online")"; ob_node_set "$n" status "$st"; ob_node_set "$n" last_ping "$(date -Iseconds)" ;;
        3) local n; n="$(ask "Node" "")"; ob_node_remove "$n" ;;
        0|*) return ;;
    esac
}

cmd_apps() {
    clear
    rule "Apps Hospedados" "$SKY"
    echo ""
    local total; total="$(ob_apps_count)"
    echo -e "  ${BOLD}Total: ${total} apps${NC}"
    echo ""
    if [ "$total" -gt 0 ]; then
        printf "  ${GRAY}%-18s %-10s %-8s %-8s %-24s %s${NC}\n" "APP" "TIPO" "STATUS" "PORTA" "DOMINIO" "PATH"
        echo -e "  ${GRAY}$(repeat_char 86 "─")${NC}"
        while IFS= read -r line; do
            local n t st port domain path
            n="$(echo "$line" | jq -r '.key')"; t="$(echo "$line" | jq -r '.value.type // "-"')"; st="$(echo "$line" | jq -r '.value.status // "-"')"
            port="$(echo "$line" | jq -r '.value.port // 0')"; domain="$(echo "$line" | jq -r '.value.domain // "-"')"; path="$(echo "$line" | jq -r '.value.path // "-"')"
            printf "  ${WHITE}%-18s${NC} ${CYAN}%-10s${NC} %-8s %-8s %-24s ${DIM}%s${NC}\n" "$n" "$t" "$st" "$port" "$domain" "$path"
        done < <(jq -r 'to_entries | sort_by(.key) | .[] | @json' "$OB_APPS_FILE" 2>/dev/null)
    fi
    echo ""
    menu_item "1" "Logs"; menu_item "2" "Reiniciar"; menu_item "3" "Backup"; menu_item "4" "Remover"; menu_item "5" "Abrir pasta no navegador VPS"; menu_item "0" "Voltar"
    local choice name path
    choice="$(ask "Acao" "")"
    case "$choice" in
        1) name="$(ask "App" "")"; bash "${OB_HOME}/commands/logs.sh" "$name" ;;
        2) name="$(ask "App" "")"; bash "${OB_HOME}/commands/restart.sh" "$name" ;;
        3) name="$(ask "App" "")"; bash "${OB_HOME}/commands/backup.sh" "$name" ;;
        4) name="$(ask "App" "")"; bash "${OB_HOME}/commands/remove.sh" "$name" ;;
        5) name="$(ask "App" "")"; path="$(jq -r --arg n "$name" '.[$n].path // empty' "$OB_APPS_FILE")"; bash "${OB_HOME}/commands/vps.sh" "${path:-$OB_APPS_DIR}" ;;
        0|*) return ;;
    esac
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "${1:-}" in
    ""|panel|dashboard) cmd_menu ;;
    --refresh) cmd_dashboard; read -r -p "Pressione ENTER para voltar..." ;;
    users)    cmd_users ;;
    plans)    cmd_plans ;;
    nodes)    cmd_nodes ;;
    apps)     cmd_apps ;;
    *)        log_error "Uso: bootstrap dashboard [users|plans|nodes|apps|--refresh]" ;;
esac
