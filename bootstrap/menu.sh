#!/usr/bin/env bash
# menu.sh — painel interativo do Hadix.app (visual profissional, secoes agrupadas)
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

# ================================================================ helpers de layout
menu_br() { echo -e "  ${GRAY}${THIN_T}$(repeat_char 70 "$THIN_T")${NC}"; }

menu_header() {
    # Titulo do grupo (ex: ── Hosting ──)
    local label="$1"
    echo ""
    echo -e "  ${SKY}${BOLD}${label}${NC}"
    echo -e "  ${SKY}${THIN_T}$(repeat_char 70 "$THIN_T")${NC}"
}

menu_item_alias() { # numero | principal | secundario | nota
    local num="$1" desc="$2" note="${3:-}"
    if [ -n "$note" ]; then
        printf "  ${CYAN}%2s${NC}  %-42s ${GRAY}%s${NC}\n" "$num" "$desc" "$note"
    else
        printf "  ${CYAN}%2s${NC}  %s\n" "$num" "$desc"
    fi
}

# ================================================================ menus internos
installers_menu() {
    clear
    rule "Instaladores" "$GRAY"
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

create_menu() {
    clear
    rule "Criar novo projeto" "$GRAY"
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
    # Se houver apps registrados, mostra lista numerada e permite escolher por numero ou nome
    local apps; apps="$(ob_apps_list 2>/dev/null)"
    if [ -z "$apps" ]; then
        ask "Nome do app" ""
        return
    fi
    local idx=1
    declare -A map
    echo ""
    echo -e "  ${SKY}${BOLD}Apps registrados:${NC}"
    while read -r app; do
        [ -z "$app" ] && continue
        local type port status
        type="$(jq -r --arg n "$app" '.[$n].type // "-"' "$OB_APPS_FILE" 2>/dev/null)"
        port="$(jq -r --arg n "$app" '.[$n].port // 0' "$OB_APPS_FILE" 2>/dev/null)"
        status="$(jq -r --arg n "$app" '.[$n].status // "-"' "$OB_APPS_FILE" 2>/dev/null)"
        printf "    ${CYAN}%2s${NC}  ${WHITE}%-18s${NC} ${GRAY}%s${NC} ${DIM}porta %s${NC} ${GRAY}[%s]${NC}\n" "$idx" "$app" "$type" "$port" "$status"
        map[$idx]="$app"
        idx=$((idx+1))
    done <<< "$apps"
    echo ""
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
    rule "Gerenciar apps" "$GRAY"
    echo ""
    local count
    count="$(ob_apps_count 2>/dev/null || echo 0)"
    if [ "$count" -gt 0 ]; then
        section_title "Apps registrados ($count)" "$SKY"
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

# ================================================================ status strip
status_line() {
    # prod-ready check
    local ready_icon prod_note
    if command_exists nginx && command_exists node && command_exists pm2; then
        prod_note="${GREEN}${TICK} Producao pronta${NC}"
    else
        prod_note="${RED}${CROSS} Rode 'production'${NC}"
    fi

    printf "  ${GRAY}${DOT}${NC} Hosting: %s   ${GRAY}|${NC} ${DIM}apps${NC} %s   ${GRAY}|${NC} Front ${SKY}%s${NC}  %s\n" \
        "$prod_note" \
        "$(ob_apps_count 2>/dev/null || echo 0)" \
        "${OB_FRONT_URL:-https://hadix.site}" \
        "$(ping_badge "$(vps_ping 2>/dev/null || echo '0 offline')")"
}

# ================================================================ main
main_menu() {
    local update_available="$(ob_version_check)"
    while true; do
        clear
        panel_header "$(ob_version)" "$update_available"
        status_line
        menu_br

        menu_header "HOSTING"
        menu_item_alias "1 " "Colocar VPS em producao" "stack completa → hospedar bots/sites"
        menu_item_alias "2 " "Dashboard central" "contas, planos, apps, nodes"
        menu_item_alias "3 " "Monitorar VPS" "--watch"
        menu_item_alias "4 " "Front hadix.site" "prod / dev / ping"

        menu_header "CRIAR"
        menu_item_alias "5 " "Criar novo projeto" "api, bot, site, worker, template"
        menu_item_alias "6 " "Instalar componentes" "docker, nginx, node, ..."

        menu_header "GERENCIAR"
        menu_item_alias "7 " "Ver status dos apps" "tabela tipo/processo/porta"
        menu_item_alias "8 " "Gerenciar apps existentes" "logs, restart, backup, ssl"
        menu_item_alias "9 " "Navegar VPS" "arquivos, deploy, nginx, pm2"

        menu_header "SISTEMA"
        menu_item_alias "10" "Ajuda e comandos rapidos"
        menu_item_alias "11" "Atualizar Hadix.app"
        menu_item_alias "0 " "Sair"

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
            7) bash "${OB_HOME}/commands/status.sh" ;;
            8) manage_menu ;;
            9) bash "${OB_HOME}/commands/vps.sh" ;;
            10) bash "${OB_HOME}/bootstrap/bootstrap.sh" --help; read -r -p "Pressione ENTER para voltar..." ;;
            11) bash "${OB_HOME}/update.sh"; read -r -p "Pressione ENTER para voltar..." ;;
            0) echo -e "${GREEN}${TICK}${NC} Até mais! Hadix.app encerrado."; echo ""; exit 0 ;;
            *) ;;
        esac
    done
}

main_menu
