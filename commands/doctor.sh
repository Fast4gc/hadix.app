#!/usr/bin/env bash
# commands/doctor.sh — diagnostico completo da VPS Hadix.app
#
# Checa: ferramentas, nginx, pm2, config JSON, apps registrados sem processo,
# permissoes, versao e saude geral. Uso:
#   bootstrap doctor              roda todas as checagens
#   bootstrap doctor --json       saida JSON (p/ front/CI)
#   bootstrap doctor --quiet      so mostra problemas (nao OKs)
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
source "${OB_HOME}/bootstrap/version.sh"
source "${OB_HOME}/bootstrap/ui.sh"
ob_config_init

JSON_OUT=false
QUIET=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUT=true ;;
        --quiet) QUIET=true ;;
        --help|-h) echo "Uso: bootstrap doctor [--json] [--quiet]"; exit 0 ;;
    esac
done

command_exists() { command -v "$1" >/dev/null 2>&1; }

# acumulador de problemas (para exit code e resumo)
PROBLEMS=0
CHECK_FAIL=false
check_done() { # ok | fail, "label", "detalhe"
    local ok="$1" label="$2" detail="$3"
    if [ "$ok" = "ok" ]; then
        if [ "$JSON_OUT" = false ] && [ "$QUIET" = false ]; then
            echo -e "  ${GREEN}${TICK}${NC} ${label}  ${DIM}${detail}${NC}"
        fi
    else
        PROBLEMS=$((PROBLEMS + 1))
        if [ "$JSON_OUT" = true ]; then
            printf '{"ok":false,"check":"%s","detail":"%s"}\n' "$label" "$detail"
        elif [ "$QUIET" = true ]; then
            echo "[FAIL] ${label}: ${detail}"
        else
            echo -e "  ${RED}${CROSS}${NC} ${label}  ${RED}${detail}${NC}"
        fi
    fi
}

