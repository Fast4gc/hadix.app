#!/usr/bin/env bash
# menu.sh — painel interativo do Hadix.app
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

trap 'echo; echo -e "${YELLOW}Voltando ao painel Hadix.app...${NC}"; sleep 1' INT

installers_menu() {
    log_title "Hadix.app • Instaladores"
    local list=(docker nginx node pnpm bun postgres redis fail2ban ufw cloudflare ssl pm2 github certbot monitoring)
    local i=1
    for item in "${list[@]}"; do
        echo -e "  ${CYAN}${i})${NC} $item"
        i=$((i+1))
    done
    echo -e "  ${CYAN}0)${NC} Voltar"
    local choice
    choice="$(ask "Escolha um componente" "")"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#list[@]}" ]; then
        require_root
        bash "${OB_HOME}/installers/${list[$((choice-1))]}.sh"
        read -r -p "Pressione ENTER para continuar..."
    fi
}

create_menu() {
    log_title "Hadix.app • Criar novo projeto"
    echo -e "  ${CYAN}1)${NC} API (Node/Express) — nginx + pm2"
    echo -e "  ${CYAN}2)${NC} Bot (Discord/Telegram) — pm2"
    echo -e "  ${CYAN}3)${NC} Site estatico — nginx"
    echo -e "  ${CYAN}4)${NC} Worker em background — pm2"
    echo -e "  ${CYAN}5)${NC} A partir de template (nextjs, vite, express, nest, fastify, hono, python, go, discord)"
    echo -e "  ${CYAN}0)${NC} Voltar"
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
    log_title "Hadix.app • Gerenciar apps"
    ob_apps_list
    echo ""
    echo -e "  ${CYAN}1)${NC} Reiniciar app"
    echo -e "  ${CYAN}2)${NC} Ver logs"
    echo -e "  ${CYAN}3)${NC} Backup"
    echo -e "  ${CYAN}4)${NC} Remover app"
    echo -e "  ${CYAN}5)${NC} Emitir/renovar SSL"
    echo -e "  ${CYAN}0)${NC} Voltar"
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
    while true; do
        clear
        echo -e "${MAGENTA}${BOLD}"
        cat << 'BANNER'
  _   _           _ _
 | | | | __ _  __| (_)_  __   __ _ _ __  _ __
 | |_| |/ _` |/ _` | \ \/ /  / _` | '_ \| '_ \
 |  _  | (_| | (_| | |>  <  | (_| | |_) | |_) |
 |_| |_|\__,_|\__,_|_/_/\_\  \__,_| .__/| .__/
                                      |_|   |_|
BANNER
        echo -e "${NC}"
        echo -e "  ${DIM}Painel completo de VPS, deploy e apps — v${OB_VERSION}${NC}\n"
        echo -e "  ${CYAN}1)${NC} Instalar componentes (docker, nginx, node...)"
        echo -e "  ${CYAN}2)${NC} Criar novo projeto"
        echo -e "  ${CYAN}3)${NC} Gerenciar apps existentes"
        echo -e "  ${CYAN}4)${NC} Listar apps"
        echo -e "  ${CYAN}5)${NC} Monitorar VPS"
        echo -e "  ${CYAN}6)${NC} Atualizar Hadix.app sem reinstalar"
        echo -e "  ${CYAN}7)${NC} Ajuda e comandos rapidos"
        echo -e "  ${CYAN}0)${NC} Sair"
        echo ""
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
            0) echo "Até mais! Hadix.app encerrado."; exit 0 ;;
            *) ;;
        esac
    done
}

main_menu
