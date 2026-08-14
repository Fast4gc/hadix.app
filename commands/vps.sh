#!/usr/bin/env bash
# commands/vps.sh — navegador seguro da VPS e ferramentas essenciais de hospedagem
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"; source "${OB_HOME}/bootstrap/ui.sh"
ob_config_init

VPS_CWD="${1:-${OB_APPS_DIR}}"
[ -d "$VPS_CWD" ] || VPS_CWD="/"

bytes_to_human() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN { split("B KB MB GB TB", u); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf "%.1f %s", b, u[i] }'
}

safe_path() {
    local base="$1" input="$2"
    if [[ "$input" = /* ]]; then
        realpath -m "$input"
    else
        realpath -m "${base}/${input}"
    fi
}

show_dir() {
    clear
    rule "Navegador da VPS" "$SKY"
    echo ""
    echo -e "  ${GRAY}Diretorio:${NC} ${BOLD}${VPS_CWD}${NC}"
    echo ""
    printf "  ${GRAY}%-4s %-5s %-10s %-17s %s${NC}\n" "#" "Tipo" "Tam" "Alterado" "Nome"
    echo -e "  ${GRAY}$(repeat_char 76 "─")${NC}"
    echo -e "  ${CYAN}..${NC}   ${DIM}dir   -          -                 voltar${NC}"
    local i=1
    while IFS=$'\t' read -r ftype size changed name; do
        [ -z "$name" ] && continue
        [[ "$name" = .* ]] && continue
        local type color human_size
        human_size="$(bytes_to_human "$size")"
        if [ "$ftype" = "d" ]; then type="dir"; color="$SKY"; else type="file"; color="$WHITE"; fi
        printf "  ${CYAN}%-4s${NC} %-5s %-10s %-17s ${color}%s${NC}\n" "$i" "$type" "$human_size" "$changed" "$name"
        i=$((i+1))
    done < <(find "$VPS_CWD" -mindepth 1 -maxdepth 1 -printf '%y\t%s\t%TY-%Tm-%Td %TH:%TM\t%f\n' 2>/dev/null | sort -k4 | head -80)
    echo ""
}

quick_actions() {
    echo -e "  ${BOLD}Acoes${NC}"
    menu_item "1" "Entrar em diretorio"
    menu_item "2" "Ver arquivo" "tail/less seguro"
    menu_item "3" "Criar pasta"
    menu_item "4" "Criar arquivo .env"
    menu_item "5" "Editar arquivo" "nano/vim/editor"
    menu_item "6" "Permissoes do app" "chown www-data/root + chmod"
    menu_item "7" "Git pull no diretorio atual"
    menu_item "8" "Instalar dependencias" "npm/pnpm/bun/pip"
    menu_item "9" "Build do projeto" "npm/pnpm/bun"
    menu_item "10" "Iniciar/registrar PM2" "start script"
    menu_item "11" "Publicar dominio Nginx" "proxy/static"
    menu_item "12" "Terminal aqui" "bash no diretorio"
    menu_item "0" "Voltar"
    echo ""
}

open_file() {
    local file; file="$(safe_path "$VPS_CWD" "$(ask "Arquivo" "")")"
    [ -f "$file" ] || { log_error "Arquivo nao encontrado."; return; }
    if command_exists less; then less -R "$file"; else sed -n '1,220p' "$file"; fi
}

edit_file() {
    local file editor; file="$(safe_path "$VPS_CWD" "$(ask "Arquivo" "")")"
    editor="${EDITOR:-nano}"
    command_exists "$editor" || editor="vi"
    "$editor" "$file"
}

create_env() {
    local file; file="$(safe_path "$VPS_CWD" ".env")"
    [ -f "$file" ] && ! confirm ".env ja existe. Sobrescrever?" && return
    cat > "$file" <<ENV
NODE_ENV=production
PORT=$(next_free_port 3000)
APP_NAME=$(basename "$VPS_CWD")
ENV
    log_ok ".env criado em ${file}"
}

install_deps() {
    if [ -f "$VPS_CWD/pnpm-lock.yaml" ] && command_exists pnpm; then (cd "$VPS_CWD" && pnpm install)
    elif [ -f "$VPS_CWD/bun.lockb" ] && command_exists bun; then (cd "$VPS_CWD" && bun install)
    elif [ -f "$VPS_CWD/package.json" ]; then (cd "$VPS_CWD" && npm install)
    elif [ -f "$VPS_CWD/requirements.txt" ]; then (cd "$VPS_CWD" && python3 -m venv venv && ./venv/bin/pip install -r requirements.txt)
    else log_error "Nenhum manifesto conhecido encontrado."; fi
}

build_project() {
    if [ -f "$VPS_CWD/package.json" ]; then
        if command_exists pnpm && [ -f "$VPS_CWD/pnpm-lock.yaml" ]; then (cd "$VPS_CWD" && pnpm build); else (cd "$VPS_CWD" && npm run build); fi
    else log_error "package.json nao encontrado."; fi
}

pm2_start_here() {
    command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
    local name cmd port domain
    name="$(ask "Nome do app" "$(basename "$VPS_CWD")")"
    cmd="$(ask "Comando start" "npm start")"
    port="$(ask "Porta" "$(next_free_port 3000)")"
    domain="$(ask "Dominio (opcional)" "")"
    (cd "$VPS_CWD" && PORT="$port" pm2 start "$cmd" --name "$name") && pm2 save
    ob_apps_add "$name" "custom" "$port" "$domain" "$VPS_CWD"
}

publish_nginx_here() {
    local mode domain port root name template
    name="$(ask "Nome do app" "$(basename "$VPS_CWD")")"
    mode="$(ask "Modo (proxy/static)" "proxy")"
    domain="$(ask "Dominio" "")"
    [ -z "$domain" ] && { log_error "Dominio obrigatorio."; return; }
    command_exists nginx || bash "${OB_HOME}/installers/nginx.sh"
    if [ "$mode" = "static" ]; then
        root="$(ask "Pasta publica" "${VPS_CWD}/dist")"
        template="${OB_HOME}/templates/nginx/static.conf"
        sed -e "s#__DOMAIN__#${domain}#g" -e "s#__ROOT_PATH__#${root}#g" -e "s#__APP_NAME__#${name}#g" "$template" > "/etc/nginx/sites-available/${name}.conf"
    else
        port="$(ask "Porta local" "3000")"
        template="${OB_HOME}/templates/nginx/api.conf"
        sed -e "s#__DOMAIN__#${domain}#g" -e "s#__PORT__#${port}#g" -e "s#__APP_NAME__#${name}#g" "$template" > "/etc/nginx/sites-available/${name}.conf"
    fi
    ln -sf "/etc/nginx/sites-available/${name}.conf" "/etc/nginx/sites-enabled/${name}.conf"
    nginx -t && systemctl reload nginx
}

while true; do
    show_dir
    quick_actions
    choice="$(ask "Acao" "")"
    case "$choice" in
        1) target="$(safe_path "$VPS_CWD" "$(ask "Diretorio" "..")")"; [ -d "$target" ] && VPS_CWD="$target" || log_error "Diretorio invalido" ;;
        2) open_file ; read -r -p "Pressione ENTER..." ;;
        3) mkdir -p "$(safe_path "$VPS_CWD" "$(ask "Nome da pasta" "nova-pasta")")" ;;
        4) create_env ; read -r -p "Pressione ENTER..." ;;
        5) edit_file ;;
        6) chown -R "${OB_APP_USER:-www-data}:${OB_APP_GROUP:-www-data}" "$VPS_CWD" 2>/dev/null || true; chmod -R u+rwX,go+rX "$VPS_CWD" ;;
        7) (cd "$VPS_CWD" && git pull) ; read -r -p "Pressione ENTER..." ;;
        8) install_deps ; read -r -p "Pressione ENTER..." ;;
        9) build_project ; read -r -p "Pressione ENTER..." ;;
        10) pm2_start_here ; read -r -p "Pressione ENTER..." ;;
        11) publish_nginx_here ; read -r -p "Pressione ENTER..." ;;
        12) (cd "$VPS_CWD" && bash) ;;
        0) exit 0 ;;
    esac
done
