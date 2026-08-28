#!/usr/bin/env bash
# commands/logs.sh — mostra logs de um app (pm2, docker, systemd, arquivos)
# Robustez p/ frontend hadix.site: suporta chamadas nao-interativas, multi-tentativas, fallback.
#
# Uso:
#   bootstrap logs <nome> [--lines N] [--no-follow] [--json]
#   bootstrap logs music               # interativo: segue logs se TTY
#   bootstrap logs music --lines 200 --no-follow   # p/ frontend: saida finita
#   bootstrap logs 61701a92-0251...    # tambem tenta resolver via apps.json / pasta
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/logger.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/utils.sh" 2>/dev/null || true
source "${OB_HOME}/bootstrap/config.sh" 2>/dev/null || true
command -v ob_config_init >/dev/null 2>&1 && ob_config_init || true

# ---------- parse args ----------
ORIG_ARGS=("$@")
NAME_RAW=""
LINES=100
FOLLOW="auto"   # auto = segue se TTY, senao nostream
JSON_OUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --lines) LINES="${2:-100}"; shift 2;;
        --lines=*) LINES="${1#--lines=}"; shift;;
        --no-follow|--nostream) FOLLOW="no"; shift;;
        --follow|-f) FOLLOW="yes"; shift;;
        --json) JSON_OUT=true; shift;;
        --help|-h) echo "Uso: bootstrap logs <nome> [--lines N] [--no-follow] [--json]"; exit 0;;
        --) shift; break;;
        -* ) shift;; # ignora flag desconhecida
        *) if [ -z "$NAME_RAW" ]; then NAME_RAW="$1"; else NAME_RAW="$NAME_RAW $1"; fi; shift;;
    esac
done

# modo nao-interativo: nunca perguntar se nao ha TTY ou se chamado pelo frontend (ex: via SSH nao-TTY)
if [ -z "$NAME_RAW" ]; then
    if [ ! -t 0 ] || [ "${HADIX_NONINTERACTIVE:-}" = "1" ]; then
        echo "Uso: bootstrap logs <nome> [--lines N] [--no-follow]" >&2
        echo "Apps disponiveis: $( (command -v ob_apps_list >/dev/null 2>&1 && ob_apps_list || ls /var/www 2>/dev/null) | tr '\n' ' ')" >&2
        exit 2
    fi
    # interativo: pergunta
    if command -v ask >/dev/null 2>&1; then
        NAME_RAW="$(ask "Nome do app" "")"
    else
        read -r -p "Nome do app: " NAME_RAW
    fi
fi

# trim
NAME_RAW="$(echo "$NAME_RAW" | xargs 2>/dev/null || echo "$NAME_RAW")"
[ -z "$NAME_RAW" ] && { (command -v log_error >/dev/null 2>&1 && log_error "Nome obrigatorio." || echo "Nome obrigatorio." >&2); exit 1; }

# decide follow
if [ "$FOLLOW" = "auto" ]; then
    if [ -t 1 ] && [ -t 0 ]; then FOLLOW="yes"; else FOLLOW="no"; fi
fi

# ---------- helpers ----------
command_exists() { command -v "$1" >/dev/null 2>&1; }

# candidatos de nomes a tentar (exato, slug, substring, uuid, pasta)
build_candidates() {
    local raw="$1"
    local slug
    slug="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
    echo "$raw"
    [ "$slug" != "$raw" ] && echo "$slug"
    # se for uuid curto, tambem tenta prefixo de 8 chars
    if [[ "$raw" =~ ^[0-9a-f-]{8,} ]]; then
        echo "${raw:0:8}"
    fi
}

