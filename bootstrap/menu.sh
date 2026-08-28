#!/usr/bin/env bash
# menu.sh — painel interativo do Hadix.app (estilo TMY-SSH-PRO)
# Layout robusto com figlet/lolcat, caixas coloridas, secoes agrupadas.
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

# ================================================================ helpers TMY
HAS_FIGLET=false; command -v figlet >/dev/null 2>&1 && HAS_FIGLET=true
HAS_LOLCAT=false; command -v lolcat >/dev/null 2>&1 && HAS_LOLCAT=true

# Banner com fallback ASCII (estilo TMY)
show_banner() {
    local ver="$1" update="$2"
    if $HAS_FIGLET; then
        if $HAS_LOLCAT; then
            figlet -k "HADIX.APP" 2>/dev/null | lolcat
        else
            figlet -k "HADIX.APP" 2>/dev/null
            echo -e "${MAGENTA}${BOLD}"
        fi
    else
        echo -e "${MAGENTA}${BOLD}"
        cat << 'ASCII'
   _   _           _ _            _       _
  | | | | __ _  __| (_)_  __   __| | __ _| |_ __ _
  | |_| |/ _` |/ _` | \ \/ /  / _` |/ _` | __/ _` |
  |  _  | (_| | (_| | |>  <  | (_| | (_| | || (_| |
  |_| |_|\__,_|\__,_|_/_/\_\  \__,_|\__,_|\__\__,_|
ASCII
    fi
    echo -e "${NC}"
    # versao + update
    if [ -n "$update" ]; then
        echo -e "  ${YELLOW}${WARN}${NC} ${GOLD}Versao ${ver}${NC} ${GRAY}${DOT}${NC} ${YELLOW}disponivel: ${BOLD}${update}${NC} ${GRAY}(rode 'hadix update')${NC}"
    else
        echo -e "  ${DIM}Versao ${BOLD}${ver}${NC}  ${GRAY}${DOT}${NC}  ${DIM}Hadix.app — VPS Platform${NC}"
    fi
}

# Caixa de titulo grossa (estilo TMY — ╔═╗)
thick_box() {
    local text="$1" color="${2:-${MAGENTA}}"
    local w=66
    echo -e "${color}${THICK_T}${THICK_T}$(repeat_char $((w - 4)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
    echo -e "${color}${THICK_V}${NC}  ${BOLD}${text}$(repeat_char $((w - ${#text} - 8)) ' ')${color}${THICK_V}${NC}"
    echo -e "${color}${THICK_T}${THICK_T}$(repeat_char $((w - 4)) "$THICK_T")${THICK_T}${THICK_T}${NC}"
}

# Separador de secao (─ ou =)
sec_br() {
    local color="${1:-${GRAY}}"
    echo -e "  ${color}$(repeat_char 66 "${THIN_T}")${NC}"
}

# Titulo de secao com estilo (ex: ═══ HOSTING ═══)
sec_title() {
    local label="$1" color="${2:-${SKY}}"
    echo ""
    echo -e "  ${color}${BOLD}${label}${NC}"
    echo -e "  ${color}$(repeat_char 66 "${THIN_T}")${NC}"
}

# Item de menu com numero, descricao e nota colorida
menu_item() {
    local num="$1" desc="$2" note="${3:-}"
    if [ -n "$note" ]; then
        printf "  ${CYAN}%2s${NC}  %-38s ${GRAY}%s${NC}\n" "$num" "$desc" "$note"
    else
        printf "  ${CYAN}%2s${NC}  %s\n" "$num" "$desc"
    fi
}

# Footer padrao de menu
menu_footer() {
    echo ""
    echo -e "  ${DIM}Digite o numero da opcao e ENTER.  0 para sair/voltar.${NC}"
    echo ""
}

# Linha de status do sistema (estilo dashboard)
status_line() {
    local ready_icon prod_note
    if command_exists nginx && command_exists node && command_exists pm2; then
        prod_note="${GREEN}${TICK} Producao pronta${NC}"
    else
        prod_note="${RED}${CROSS} Rode 'production'${NC}"
    fi
    local app_count
    app_count="$(ob_apps_count 2>/dev/null || echo 0)"
    local ping_info
    ping_info="$(ping_badge "$(vps_ping 2>/dev/null || echo '0 offline')")"
    echo ""
    echo -e "  ${GRAY}${DOT}${NC} Hosting: ${prod_note}   ${GRAY}|${NC} Apps: ${BOLD}${app_count}${NC}   ${GRAY}|${NC} ${ping_info}"
    sec_br
}

# ================================================================ submenus
installers_menu() {
    clear
    echo ""
    fly_box "Instaladores" "$GRAY"
    echo ""
    local list=(docker nginx node pnpm bun postgres redis fail2ban ufw cloudflare ssl pm2 github certbot monitoring)
    local i=1
    for item in "${list[@]}"; do
        printf "  ${CYAN}%2s${NC}  %s\n" "$i" "$item"
        i=$((i+1))
    done
    echo -e "  ${RED} 0${NC}  Voltar"
    echo ""
    local choice
    choice="$(ask "Escolha um componente" "")"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#list[@]}" ]; then
        require_root
        bash "${OB_HOME}/installers/${list[$((choice-1))]}.sh"
        read -r -p "Pressione ENTER para continuar..."
    fi
}

# Caixa simples (fly) para menus internos
fly_box() {
    local text="$1" color="${2:-${GRAY}}"
    local w=66
    echo -e "${color}${THIN_T}${THIN_T}$(repeat_char $((w - 4)) "$THIN_T")${THIN_T}${THIN_T}${NC}"
    echo -e "${color}${THIN_V}${NC}  ${BOLD}${text}$(repeat_char $((w - ${#text} - 8)) ' ')${color}${THIN_V}${NC}"
    echo -e "${color}${THIN_T}${THIN_T}$(repeat_char $((w - 4)) "$THIN_T")${THIN_T}${THIN_T}${NC}"
}

create_menu() {
    clear
    echo ""
    fly_box "Criar novo projeto" "$CYAN"
    echo ""
    menu_item "1" "API (Node/Express)" "nginx + pm2"
    menu_item "2" "Bot (Discord/Telegram)" "pm2"
    menu_item "3" "Site estatico" "nginx"
    menu_item "4" "Worker em background" "pm2"
    menu_item "5" "A partir de template" "nextjs, vite, express, ..."
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    case "$choice" in
        1) bash "${OB_HOME}/commands/create-api.sh" ;;
        2) bash "${OB_HOME}/commands/create-bot.sh" ;;
        3) bash "${OB_HOME}/commands/create-site.sh" ;;
        4) bash "${OB_HOME}/commands/create-worker.sh" ;;
        5)
            local tpl
            tpl="$(ask "Template (nextjs/vite/discord/express/nest/fastify/hono/python/go)" "")"
            bash "${OB_HOME}/commands/create.sh" "$tpl"
            ;;
        0|*) return ;;
    esac
    read -r -p "Pressione ENTER para continuar..."
}

pick_app_name() {
    local apps; apps="$(ob_apps_list 2>/dev/null)"
    if [ -z "$apps" ]; then
        ask "Nome do app" ""
        return
    fi
    local idx=1
    declare -A map
    # UI vai para stderr para nao contaminar o valor capturado em $(pick_app_name)
    echo "" >&2
    echo -e "  ${SKY}${BOLD}Apps registrados:${NC}" >&2
    while read -r app; do
        [ -z "$app" ] && continue
        local type port status
        type="$(jq -r --arg n "$app" '.[$n].type // "-"' "$OB_APPS_FILE" 2>/dev/null)"
        port="$(jq -r --arg n "$app" '.[$n].port // 0' "$OB_APPS_FILE" 2>/dev/null)"
        status="$(jq -r --arg n "$app" '.[$n].status // "-"' "$OB_APPS_FILE" 2>/dev/null)"
        printf "    ${CYAN}%2s${NC}  ${WHITE}%-18s${NC} ${GRAY}%s${NC} ${DIM}porta %s${NC} ${GRAY}[%s]${NC}\n" "$idx" "$app" "$type" "$port" "$status" >&2
        map[$idx]="$app"
        idx=$((idx+1))
    done <<< "$apps"
    echo "" >&2
    local input
    input="$(ask "Escolha numero ou digite nome (0=cancelar)" "")"
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -lt "$idx" ]; then
        echo "${map[$input]}"
    elif [ "$input" = "0" ] || [ -z "$input" ]; then
        echo ""
    else
        echo "$input"
    fi
}

manage_menu() {
    clear
    echo ""
    fly_box "Gerenciar apps" "$SKY"
    echo ""
    local count
    count="$(ob_apps_count 2>/dev/null || echo 0)"
    if [ "$count" -gt 0 ]; then
        echo -e "  ${BOLD}${SKY}Apps registrados (${count})${NC}"
        sec_br "$SKY"
        local i=1
        while read -r app; do
            [ -z "$app" ] && continue
            local type status
            type="$(jq -r --arg n "$app" '.[$n].type // "-"' "$OB_APPS_FILE" 2>/dev/null)"
            status="$(jq -r --arg n "$app" '.[$n].status // "-"' "$OB_APPS_FILE" 2>/dev/null)"
            local sc="$GREEN"; [ "$status" != "active" ] && sc="$YELLOW"
            printf "  ${GRAY}${DOT}${NC} ${WHITE}%-18s${NC} ${CYAN}%-8s${NC} ${sc}%s${NC}\n" "$app" "$type" "$status"
        done <<< "$(ob_apps_list)"
    else
        echo -e "  ${YELLOW}${WARN}${NC}  Nenhum app registrado ainda."
        echo -e "  ${DIM}Dica: crie via 'Criar novo projeto' ou registre em /var/www${NC}"
    fi
    echo ""
    menu_item "1" "Ver status dos apps" "tabela: tipo, processo, porta"
    menu_item "2" "Reiniciar app" "pm2/docker/systemd"
    menu_item "3" "Ver logs" "100 linhas, segue se TTY"
    menu_item "4" "Backup de app (ou todos)"
    menu_item "5" "Remover app"
    menu_item "6" "Emitir/renovar SSL"
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    local name
    case "$choice" in
        1) bash "${OB_HOME}/commands/status.sh" ;;
        2) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/restart.sh" "$name" ;;
        3) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/logs.sh" "$name" ;;
        4) name="$(pick_app_name)"; bash "${OB_HOME}/commands/backup.sh" "$name" ;;
        5) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/remove.sh" "$name" ;;
        6) name="$(ask "Dominio" "")"; bash "${OB_HOME}/commands/ssl.sh" "$name" ;;
       0|*) return ;;
    esac
    read -r -p "Pressione ENTER para continuar..."
}

# ================================================================ main
main_menu() {
    local update_available="$(ob_version_check)"
    while true; do
        clear
        show_banner "$(ob_version)" "$update_available"
        status_line

        sec_title "HOSTING" "$GREEN"
        menu_item "1 " "Colocar VPS em producao" "stack completa → hospedar bots/sites"
        menu_item "2 " "Dashboard central" "contas, planos, apps, nodes"
        menu_item "3 " "Monitorar VPS" "--watch"
        menu_item "4 " "Front hadix.site" "prod / dev / ping"

        sec_title "CRIAR" "$SKY"
        menu_item "5 " "Criar novo projeto" "api, bot, site, worker, template"
        menu_item "6 " "Instalar componentes" "docker, nginx, node, ..."

        sec_title "GERENCIAR" "$YELLOW"
        menu_item "7 " "Ver status dos apps" "tabela tipo/processo/porta"
        menu_item "8 " "Gerenciar apps existentes" "logs, restart, backup, ssl"
        menu_item "9 " "Navegar VPS" "arquivos, deploy, nginx, pm2"

        sec_title "SISTEMA" "$MAGENTA"
        menu_item "10" "Ajuda e comandos rapidos"
        menu_item "11" "Iniciar/provisionar app" "sobe app registrado via pm2"
        menu_item "12" "Atualizar Hadix.app"
        menu_item "0 " "Sair"

        menu_footer
        local choice
        choice="$(ask "Escolha uma opcao" "")"
        case "$choice" in
            1) bash "${OB_HOME}/commands/production.sh"; read -r -p "Pressione ENTER para continuar..." ;;
            2) bash "${OB_HOME}/commands/dashboard.sh" ;;
            3) bash "${OB_HOME}/commands/monitor.sh" --watch; read -r -p "Pressione ENTER para voltar..." ;;
            4) bash "${OB_HOME}/commands/front.sh" ;;
            5) create_menu ;;
            6) installers_menu ;;
            7) bash "${OB_HOME}/commands/status.sh"; read -r -p "Pressione ENTER para continuar..." ;;
            8) manage_menu ;;
            9) bash "${OB_HOME}/commands/vps.sh" ;;
            10) bash "${OB_HOME}/bootstrap/bootstrap.sh" --help; read -r -p "Pressione ENTER para voltar..." ;;
            11) bash "${OB_HOME}/commands/start.sh"; read -r -p "Pressione ENTER para continuar..." ;;
            12) bash "${OB_HOME}/update.sh"; read -r -p "Pressione ENTER para voltar..." ;;
            0) echo -e "${GREEN}${TICK}${NC} Ate mais! Hadix.app encerrado."; echo ""; exit 0 ;;
            *) ;;
        esac
    done
}

main_menu