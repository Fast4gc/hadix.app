#!/usr/bin/env bash
# menu.sh — painel interativo do Hadix.app (visual profissional)
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
        # preview rapido ja feito por pick_app_name depois
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
        echo -e "  ${DIM}Dica: crie via 'Criar novo projeto' ou registre manualmente em /var/www${NC}"
    fi
    echo ""
    menu_item "1" "Reiniciar app" "pm2/docker/systemd"
    menu_item "2" "Ver logs" "100 linhas, segue se TTY"
    menu_item "3" "Backup de app (ou todos)"
    menu_item "4" "Remover app"
    menu_item "5" "Emitir/renovar SSL"
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    local name
    case "$choice" in
        1) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/restart.sh" "$name" ;;
        2) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/logs.sh" "$name" ;;
        3) name="$(pick_app_name)"; bash "${OB_HOME}/commands/backup.sh" "$name" ;;
        4) name="$(pick_app_name)"; [ -n "$name" ] && bash "${OB_HOME}/commands/remove.sh" "$name" ;;
        5) name="$(ask "Dominio" "")"; bash "${OB_HOME}/commands/ssl.sh" "$name" ;;
       0|*) return ;;
    esac
    read -r -p "Pressione ENTER para continuar..."
}

main_menu() {
    local update_available="$(ob_version_check)"
    while true; do
        clear
        panel_header "$(ob_version)" "$update_available"
        separator
        sysinfo
        separator
        echo ""
        menu_item "1" "Dashboard central" "contas, planos, bots, nodes, ping"
        menu_item "2" "Instalar componentes" "docker, nginx, node, ..."
        menu_item "3" "Criar novo projeto"
        menu_item "4" "Gerenciar apps existentes"
        menu_item "5" "Navegar VPS" "arquivos, deploy, nginx, pm2"
        menu_item "6" "Front hadix.site" "exportar prod / dev / ping"
        menu_item "7" "Monitorar VPS" "--watch"
        menu_item "8" "Atualizar Hadix.app"
        menu_item "9" "Ajuda e comandos rapidos"
        menu_item "0" "Sair"
        menu_footer
        local choice
        choice="$(ask "Escolha uma opcao" "")"
        case "$choice" in
            1) bash "${OB_HOME}/commands/dashboard.sh" ;;
            2) installers_menu ;;
            3) create_menu ;;
            4) manage_menu ;;
            5) bash "${OB_HOME}/commands/vps.sh" ;;
            6) bash "${OB_HOME}/commands/front.sh" ;;
            7) bash "${OB_HOME}/commands/monitor.sh" --watch; read -r -p "Pressione ENTER para voltar..." ;;
            8) bash "${OB_HOME}/update.sh"; read -r -p "Pressione ENTER para voltar..." ;;
            9) bash "${OB_HOME}/bootstrap/bootstrap.sh" --help; read -r -p "Pressione ENTER para voltar..." ;;
            0) echo -e "${GREEN}${TICK}${NC} Até mais! Hadix.app encerrado."; echo ""; exit 0 ;;
            *) ;;
        esac
    done
}

main_menu