resolve_app_path() {
    local cand="$1"
    # 1) via apps.json (exato e parcial) — tenta jq, fallback grep se jq ausente
    if command -v ob_apps_get >/dev/null 2>&1; then
        local info path
        info="$(ob_apps_get "$cand" 2>/dev/null)"
        if [ "$info" != "null" ] && [ -n "$info" ] && [ "$info" != "" ]; then
            if command -v jq >/dev/null 2>&1; then
                path="$(echo "$info" | jq -r '.path // empty' 2>/dev/null)"
            else
                path="$(echo "$info" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*\"path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/')"
            fi
            [ -n "$path" ] && [ "$path" != "null" ] && echo "$path" && return 0
        fi
        # busca parcial por key contendo cand (ex: music vs music-xxx)
        if command -v jq >/dev/null 2>&1; then
            local hit
            hit="$(jq -r --arg q "$cand" 'to_entries[] | select(.key | contains($q)) | .value.path // empty' "$OB_APPS_FILE" 2>/dev/null | head -1)"
            [ -n "$hit" ] && echo "$hit" && return 0
        else
            # fallback grep: procura chave contendo cand
            local hit2
            hit2="$(grep -o "\"[^\"]*${cand}[^\"]*\"[[:space:]]*:[[:space:]]*{[^}]*\"path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$OB_APPS_FILE" 2>/dev/null | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*\"path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/')"
            [ -n "$hit2" ] && echo "$hit2" && return 0
        fi
    fi
    # 2) pasta em OB_APPS_DIR (default /var/www)
    local apps_dir="${OB_APPS_DIR:-/var/www}"
    if [ -d "${apps_dir}/${cand}" ]; then echo "${apps_dir}/${cand}"; return 0; fi
    local glob_hit
    glob_hit="$(ls -d "${apps_dir}/"*${cand}* 2>/dev/null | head -1)"
    [ -n "$glob_hit" ] && echo "$glob_hit" && return 0
    return 1
}

# tenta pm2 com multiplos HOME (root, www-data, hadix, etc)
pm2_candidates_for() {
    local cand="$1"
    local homes=("/root" "/home/www-data" "/home/hadix" "$HOME")
    # PM2_HOME explicito do sistema
    [ -n "${PM2_HOME:-}" ] && homes+=("$PM2_HOME")
    local out=""
    # jlist busca precisa (pm2 atual)
    if command_exists pm2; then
        if pm2 jlist 2>/dev/null | jq -e --arg n "$cand" '.[] | select(.name == $n)' >/dev/null 2>&1; then
            echo "pm2:$cand"; return 0
        fi
        # busca parcial pm2
        local partial
        partial="$(pm2 jlist 2>/dev/null | jq -r --arg q "$cand" '.[] | select(.name | contains($q)) | .name' 2>/dev/null | head -1)"
        [ -n "$partial" ] && echo "pm2:$partial" && return 0
        # fallback describe
        if pm2 describe "$cand" >/dev/null 2>&1; then echo "pm2:$cand"; return 0; fi
    fi
    # tenta via sudo -u www-data etc se pm2 socket de outro user
    for u in www-data hadix ubuntu; do
        if id "$u" >/dev/null 2>&1 && sudo -u "$u" pm2 jlist 2>/dev/null | jq -e --arg n "$cand" '.[] | select(.name == $n)' >/dev/null 2>&1; then
            echo "pm2user:$u:$cand"; return 0
        fi
    done
    # procura arquivos de log pm2 em homes
    for h in "${homes[@]}"; do
        if ls "$h/.pm2/logs/${cand}"*.log >/dev/null 2>&1; then echo "pm2file:$h/.pm2/logs/${cand}"; return 0; fi
        if ls "$h/.pm2/logs/"*"${cand}"* >/dev/null 2>&1; then
            local f
            f="$(ls "$h/.pm2/logs/"*"${cand}"* 2>/dev/null | head -1)"
            echo "pm2file:$f"; return 0
        fi
    done
    return 1
}

docker_candidates_for() {
    local cand="$1"
    if ! command_exists docker; then return 1; fi
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$cand"; then echo "docker:$cand"; return 0; fi
    local partial
    partial="$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -m1 "$cand" || true)"
    [ -n "$partial" ] && echo "docker:$partial" && return 0
    return 1
}

# ---------- main resolution ----------
CANDIDATES=()
while IFS= read -r c; do [ -n "$c" ] && CANDIDATES+=("$c"); done < <(build_candidates "$NAME_RAW")

