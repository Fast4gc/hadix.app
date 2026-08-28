#!/usr/bin/env bash
# commands/status.sh — status geral dos apps hospedados (estilo Discloud/Squarecloud)
# Mostra, em tabela, cada app com: tipo, processo, status, porta, dominio, memoria/uptime.
#
# Uso:
#   bootstrap status              tabela de todos os apps (+ pm2/docker/nginx)
#   bootstrap status <app>        detalhes de um app especifico
#   bootstrap status --json       saida JSON p/ front hadix.site
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
source "${OB_HOME}/bootstrap/ui.sh"
ob_config_init

command_exists() { command -v "$1" >/dev/null 2>&1; }

JSON_OUT=false
FILTER=""
for arg in "$@"; do
    case "$arg" in
        --json|-j) JSON_OUT=true;;
        *) FILTER="$arg";;
    esac
done

# ---------- resolucao do processo ----------
proc_info() { # proc_info <app> -> imprime "tipo status detalhe"
    local name="$1"
    local type port domain path
    type="$(jq -r --arg n "$name" '.[$n].type // "-"' "$OB_APPS_FILE" 2>/dev/null)"
    port="$(jq -r --arg n "$name" '.[$n].port // 0' "$OB_APPS_FILE" 2>/dev/null)"
    domain="$(jq -r --arg n "$name" '.[$n].domain // ""' "$OB_APPS_FILE" 2>/dev/null)"
    path="$(jq -r --arg n "$name" '.[$n].path // ""' "$OB_APPS_FILE" 2>/dev/null)"
    local kind="?" status="parado" detail=""

    # pm2 (root e/ou user hadix)
    if command_exists pm2; then
        local pname pstate pram puptime
        pname="$(pm2 jlist 2>/dev/null | jq -r --arg n "$name" '.[] | select(.name==$n) | .name' 2>/dev/null | head -1)"
        if [ -n "$pname" ]; then
            kind="pm2"
            status="$(pm2 jlist 2>/dev/null | jq -r --arg n "$name" '.[] | select(.name==$n) | .pm2_env.status' 2>/dev/null | head -1)"
            pram="$(pm2 jlist 2>/dev/null | jq -r --arg n "$name" '.[] | select(.name==$n) | (.monit.memory/1048576|floor)' 2>/dev/null | head -1)"
            detail="mem ${pram:-?}MB"
            [ "$status" = "online" ] && status="rodando" || status="parado"
        fi
    fi
    # docker
    if [ "$kind" = "?" ] && command_exists docker; then
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
            kind="docker"
            local ds; ds="$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)"
            if [ "$ds" = "true" ]; then status="rodando"; else status="parado"; fi
        fi
    fi
    # nginx (site estatico tudo via nginx + file)
    if [ "$kind" = "?" ] && [ -f "/etc/nginx/sites-enabled/${name}.conf" ]; then
        kind="nginx"
        if systemctl is-active --quiet nginx 2>/dev/null; then status="rodando"; else status="parado"; fi
    fi
    # arquivo de manifest existente?
    local manifest=""
    [ -n "$path" ] && [ -f "${path}/hadix.toml" ] && manifest="${path}/hadix.toml"

    if [ "$JSON_OUT" = false ]; then
        local sc="$GREEN"
        [ "$status" != "rodando" ] && sc="$RED"
        printf "  ${WHITE}%-18s${NC} ${CYAN}%-8s${NC} ${GRAY}%-6s${NC} ${sc}%-8s${NC} ${GRAY}%s${NC} %s\n" \
            "$name" "$type" "$kind" "$status" "porta ${port} ${domain}" "$detail"
    else
        jq -n --arg name "$name" --arg type "$type" --arg kind "$kind" \
           --arg status "$status" --arg port "$port" --arg domain "$domain" \
           --arg mem "$detail" '{name:$name,type:$type,process:$kind,status:$status,port:$port,domain:$domain,mem:$mem}'
    fi
}

apps="$(ob_apps_list 2>/dev/null)"

json_out() {
    echo "["
    local first=1
    while read -r app; do
        [ -n "$app" ] || continue
        local line
        line="$(proc_info "$app")"
        [ -n "$line" ] || continue
        [ "$first" -eq 0 ] && echo ","
        echo -n "  $line"
        first=0
    done <<< "$apps"
    [ "$first" -eq 1 ] && echo -n ""
    echo ""
    echo "]"
}

if [ "$JSON_OUT" = true ]; then
    json_out
    exit 0
fi

# ---------- saída legivel ----------
show_detail() {
    local fname="$1"
    if jq -e --arg n "$fname" 'has($n)' "$OB_APPS_FILE" >/dev/null 2>&1; then
        echo ""
        rule "Status: ${fname}" "$SKY"
        echo ""
        proc_info "$fname"
        echo ""
        local path
        path="$(jq -r --arg n "$fname" '.[$n].path // empty' "$OB_APPS_FILE" 2>/dev/null)"
        if [ -n "$path" ] && [ -f "${path}/hadix.toml" ]; then
            echo -e "  ${SKY}${BOLD}hadix.toml${NC}"
            cat "${path}/hadix.toml"
            echo ""
        else
            echo -e "  ${DIM}Sem hadix.toml — rode 'bootstrap production' p/ gerar modelo${NC}"
        fi
        echo ""
    else
        echo -e "  ${YELLOW}${WARN}${NC} App '${fname}' nao registrado (use 'bootstrap list')."
        exit 1
    fi
}

show_table() {
    echo ""
    rule "Apps hospedados $(ob_apps_count 2>/dev/null || echo 0)" "$SKY"
    echo ""
    printf "  ${GRAY}%-18s %-8s %-6s %-10s %s${NC}\n" "APP" "TIPO" "PROC" "STATUS" "DETALHE"
    echo -e "  ${GRAY}$(repeat_char 70 "$THIN_T")${NC}"
    local count=0
    while read -r app; do
        [ -n "$app" ] || continue
        proc_info "$app"
        count=$((count+1))
    done <<< "$apps"
    [ "$count" -eq 0 ] && echo -e "  ${DIM}Nenhum app registrado. Use 'bootstrap create-*' ou 'bootstrap production'.${NC}"
    echo ""
    echo -e "  ${DIM}Use 'bootstrap status <app>' p/ ver o hadix.toml e detalhes.${NC}"
    echo ""
}

if [ -n "$FILTER" ]; then
    show_detail "$FILTER"
else
    show_table
fi
