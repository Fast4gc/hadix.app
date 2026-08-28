#!/usr/bin/env bash
# commands/start.sh — sobe um app no PM2 a partir do registro em apps.json
# (usado pelo front hadix.site via vps-api, e manualmente via CLI).
#
# O app e registrado em apps.json pelo endpoint /config/apps/add do vps-api
# (name, type, main, start, port, domain, path). Este comando garante que o
# processo esteja rodando: cria a pasta se faltar, escreve um starter minimo
# (caso o codigo ainda nao tenha sido enviado), instala dependencias e inicia
# via pm2 com o mesmo nome do app. Assim os logs/status passam a funcionar.
#
# Uso:
#   bootstrap start <nome>
#   bootstrap start <nome> --no-install   # nao roda npm install
#   bootstrap start <nome> --skip-files   # nao cria starter se pasta vazia
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

command_exists() { command -v "$1" >/dev/null 2>&1; }

NAME=""
DO_INSTALL=true
SKIP_FILES=false
for arg in "$@"; do
    case "$arg" in
        --no-install) DO_INSTALL=false;;
        --skip-files) SKIP_FILES=true;;
        --help|-h) echo "Uso: bootstrap start <nome> [--no-install] [--skip-files]"; exit 0;;
        -*) ;;
        *) [ -z "$NAME" ] && NAME="$arg";;
    esac
done

[ -z "$NAME" ] && { log_error "Nome do app obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"

# --- resolve os metadados do app (apps.json) ---
info="$(ob_apps_get "$NAME" 2>/dev/null)"
if [ -z "$info" ] || [ "$info" = "null" ]; then
    # fallback sem jq: tenta casar chave no apps.json
    if command_exists jq; then
        info=""
    else
        info="$(grep -o "\"${NAME}\"[[:space:]]*:[[:space:]]*{[^}]*}" "$OB_APPS_FILE" 2>/dev/null | head -1)"
    fi
fi
# Se nao registrado, ainda permite iniciar a partir de uma pasta existente
if [ -z "$info" ]; then
    if [ -d "${OB_APPS_DIR:-/var/www}/${NAME}" ]; then
        log_info "App '${NAME}' nao esta em apps.json, mas a pasta existe — iniciando pela pasta."
        APPTYPE="bot"
        MAIN="index.js"
        START=""
        PORT=0
        DOMAIN=""
        APP_DIR="${OB_APPS_DIR:-/var/www}/${NAME}"
        if [ -f "$APP_DIR/package.json" ]; then
            if command_exists jq; then
                MAIN="$(jq -r '.main // "index.js"' "$APP_DIR/package.json" 2>/dev/null)"
                [ "$(jq -r '.scripts.start // empty' "$APP_DIR/package.json" 2>/dev/null)" != "" ] \
                    && START="$(jq -r '.scripts.start' "$APP_DIR/package.json" 2>/dev/null)"
            fi
        fi
    else
        log_error "App '${NAME}' nao registrado em apps.json (e pasta ${OB_APPS_DIR:-/var/www}/${NAME} nao existe)."
        echo "  Registre via: bootstrap status ${NAME}  (ou crie antes com create-*)."
        exit 1
    fi
fi

if [ -n "$info" ]; then
    if command_exists jq; then
        APPTYPE="$(echo "$info" | jq -r '.type // "bot"' 2>/dev/null || echo bot)"
        MAIN="$(echo "$info" | jq -r '.main // empty' 2>/dev/null)"
        START="$(echo "$info" | jq -r '.start // empty' 2>/dev/null)"
        PORT="$(echo "$info" | jq -r '.port // 0' 2>/dev/null || echo 0)"
        DOMAIN="$(echo "$info" | jq -r '.domain // empty' 2>/dev/null)"
        PATHREG="$(echo "$info" | jq -r '.path // empty' 2>/dev/null)"
    else
        APPTYPE="$(echo "$info" | grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"type"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
        [ -z "$APPTYPE" ] && APPTYPE="bot"
        MAIN="$(echo "$info" | grep -o '"main"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"main"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
        START="$(echo "$info" | grep -o '"start"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"start"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
        PORT="$(echo "$info" | grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed -E 's/.*"port"[[:space:]]*:[[:space:]]*([0-9]*).*/\1/')"
        [ -z "$PORT" ] && PORT=0
        DOMAIN="$(echo "$info" | grep -o '"domain"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"domain"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
        PATHREG="$(echo "$info" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    fi
