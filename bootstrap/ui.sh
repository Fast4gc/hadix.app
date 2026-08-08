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

# Linha repetida de um caractere
repeat_char() {
    local count="$1" ch="$2"
    [ "$count" -lt 0 ] && count=0
    printf '%*s' "$count" '' | tr ' ' "$ch"
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
    echo -e "  ${color}$(repeat_char 40 "─")${NC}"
}

# Separador horizontal fino
separator() {
    local w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90
    echo -e "  ${GRAY}$(repeat_char $((w - 4)) "─")${NC}"
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
    echo -e "${color}$(repeat_char "$left" "─")${NC} [ ${BOLD}${text}${NC} ] ${color}$(repeat_char "$right" "─")${NC}"
}

# Mensagem de boas-vindas / cabecalho com versao e atualizacao
panel_header() {
    local version="$1" update="$2" w
    w="$(term_width)"
    [ "$w" -gt 90 ] && w=90

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

    local line
    line="  ${BOLD}${WHITE}Hadix.app${NC} ${GRAY}${DOT}${NC} ${SKY}Painel de VPS${NC} ${GRAY}${DOT}${NC} ${DIM}deploy${NC} ${GRAY}${DOT}${NC} ${DIM}monitor${NC}"
    echo -e "$line"

    if [ -n "$update" ]; then
        echo -e "  ${YELLOW}${WARN}${NC} ${GOLD}Versao ${version}${NC} ${GRAY}${DOT}${NC} ${YELLOW}disponivel: ${BOLD}${update}${NC} ${GRAY}(rode 'hadix update')${NC}"
    else
        echo -e "  ${DIM}Versao ${BOLD}${version}${NC}${DIM}${NC} ${GRAY}${DOT}${NC} ${DIM}Linux VPS ready${NC}"
    fi
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