# se nome contem espaco ou varios tokens (frontend mandou "music 61701a92..."), tenta cada um
if [[ "$NAME_RAW" == *" "* ]] || [[ "$NAME_RAW" == *","* ]]; then
    for tok in $(echo "$NAME_RAW" | tr ', ' ' '); do
        while IFS= read -r c; do [[ " ${CANDIDATES[*]} " != *" $c "* ]] && CANDIDATES+=("$c"); done < <(build_candidates "$tok")
    done
fi

FOUND_KIND=""
FOUND_VAL=""
FOUND_CAND=""
for cand in "${CANDIDATES[@]}"; do
    if res="$(pm2_candidates_for "$cand")"; then FOUND_KIND="${res%%:*}"; FOUND_VAL="${res#*:}"; FOUND_CAND="$cand"; break; fi
    if res="$(docker_candidates_for "$cand")"; then FOUND_KIND="${res%%:*}"; FOUND_VAL="${res#*:}"; FOUND_CAND="$cand"; break; fi
    if systemctl list-units --full --all 2>/dev/null | grep -q "${cand}.service"; then FOUND_KIND="systemd"; FOUND_VAL="$cand"; FOUND_CAND="$cand"; break; fi
    if [ -f "/var/log/nginx/${cand}.error.log" ] || [ -f "/var/log/nginx/${cand}.access.log" ]; then FOUND_KIND="nginx"; FOUND_VAL="$cand"; FOUND_CAND="$cand"; break; fi
    if path="$(resolve_app_path "$cand")"; then FOUND_KIND="path"; FOUND_VAL="$path"; FOUND_CAND="$cand"; break; fi
done

# se nada encontrado, tenta ainda app path original (sem loop)
if [ -z "$FOUND_KIND" ]; then
    if path="$(resolve_app_path "$NAME_RAW")"; then FOUND_KIND="path"; FOUND_VAL="$path"; FOUND_CAND="$NAME_RAW"; fi
fi

# ---------- output ----------
emit_found() {
    local kind="$1" val="$2" cand="$3"
    # cabecalho informativo (stderr p/ nao poluir pipe do frontend quando --json=false ainda legivel)
    if [ "$JSON_OUT" = false ]; then
        echo -e "${DIM:-}— logs de '${cand}' via ${kind}: ${val} (lines=${LINES}, follow=${FOLLOW}) —${NC:-}" >&2
    fi
}