fi
# path registrado mas pasta ainda nao existe: usa
[ -z "${APP_DIR:-}" ] && [ -n "$PATHREG" ] && APP_DIR="$PATHREG"
[ -z "${APP_DIR:-}" ] && APP_DIR="${OB_APPS_DIR:-/var/www}/${NAME}"
[ -z "$MAIN" ] && MAIN="index.js"
[ -z "$START" ] && [ "$APPTYPE" = "site" ] && START=""

# --- garante a pasta e starter (se nao vier codigo do front) ---
if [ "$SKIP_FILES" = false ]; then
    if [ ! -d "$APP_DIR" ]; then
        mkdir -p "$APP_DIR"
        log_info "Pasta criada: ${APP_DIR}"
    fi
    # package.json base
    if [ "$APPTYPE" != "site" ] && [ ! -f "$APP_DIR/package.json" ]; then
        cat > "$APP_DIR/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "main": "${MAIN}",
  "scripts": { "start": "${START:-node ${MAIN}}" },
  "dependencies": { } }
PKG
        log_info "package.json starter criado."
    fi
    # main file starter (apenas se nao existir e tipo executavel)
    if [ "$APPTYPE" != "site" ] && [ ! -f "$APP_DIR/$MAIN" ]; then
        if [ "$APPTYPE" = "bot" ]; then
            cat > "$APP_DIR/$MAIN" << 'JS'
require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');
const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages] });
client.once('ready', () => console.log(`Bot online como ${client.user.tag}`));
client.on('messageCreate', (msg) => { if (msg.content === '!ping') msg.reply('pong! (hadix)'); });
client.login(process.env.DISCORD_TOKEN || process.env.TOKEN);
JS
        else
            cat > "$APP_DIR/$MAIN" << JS
require('dotenv').config();
const http = require('http');
http.createServer((req, res) => { res.writeHead(200, {'content-type':'text/plain'}); res.end('hadix app online'); })
  .listen(${PORT:-0}, () => console.log('listening' + (${PORT:-0} ? ' :${PORT}' : '')));
JS
        fi
        log_info "Starter ${MAIN} criado (o codigo real do app pode substituir)."
    fi
    # .env padrao p/ bots
    if [ "$APPTYPE" = "bot" ] && [ ! -f "$APP_DIR/.env" ]; then
        cat > "$APP_DIR/.env" << 'ENV'
DISCORD_TOKEN=
TOKEN=
ENV
        chmod 600 "$APP_DIR/.env" 2>/dev/null || true
    fi
fi

# --- instala dependencias ---
if [ "$DO_INSTALL" = true ] && [ -f "$APP_DIR/package.json" ] && command_exists npm; then
    log_step "Instalando dependencias em ${APP_DIR}"
    (cd "$APP_DIR" && npm install --production --no-audit --no-fund >/dev/null 2>&1) \
        || log_warn "npm install falhou (verifique package.json)."
fi

# --- inicia via pm2 (mesmo nome do app p/ logs/status resolverem) ---
if command_exists pm2; then
    if pm2 describe "$NAME" >/dev/null 2>&1; then
        pm2 restart "$NAME" >/dev/null 2>&1
        log_ok "'${NAME}' ja estava no pm2 — reiniciado."
    else
        if [ "$APPTYPE" = "site" ]; then
            # site estatico: sem processo node, apenas pasta (nginx cuida)
            log_ok "App '${NAME}' (site estatico) pronto — publique via nginx."
            exit 0
        fi
        cmd="node ${MAIN}"
        [ -n "$START" ] && cmd="$START"
        if (cd "$APP_DIR" && pm2 start "${MAIN}" --name "$NAME" --cwd "$APP_DIR" >/dev/null 2>&1); then
            log_ok "'${NAME}' iniciado via pm2 (${cmd})."
        else
            (cd "$APP_DIR" && pm2 start "${MAIN}" --name "$NAME" >/dev/null 2>&1) \
                && log_ok "'${NAME}' iniciado via pm2." \
                || log_error "Falha ao iniciar via pm2 em ${APP_DIR}."
        fi
    fi
    pm2 save >/dev/null 2>&1 || true
else
    log_warn "pm2 nao instalado — app '${NAME}' nao foi iniciado."
    echo "  Rode: bootstrap production   (instala pm2 e sobe a stack)"
    exit 1
fi

# atualiza apps.json com path confirmado
if command_exists jq; then
    if [ "$(echo "$info" | jq -r '.path // empty' 2>/dev/null)" != "$APP_DIR" ]; then
        tmp="$(mktemp)"
        jq --arg n "$NAME" --arg p "$APP_DIR" '.[$n].path = $p' "$OB_APPS_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$OB_APPS_FILE" 2>/dev/null
    fi
fi

echo ""
log_ok "App '${NAME}' online (bootstrap status ${NAME} / bootstrap logs ${NAME})."
