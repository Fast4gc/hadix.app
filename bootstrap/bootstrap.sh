#!/usr/bin/env bash
# bootstrap.sh — ponto de entrada. Carrega o ambiente e despacha comandos.
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"

# shellcheck source=colors.sh
source "${OB_HOME}/bootstrap/colors.sh"
# shellcheck source=logger.sh
source "${OB_HOME}/bootstrap/logger.sh"
# shellcheck source=utils.sh
source "${OB_HOME}/bootstrap/utils.sh"
# shellcheck source=config.sh
source "${OB_HOME}/bootstrap/config.sh"

ob_config_init

show_usage() {
    cat << USAGE
${BOLD}Hadix.app${NC} — painel e gerenciador de VPS (v${OB_VERSION})

Uso:
  bootstrap                          Abre o painel Hadix.app (padrao)
  bootstrap install <componente>     Instala um componente (docker, nginx, node, ...)
  bootstrap create <tipo> <nome>     Cria um projeto a partir de um template
  bootstrap create-api <nome>        Cria uma API (Node/Express) com nginx + pm2
  bootstrap create-bot <nome>        Cria um bot (Discord/Telegram) com pm2
  bootstrap create-site <nome>       Cria um site estatico com nginx
  bootstrap create-worker <nome>     Cria um worker em background com pm2
  bootstrap backup [nome]            Faz backup de um app (ou de tudo)
  bootstrap restore <arquivo>        Restaura a partir de um backup
  bootstrap logs <nome>              Mostra logs de um app (pm2/docker)
  bootstrap restart <nome>           Reinicia um app
  bootstrap ssl <dominio>            Emite/renova certificado SSL
  bootstrap remove <nome>            Remove um app
  bootstrap list                     Lista os apps gerenciados
  bootstrap monitor [--watch]         Mostra monitoramento da VPS
  bootstrap update                   Atualiza o Hadix.app sem reinstalar
  bootstrap uninstall                Remove o oracle-bootstrap

Templates disponiveis para 'create':
  nextjs, vite, discord, express, nest, fastify, hono, python, go

Exemplos:
  bootstrap install docker
  bootstrap create nextjs meu-site
  bootstrap create-api minha-api
USAGE
}

dispatch() {
    local cmd="${1:-}"; shift || true

    case "$cmd" in
        ""|menu)
            bash "${OB_HOME}/bootstrap/menu.sh"
            ;;
        install)
            local target="${1:-}"
            if [ -z "$target" ]; then
                log_error "Uso: bootstrap install <componente>"
                exit 1
            fi
            local installer="${OB_HOME}/installers/${target}.sh"
            if [ -f "$installer" ]; then
                require_root
                bash "$installer"
            else
                log_error "Instalador '${target}' nao encontrado."
                echo "Disponiveis: $(ls "${OB_HOME}/installers" | sed 's/\.sh$//' | tr '\n' ' ')"
                exit 1
            fi
            ;;
        create)
            require_root
            bash "${OB_HOME}/commands/create.sh" "$@"
            ;;
        create-api)     require_root; bash "${OB_HOME}/commands/create-api.sh" "$@" ;;
        create-bot)     require_root; bash "${OB_HOME}/commands/create-bot.sh" "$@" ;;
        create-site)    require_root; bash "${OB_HOME}/commands/create-site.sh" "$@" ;;
        create-worker)  require_root; bash "${OB_HOME}/commands/create-worker.sh" "$@" ;;
        backup)         bash "${OB_HOME}/commands/backup.sh" "$@" ;;
        restore)        require_root; bash "${OB_HOME}/commands/restore.sh" "$@" ;;
        logs)           bash "${OB_HOME}/commands/logs.sh" "$@" ;;
        restart)        require_root; bash "${OB_HOME}/commands/restart.sh" "$@" ;;
        monitor)        bash "${OB_HOME}/commands/monitor.sh" "$@" ;;
        ssl)            require_root; bash "${OB_HOME}/commands/ssl.sh" "$@" ;;
        remove)         require_root; bash "${OB_HOME}/commands/remove.sh" "$@" ;;
        list)
            ob_config_init
            echo -e "${BOLD}Apps gerenciados:${NC}"
            ob_apps_list
            ;;
        update)
            bash "${OB_HOME}/update.sh"
            ;;
        uninstall)
            bash "${OB_HOME}/uninstall.sh"
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            log_error "Comando desconhecido: $cmd"
            show_usage
            exit 1
            ;;
    esac
}

dispatch "$@"
