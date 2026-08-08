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

manage_menu() {
    clear
    rule "Gerenciar apps" "$GRAY"
    echo ""
    if [ "$(ob_apps_list | wc -l)" -gt 0 ]; then
        section_title "Apps registrados" "$SKY"
        while read -r app; do
            echo -e "  ${GRAY}${DOT}${NC} ${WHITE}${app}${NC}"
        done <<< "$(ob_apps_list)"
    else
        echo -e "  ${YELLOW}${WARN}${NC}  Nenhum app registrado ainda."
    fi
    echo ""
    menu_item "1" "Reiniciar app"
    menu_item "2" "Ver logs"
    menu_item "3" "Backup de app (ou todos)"
    menu_item "4" "Remover app"
    menu_item "5" "Emitir/renovar SSL"
    menu_item "0" "Voltar"
    menu_footer
    local choice
    choice="$(ask "Escolha" "")"
    local name
    case "$choice" in
        1) name="$(ask "Nome do app" "")"; bash "${OB_HOME}/commands/restart.sh" "$name" ;;
        2) name="$(ask "Nome do app" "")"; bash "${OB_HOME}/commands/logs.sh" "$name" ;;
        3) name="$(ask "Nome do app (vazio = todos)" "")"; bash "${OB_HOME}/commands/backup.sh" "$name" ;;
        4) name="$(ask "Nome do app" "")"; bash "${OB_HOME}/commands/remove.sh" "$name" ;;
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
        menu_item "1" "Instalar componentes" "docker, nginx, node, ..."
        menu_item "2" "Criar novo projeto"
        menu_item "3" "Gerenciar apps existentes"
        menu_item "4" "Listar apps"
        menu_item "5" "Monitorar VPS" "--watch"
        menu_item "6" "Atualizar Hadix.app"
        menu_item "7" "Ajuda e comandos rapidos"
        menu_item "0" "Sair"
        menu_footer
        local choice
        choice="$(ask "Escolha uma opcao" "")"
        case "$choice" in
            1) installers_menu ;;
            2) create_menu ;;
            3) manage_menu ;;
            4) log_title "Apps"; ob_apps_list; read -r -p "Pressione ENTER para voltar..." ;;
            5) bash "${OB_HOME}/commands/monitor.sh" --watch; read -r -p "Pressione ENTER para voltar..." ;;
            6) bash "${OB_HOME}/update.sh"; read -r -p "Pressione ENTER para voltar..." ;;
            7) bash "${OB_HOME}/bootstrap/bootstrap.sh" --help; read -r -p "Pressione ENTER para voltar..." ;;
            0) echo -e "${GREEN}${TICK}${NC} Até mais! Hadix.app encerrado."; echo ""; exit 0 ;;
            *) ;;
        esac
    done
}

main_menu