handle_pm2() {
    local name="$1"
    emit_found "pm2" "$name" "$FOUND_CAND"
    if [ "$FOLLOW" = "yes" ]; then
        pm2 logs "$name" --lines "$LINES"
    else
        # nostream para frontend/CI
        pm2 logs "$name" --lines "$LINES" --nostream 2>&1 | tail -n "$LINES"
        # fallback: se pm2 logs nostream nao retornar nada (processo parado), le arquivo
        local got
        got="$(pm2 logs "$name" --lines "$LINES" --nostream 2>&1 | wc -l)"
        if [ "$got" -lt 2 ]; then
            for h in /root /home/* "$HOME"; do
                for f in "$h/.pm2/logs/${name}"*.log "$h/.pm2/logs/${name}"-out.log "$h/.pm2/logs/${name}"-error.log; do
                    [ -f "$f" ] && { echo "--- $f ---" >&2; tail -n "$LINES" "$f"; return 0; }
                done
            done
        fi
    fi
}

handle_pm2user() {
    local user="$1" name="$2"
    emit_found "pm2($user)" "$name" "$FOUND_CAND"
    if [ "$FOLLOW" = "yes" ]; then
        sudo -u "$user" pm2 logs "$name" --lines "$LINES"
    else
        sudo -u "$user" pm2 logs "$name" --lines "$LINES" --nostream 2>&1 | tail -n "$LINES"
    fi
}

handle_pm2file() {
    local pattern="$1"
    # pattern pode ser dir prefix
    local files
    files="$(ls -t $pattern*.log 2>/dev/null | head -5)"
    if [ -z "$files" ] && [ -f "$pattern" ]; then files="$pattern"; fi
    emit_found "pm2-file" "$pattern" "$FOUND_CAND"
    for f in $files; do
        [ -f "$f" ] || continue
        echo "=== $f ===" >&2
        if [ "$FOLLOW" = "yes" ]; then tail -n "$LINES" -f "$f"; else tail -n "$LINES" "$f"; fi
    done
}

handle_docker() {
    local name="$1"
    emit_found "docker" "$name" "$FOUND_CAND"
    if [ "$FOLLOW" = "yes" ]; then docker logs -f --tail "$LINES" "$name"; else docker logs --tail "$LINES" "$name" 2>&1; fi
}

handle_systemd() {
    local name="$1"
    emit_found "systemd" "$name" "$FOUND_CAND"
    if [ "$FOLLOW" = "yes" ]; then journalctl -u "$name" -n "$LINES" -f --no-pager; else journalctl -u "$name" -n "$LINES" --no-pager 2>&1 | tail -n "$LINES"; fi
}

handle_nginx() {
    local name="$1"
    emit_found "nginx" "$name" "$FOUND_CAND"
    local files=()
    [ -f "/var/log/nginx/${name}.access.log" ] && files+=("/var/log/nginx/${name}.access.log")
    [ -f "/var/log/nginx/${name}.error.log" ] && files+=("/var/log/nginx/${name}.error.log")
    if [ "$FOLLOW" = "yes" ]; then tail -n "$LINES" -f "${files[@]}"; else tail -n "$LINES" "${files[@]}" 2>&1; fi
}

handle_path() {
    local p="$1"
    emit_found "path" "$p" "$FOUND_CAND"
    # procura logs dentro da pasta do app
    local logfiles
    logfiles="$(find "$p" -maxdepth 3 -type f \( -name "*.log" -o -name "npm-debug.log*" -o -name "pm2.log" \) 2>/dev/null | head -5)"
    if [ -n "$logfiles" ]; then
        for f in $logfiles; do
            echo "=== $f ===" >&2
            tail -n "$LINES" "$f" 2>&1
        done
        return 0
    fi
    # tenta journalctl com nome da pasta
    local base
    base="$(basename "$p")"
    if systemctl list-units --full --all 2>/dev/null | grep -q "${base}.service"; then
        journalctl -u "$base" -n "$LINES" --no-pager 2>&1 | tail -n "$LINES"
        return 0
    fi
    # tenta pm2 file dentro de .pm2 do app owner
    for h in /root /home/*; do
        for f in "$h/.pm2/logs/${base}"*.log; do [ -f "$f" ] && { echo "=== $f ===" >&2; tail -n "$LINES" "$f"; return 0; }; done
    done
    # ultimo recurso: lista arquivos e mostra README de como iniciar
    echo "Nenhum arquivo .log encontrado em ${p}." >&2
    echo "Conteudo de ${p}:" >&2
    ls -la "$p" 2>&1 | head -20 >&2
    # tenta mostrar pm2 status geral filtrado
    if command_exists pm2; then
        echo "--- pm2 status (filtrado) ---" >&2
        pm2 jlist 2>/dev/null | jq -r --arg q "$base" '.[] | select(.name | contains($q)) | "\(.name) — \(.pm2_env.status) — \(.pm2_env.pm_out_log // "")"' 2>&1 | head -20 >&2
    fi
    return 1
}

# ---------- auto-start (se app registrado mas sem processo) ----------
AUTO_STARTED="${AUTO_STARTED:-0}"

case "$FOUND_KIND" in
    pm2) handle_pm2 "$FOUND_VAL" ;;
    pm2user)
             user="$(echo "$FOUND_VAL" | cut -d: -f1)"; name="$(echo "$FOUND_VAL" | cut -d: -f2-)"
             handle_pm2user "$user" "$name" ;;
    pm2file) handle_pm2file "$FOUND_VAL" ;;
    docker) handle_docker "$FOUND_VAL" ;;
    systemd) handle_systemd "$FOUND_VAL" ;;
    nginx) handle_nginx "$FOUND_VAL" ;;
    path) handle_path "$FOUND_VAL" ;;
    *)
        # Auto-start: se app registrado/pasta existe mas sem processo, inicia automaticamente
        if [ "$AUTO_STARTED" -eq 0 ]; then
            _can_start=false
            if command -v ob_apps_get >/dev/null 2>&1; then
                _info="$(ob_apps_get "$NAME_RAW" 2>/dev/null)"
                [ -n "$_info" ] && [ "$_info" != "null" ] && _can_start=true
            fi
            if [ "$_can_start" = false ] && [ -d "${OB_APPS_DIR:-/var/www}/${NAME_RAW}" ]; then
                _can_start=true
            fi
            if [ "$_can_start" = true ]; then
                echo -e "  ${CYAN}${SPIN}${NC} App registrado mas sem processo — iniciando..." >&2
                bash "${OB_HOME}/commands/start.sh" "$NAME_RAW" --no-install >/dev/null 2>&1 || true
                # re-executa com flag para evitar loop
                exec env AUTO_STARTED=1 bash "$0" "${ORIG_ARGS[@]}"
            fi
        fi
        # Nenhuma fonte encontrada — saida estruturada p/ frontend
        ERR_MSG="Nao encontrei logs para '${NAME_RAW}' (pm2/docker/systemd/nginx/arquivos)."
        HINT="Se o app foi publicado via hadix.site, rode: bootstrap start ${NAME_RAW}   (ou: 1) pm2 list | grep ${NAME_RAW}  2) ls /var/www/  3) Atividade → Deployments e se MAIN/START estao corretos)."
        # lista o que foi tentado
        TRIED="tentativas: $(printf '%s, ' "${CANDIDATES[@]}" | sed 's/, $//')"
        if [ "$JSON_OUT" = true ]; then
            jq -n --arg name "$NAME_RAW" --arg tried "$TRIED" --arg hint "$HINT" '{error: $tried, name: $name, hint: $hint, apps: []}' 2>/dev/null || echo "{\"error\":\"$ERR_MSG\",\"tried\":\"$TRIED\"}"
        else
            (command -v log_error >/dev/null 2>&1 && log_error "$ERR_MSG" || echo "ERRO: $ERR_MSG" >&2)
            echo "  $TRIED" >&2
            echo "  $HINT" >&2
            if command -v ob_apps_list >/dev/null 2>&1; then
                _apps_list="$(ob_apps_list 2>/dev/null | tr '\n' ' ')"
                # fallback se jq ausente e lista vazia: tenta grep no apps.json
                if [ -z "$_apps_list" ] && [ -f "${OB_APPS_FILE:-}" ]; then
                    _apps_list="$(grep -o '"[^"]*"[[:space:]]*:[[:space:]]*{' "${OB_APPS_FILE}" 2>/dev/null | sed -E 's/\"([^\"]*)\".*/\1/' | tr '\n' ' ')"
                fi
                echo "  Apps registrados: ${_apps_list:- (nenhum)}" >&2
            fi
            if command_exists pm2; then
                if command -v jq >/dev/null 2>&1; then
                    echo "  pm2 processos: $(pm2 jlist 2>/dev/null | jq -r '.[].name' 2>/dev/null | tr '\n' ' ')" >&2
                else
                    echo "  pm2 processos: $(pm2 jlist 2>/dev/null | grep -o '\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' 2>/dev/null | head -5 | tr '\n' ' ')" >&2
                fi
            fi
            # ainda tenta mostrar algo util: lista pasta se existir
            _apps_dir="${OB_APPS_DIR:-/var/www}"
            if [ -d "${_apps_dir}/${NAME_RAW}" ]; then
                echo "--- ${_apps_dir}/${NAME_RAW} existe, mas sem processo pm2/docker ativo ---" >&2
                ls -la "${_apps_dir}/${NAME_RAW}" 2>&1 | head -30 >&2
                # mostra package.json start
                [ -f "${_apps_dir}/${NAME_RAW}/package.json" ] && (jq '.scripts' "${_apps_dir}/${NAME_RAW}/package.json" 2>&1 | head -20 >&2 || cat "${_apps_dir}/${NAME_RAW}/package.json" 2>&1 | head -20 >&2)
            fi
        fi
        exit 1
        ;;
esac