# ---------------------------------------------------------------- banner
if [ "$JSON_OUT" = false ]; then
    echo -e "${MAGENTA}${BOLD}"
    cat << 'ASCII'
   _   _           _ _            _       _
  | | | | __ _  __| (_)_  __   __| | __ _| |_ __ _
  | |_| |/ _` |/ _` | \ \/ /  / _` |/ _` | __/ _` |
  |  _  | (_| | (_| | |>  <  | (_| | (_| | || (_| |
  |_| |_|\__,_|\__,_|_/_/\_\  \__,_|\__,_|\__\__,_|
ASCII
    echo -e "${NC}"
    echo -e "  ${BOLD}${WHITE}Hadix.app${NC} ${GRAY}${DOT}${NC} ${SKY}Diagnostico${NC} ${GRAY}${DOT}${NC} ${DIM}v$(ob_version)${NC}"
    echo ""
fi

# ---------------------------------------------------------------- ferramentas
if [ "$JSON_OUT" = false ]; then echo -e "  ${BOLD}Ferramentas${NC}"; fi
for t in nginx node npm pm2 jq curl git python3 docker certbot; do
    if command_exists "$t"; then
        check_done ok "$t" "$(command -v "$t")"
    else
        check_done fail "$t" "nao instalado"
    fi
done

# ---------------------------------------------------------------- nginx
if [ "$JSON_OUT" = false ]; then echo ""; echo -e "  ${BOLD}Nginx${NC}"; fi
if command_exists nginx; then
    if nginx -t >/tmp/hadix_nginx_t.out 2>&1; then
        check_done ok "nginx config" "sintaxe valida"
    else
        check_done fail "nginx config" "$(grep -o '\[emerg\][^;]*' /tmp/hadix_nginx_t.out 2>/dev/null | head -1 || head -1 /tmp/hadix_nginx_t.out)"
    fi
    # procura placeholders nao substituidos nos confs
    _ph="$(grep -rl '__[A-Z_]*__' /etc/nginx/conf.d /etc/nginx/sites-enabled 2>/dev/null | head -3)"
    if [ -n "$_ph" ]; then
        check_done fail "nginx placeholders" "encontrados em: $(echo "$_ph" | tr '\n' ' ')"
    else
        check_done ok "nginx placeholders" "nenhum __VAR__ sem substituir"
    fi
else
    check_done fail "nginx" "nao instalado — rode bootstrap production"
fi

# ---------------------------------------------------------------- pm2 / apps
if [ "$JSON_OUT" = false ]; then echo ""; echo -e "  ${BOLD}PM2 e apps${NC}"; fi
if command_exists pm2; then
    pm2 jlist >/tmp/hadix_pm2_jlist.json 2>/dev/null
    _pm2_names="$(jq -r '.[].name' /tmp/hadix_pm2_jlist.json 2>/dev/null | sort)"
    if [ -z "$_pm2_names" ]; then
        check_done ok "pm2" "rodando, sem processos"
    else
        check_done ok "pm2" "$(echo "$_pm2_names" | wc -l) processos"
    fi
else
    check_done fail "pm2" "nao instalado — rode bootstrap production"
fi

# apps registrados mas sem processo
if [ -f "$OB_APPS_FILE" ]; then
    _apps="$(ob_apps_list 2>/dev/null)"
    if [ -n "$_apps" ]; then
        while read -r app; do
            [ -z "$app" ] && continue
            if [ -n "$_pm2_names" ] && echo "$_pm2_names" | grep -qx "$app"; then
                check_done ok "app ${app}" "processo pm2 presente"
            elif echo "$_apps" | grep -qx "$app"; then
                # registrado em apps.json mas sem processo pm2
                check_done fail "app ${app}" "registrado sem processo pm2 (rode: bootstrap start ${app})"
            fi
        done <<< "$_apps"
    else
        check_done ok "apps" "nenhum registrado"
    fi
else
    check_done fail "apps.json" "arquivo ausente em ${OB_APPS_FILE}"
fi

# ---------------------------------------------------------------- config
if [ "$JSON_OUT" = false ]; then echo ""; echo -e "  ${BOLD}Config${NC}"; fi
for f in apps users plans nodes domains; do
    if [ -f "${OB_CONFIG_DIR}/${f}.json" ]; then
        if jq -e . "${OB_CONFIG_DIR}/${f}.json" >/dev/null 2>&1; then
            check_done ok "${f}.json" "JSON valido"
        else
            check_done fail "${f}.json" "JSON invalido (corrompido)"
        fi
    else
        check_done fail "${f}.json" "arquivo ausente"
    fi
done

# permissoes do apps dir
if [ -d "${OB_APPS_DIR:-/var/www}" ]; then
    check_done ok "OB_APPS_DIR" "${OB_APPS_DIR:-/var/www}"
else
    check_done fail "OB_APPS_DIR" "${OB_APPS_DIR:-/var/www} nao existe"
fi

# ---------------------------------------------------------------- versao
if [ "$JSON_OUT" = false ]; then echo ""; echo -e "  ${BOLD}Versao${NC}"; fi
_cur="$(ob_version)"
_latest="$(ob_version_latest 2>/dev/null || true)"
if [ -n "$_latest" ] && [ "$(ob_version_compare "$_latest" "$_cur")" -gt 0 ]; then
    check_done fail "versao" "instalada ${_cur}, disponivel ${_latest} (rode: bootstrap update)"
else
    check_done ok "versao" "${_cur}"
fi

# ---------------------------------------------------------------- resumo
if [ "$JSON_OUT" = false ]; then
    echo ""
    if [ "$PROBLEMS" -eq 0 ]; then
        echo -e "  ${GREEN}${TICK}${NC} ${BOLD}Diagnostico OK — sem problemas encontrados.${NC}"
    else
        echo -e "  ${RED}${CROSS}${NC} ${BOLD}${PROBLEMS} problema(s) encontrado(s).${NC}"
        echo -e "  ${DIM}Dica: resolva os itens acima e rode 'bootstrap doctor' de novo.${NC}"
    fi
    echo ""
fi

[ "$PROBLEMS" -eq 0 ]
