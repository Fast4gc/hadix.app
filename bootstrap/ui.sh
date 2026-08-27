#!/usr/bin/env bash
# ui.sh — componentes visuais do painel Hadix.app
# Fornece funcoes de "maquiagem": boxes, titulos, separadores, spinner, banner.
set -uo pipefail

# Largura do terminal (fallback 90)
term_width() {
    if command_exists tput; then
        tput cols 2>/dev/null || echo 90
    else
        echo 90
    fi
}

# Linha repetida de um caractere (seguro p/ ASCII e UTF-8)
repeat_char() {
    local count="$1" ch="$2"
    [ "$count" -lt 0 ] && count=0
    # se ch for multi-char UTF-8, tr nao funciona bem -> usa loop
    if [ "${#ch}" -gt 1 ] || [[ "$ch" == *"�"* ]]; then
        # fallback ASCII ja definido em colors.sh
        ch="-"
    fi
    if [ "${#ch}" -eq 1 ]; then
        printf '%*s' "$count" '' | tr ' ' "$ch"
    else
        local out=""; local i; for ((i=0;i<count;i++)); do out+="$ch"; done; printf '%s' "$out"
    fi
}

# Titulo centralizado dentro de uma "caixa" de largura w
center_text() {
    local w="$1" text="$2"
    local len
    len="$(echo -ne "${text}" | wc -c)"
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    local right=$((w - len - pad))
    [ "$right" -lt 0 ] && right=0
    printf '%s%s%s' "$(repeat_char "$pad" ' ')" "$text" "$(repeat_char "$right" ' ')"
}

# Box de titulo: 1 linha, com bordas e texto centralizado
box_title() {
    local text="$1" color="${2:-${CYAN}}" w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90
    echo -e "${color}${THICK_T}${THICK_T}$(repeat_char $((w - 4)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
    echo -e "${color}${THICK_V}${NC} $(center_text $((w - 4)) "${BOLD}${text}${NC}") ${color}${THICK_V}${NC}"
    echo -e "${color}${THICK_T}${THICK_T}$(repeat_char $((w - 4)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
}

# Titulo pequeno de secao com cor
section_title() {
    local text="$1" color="${2:-${CYAN}}"
    echo ""
    echo -e "  ${color}${BOLD}${DOT} ${text}${NC}"
    echo -e "  ${color}$(repeat_char 40 "$THIN_T")${NC}"
}

# Separador horizontal fino
separator() {
    local w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90
    echo -e "  ${GRAY}$(repeat_char $((w - 4)) "$THIN_T")${NC}"
}

# Linha de separacao com texto (ex: ----[ Menu ]----)
rule() {
    local text="$1" color="${2:-${GRAY}}" w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90
    local left right total
    total=$((w - 6))
    left=$(( (total - ${#text}) / 2 ))
    right=$((total - left - ${#text}))
    echo -e "${color}$(repeat_char "$left" "$THIN_T")${NC} [ ${BOLD}${text}${NC} ] ${color}$(repeat_char "$right" "$THIN_T")${NC}"
}

# Ping da VPS ate o front oficial (hadix.site): mede latencia e status.
# Imprime: <ms> <status> onde status = ok|delay|offline
vps_ping() {
    local url="${OB_FRONT_URL:-https://hadix.site}"
    local timeout="${OB_PING_TIMEOUT:-6}" ms code
    local result
    result="$(curl -o /dev/null -s -w '%{time_total} %{http_code}' --max-time "$timeout" -k "$url" 2>/dev/null)"
    ms="$(awk '{print $1}' <<< "$result")"
    code="$(awk '{print $2}' <<< "$result")"
    if [ -z "$ms" ] || [ -z "$code" ] || [ "$code" = "000" ]; then
        echo "0 offline"
    else
        local mstxt
        mstxt="$(awk -v t="$ms" 'BEGIN { printf "%.0f", t*1000 }')"
        if [ "$mstxt" -lt "${OB_PING_DELAY:-800}" ]; then
            echo "$mstxt ok"
        else
            echo "$mstxt delay"
        fi
    fi
}

# Formata o status do ping como bolha colorida de dashboard
ping_badge() {
    local line="$1" ms status
    line="${line:-0 offline}"
    ms="$(echo "$line" | awk '{print $1}')"
    status="$(echo "$line" | awk '{print $2}')"
    case "$status" in
        ok)      echo -e "${GREEN}${BG_DARK} VPS OK ${NC} ${DIM}${ms}ms${NC}" ;;
        delay)   echo -e "${YELLOW}${BG_DARK} VPS COM DELAY ${NC} ${DIM}${ms}ms${NC}" ;;
        offline) echo -e "${RED}${BG_DARK} VPS OFFLINE ${NC}" ;;
        *)       echo -e "${GRAY}${BG_DARK} sem resposta ${NC}" ;;
    esac
}

# Mensagem de boas-vindas / cabecalho com versao e atualizacao
panel_header() {
    local version="$1" update="$2" w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90

    echo ""
    # ASCII simples: evita quebras em web console; usa logo limpo
    if [ "${THICK_T:-}" != "=" ]; then
        echo -e "${MAGENTA}${BOLD}"
        cat << 'ASCII'
   _   _           _ _            _       _
  | | | | __ _  __| (_)_  __   __| | __ _| |_ __ _
  | |_| |/ _` |/ _` | \ \/ /  / _` |/ _` | __/ _` |
  |  _  | (_| | (_| | |>  <  | (_| | (_| | || (_| |
  |_| |_|\__,_|\__,_|_/_/\_\  \__,_|\__,_|\__\__,_|
ASCII
        echo -e "${NC}"
    else
        echo -e "${MAGENTA}${BOLD}  HADIX.APP — Painel de VPS${NC}"
    fi

    local line
    line="  ${BOLD}${WHITE}Hadix.app${NC} ${GRAY}${DOT}${NC} ${SKY}Painel de VPS${NC} ${GRAY}${DOT}${NC} ${DIM}deploy${NC} ${GRAY}${DOT}${NC} ${DIM}monitor${NC}"
    echo -e "$line"

    if [ -n "$update" ]; then
        echo -e "  ${YELLOW}${WARN}${NC} ${GOLD}Versao ${version}${NC} ${GRAY}${DOT}${NC} ${YELLOW}disponivel: ${BOLD}${update}${NC} ${GRAY}(rode 'hadix update')${NC}"
    else
        echo -e "  ${DIM}Versao ${BOLD}${version}${NC}${DIM}${NC} ${GRAY}${DOT}${NC} ${DIM}Linux VPS ready${NC}"
    fi

    # ping nao deve travar header: timeout curto ja em vps_ping
    local ping_cached
    ping_cached="$(vps_ping 2>/dev/null || echo "0 offline")"
    echo -e "  ${GRAY}${DOT}${NC} Front: ${SKY}${OB_FRONT_URL:-https://hadix.site}${NC} ${GRAY}${DOT}${NC} $(ping_badge "$ping_cached")"
    echo ""
}

# Texto de status com "bolha" colorida (estilo dashboard)
badge() {
    local text="$1" color="$2"
    echo -e "${color}${BG_DARK} ${text} ${NC}"
}

# Spinner com mensagem (roda um comando e mostra OK/FALHOU)
spin() {
    local msg="$1" out="$2"
    shift 2
    echo -ne "  ${CYAN}${SPIN}${NC} ${DIM}${msg}...${NC}"
    if "$@" >>"$out" 2>&1; then
        echo -e "\r  ${GREEN}${TICK}${NC} ${msg} ${GREEN}OK${NC}"
    else
        echo -e "\r  ${RED}${CROSS}${NC} ${msg} ${RED}FALHOU${NC} (log: $out)"
        return 1
    fi
}

# Painel de sistema (hostname/ip/os) exibido no menu principal
_SYSINFO_IP=""
sysinfo() {
    local host os ip
    host="$(hostname 2>/dev/null || echo 'vps')"
    os="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-linux}" || echo 'linux')"
    if [ -z "$_SYSINFO_IP" ]; then
        _SYSINFO_IP="$(get_public_ip 2>/dev/null || echo '-')"
    fi
    ip="$_SYSINFO_IP"
    echo -e "  ${GRAY}${DOT}${NC} ${BOLD}${host}${NC} ${GRAY}|${NC} ${os} ${GRAY}|${NC} ${ip}"
}

# Opcao de menu com numero colorido e descricao, alinhada
menu_item() {
    local num="$1" desc="$2" note="${3:-}"
    if [ -n "$note" ]; then
        printf "  ${CYAN}%2s${NC}  %-44s ${GRAY}%s${NC}\n" "$num" "$desc" "$note"
    else
        printf "  ${CYAN}%2s${NC}  %s\n" "$num" "$desc"
    fi
}

# Footer padrao de menu
menu_footer() {
    echo ""
    echo -e "  ${DIM}Digite o numero da opcao e pressione ENTER. 0 para sair/voltar.${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Dashboard helpers — cards, barras, tabelas, status boxes
# ---------------------------------------------------------------------------

# Stat card: bloco compacto de metrica (label + valor + cor)
# Uso: stat_card "Contas" "42" "$GREEN"
stat_card() {
    local label="$1" value="$2" color="${3:-${CYAN}}"
    printf "  %s${BOLD}%-14s${NC} %s%b${NC}\n" "$color" "$label" "$color" "$value"
}

# Stat card inline (2 colunas lado a lado)
stat_pair() {
    local l1="$1" v1="$2" c1="$3" l2="$4" v2="$5" c2="$6"
    printf "  %s${BOLD}%-14s${NC} %s%b${NC}   %s${BOLD}%-14s${NC} %s%b${NC}\n" \
        "$c1" "$l1" "$c1" "$v1" "$c2" "$l2" "$c2" "$v2"
}

# Barra de progresso: [████████░░░░░░░░] 50% (fallback ASCII se sem UTF-8)
# Uso: progress_bar 50 100 20
progress_bar() {
    local current="$1" total="$2" width="${3:-20}"
    [ "$total" -gt 0 ] 2>/dev/null || total=1
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar="" i
    # escolhe chars conforme suporte UTF
    local fill_c="█" empty_c="░"
    if [ "${THICK_T:-}" = "=" ]; then fill_c="#" ; empty_c="-"; fi
    for ((i=0; i<filled; i++)); do bar+="$fill_c"; done
    for ((i=0; i<empty; i++)); do bar+="$empty_c"; done
    local color="$GREEN"
    [ "$pct" -gt 80 ] && color="$YELLOW"
    [ "$pct" -gt 95 ] && color="$RED"
    printf "  ${color}%s${NC} ${DIM}%3d%%${NC}" "$bar" "$pct"
}

# Barra horizontal de uso (bots/sites) com limite
usage_bar() {
    local used="$1" limit="$2" width="${3:-16}"
    [ "$limit" -gt 0 ] 2>/dev/null || limit=1
    local pct=$((used * 100 / limit))
    local filled=$((used * width / limit))
    [ "$filled" -gt "$width" ] && filled="$width"
    local empty=$((width - filled))
    local bar="" i
    local fill_c="█" empty_c="░"
    if [ "${THICK_T:-}" = "=" ]; then fill_c="#" ; empty_c="-"; fi
    for ((i=0; i<filled; i++)); do bar+="$fill_c"; done
    for ((i=0; i<empty; i++)); do bar+="$empty_c"; done
    local color="$GREEN"
    [ "$pct" -gt 70 ] && color="$YELLOW"
    [ "$pct" -gt 90 ] && color="$RED"
    printf "${color}%s${NC} ${DIM}%d/%d${NC}" "$bar" "$used" "$limit"
}

# Linha de tabela colorida com alinhamento
table_row() {
    local col1="$1" col2="$2" col3="$3" col4="${4:-}" col5="${5:-}"
    if [ -n "$col5" ]; then
        printf "  ${WHITE}%-18s${NC} ${CYAN}%-12s${NC} %-10s ${GRAY}%-20s${NC} %s\n" \
            "$col1" "$col2" "$col3" "$col4" "$col5"
    elif [ -n "$col4" ]; then
        printf "  ${WHITE}%-18s${NC} ${CYAN}%-12s${NC} %-10s %s\n" \
            "$col1" "$col2" "$col3" "$col4"
    else
        printf "  ${WHITE}%-18s${NC} ${CYAN}%-12s${NC} %s\n" \
            "$col1" "$col2" "$col3"
    fi
}

# Status badge de VPS node (online/offline/pending)
node_status_badge() {
    local status="$1"
    case "$status" in
        online)  echo -e "${GREEN}${BG_DARK} ONLINE ${NC}" ;;
        offline) echo -e "${RED}${BG_DARK} OFFLINE ${NC}" ;;
        pending) echo -e "${YELLOW}${BG_DARK} PENDENTE ${NC}" ;;
        *)       echo -e "${GRAY}${BG_DARK} ? ${NC}" ;;
    esac
}

# Status badge de plano (active/expired/expiring)
plan_status_badge() {
    local status="$1"
    case "$status" in
        active)   echo -e "${GREEN}${BG_DARK} ATIVO ${NC}" ;;
        expired)  echo -e "${RED}${BG_DARK} EXPIRADO ${NC}" ;;
        expiring) echo -e "${YELLOW}${BG_DARK} VENCENDO ${NC}" ;;
        *)        echo -e "${GRAY}${BG_DARK} ? ${NC}" ;;
    esac
}

# Box de secao do dashboard (titulo com borda)
dash_section() {
    local title="$1" icon="${2:-}"
    local w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90
    echo ""
    echo -e "  ${CYAN}${THICK_T}${THICK_T}$(repeat_char $((w - 6)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
    if [ -n "$icon" ]; then
        echo -e "  ${CYAN}${THICK_V}${NC}  ${BOLD}${icon} ${title}${NC}$(repeat_char $((w - ${#title} - ${#icon} - 8)) ' ')${CYAN}${THICK_V}${NC}"
    else
        echo -e "  ${CYAN}${THICK_V}${NC}  ${BOLD}${title}${NC}$(repeat_char $((w - ${#title} - 8)) ' ')${CYAN}${THICK_V}${NC}"
    fi
    echo -e "  ${CYAN}${THICK_T}${THICK_T}$(repeat_char $((w - 6)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
}

# Resumo compacto de sistema (CPU, RAM, disco) em uma linha
sys_summary_line() {
    local cpu_load mem_info disk_info cpu_pct
    cpu_load="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "?")"
    mem_info="$(free -h 2>/dev/null | awk '/Mem: {print $3"/"$2}' || echo "?")"
    disk_info="$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "?")"
    cpu_pct="$(awk -v l="$cpu_load" '{printf "%.0f", l/NF*100}' /proc/loadavg 2>/dev/null || echo "?")"
    printf "  ${GRAY}CPU${NC} ${BOLD}%s%%${NC} ${GRAY}|${NC} ${GRAY}RAM${NC} ${BOLD}%s${NC} ${GRAY}|${NC} ${GRAY}Disco${NC} ${BOLD}%s${NC}" \
        "$cpu_pct" "$mem_info" "$disk_info"
}
