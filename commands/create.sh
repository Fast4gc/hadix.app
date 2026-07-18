#!/usr/bin/env bash
# commands/create.sh — o "diferencial": scaffolding a partir de templates prontos
#
# Uso:
#   bootstrap create <template> [nome] [dominio]
#
# Templates: nextjs, vite, discord, express, nest, fastify, hono, python, go
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

TEMPLATE="${1:-}"
if [ -z "$TEMPLATE" ]; then
    echo "Templates disponiveis: nextjs, vite, discord, express, nest, fastify, hono, python, go"
    TEMPLATE="$(ask "Qual template" "")"
fi

NAME="${2:-$(ask "Nome do projeto" "meu-app")}"
NAME="$(slugify "$NAME")"
APP_PATH="${OB_APPS_DIR}/${NAME}"

[ -d "$APP_PATH" ] && { log_error "Diretorio ${APP_PATH} ja existe."; exit 1; }

ensure_node()   { command_exists node   || bash "${OB_HOME}/installers/node.sh"; }
ensure_pnpm()   { command_exists pnpm   || bash "${OB_HOME}/installers/pnpm.sh"; }
ensure_pm2()    { command_exists pm2    || bash "${OB_HOME}/installers/pm2.sh"; }
ensure_nginx()  { command_exists nginx  || bash "${OB_HOME}/installers/nginx.sh"; }
ensure_python() { command_exists python3 || pkg_install python3 python3-pip python3-venv; }
ensure_go()     { command_exists go || { pkg_install golang || pkg_install golang-bin; }; }

publish_nginx_static() {
    local domain="$1" root="$2"
    [ -z "$domain" ] && return 0
    ensure_nginx
    sed -e "s#__DOMAIN__#${domain}#g" -e "s#__ROOT_PATH__#${root}#g" -e "s#__APP_NAME__#${NAME}#g" \
        "${OB_HOME}/templates/nginx/static.conf" > "/etc/nginx/sites-available/${NAME}.conf"
    ln -sf "/etc/nginx/sites-available/${NAME}.conf" "/etc/nginx/sites-enabled/${NAME}.conf"
    nginx -t && systemctl reload nginx
}

publish_nginx_proxy() {
    local domain="$1" port="$2"
    [ -z "$domain" ] && return 0
    ensure_nginx
    sed -e "s#__DOMAIN__#${domain}#g" -e "s#__PORT__#${port}#g" -e "s#__APP_NAME__#${NAME}#g" \
        "${OB_HOME}/templates/nginx/api.conf" > "/etc/nginx/sites-available/${NAME}.conf"
    ln -sf "/etc/nginx/sites-available/${NAME}.conf" "/etc/nginx/sites-enabled/${NAME}.conf"
    nginx -t && systemctl reload nginx
}

case "$TEMPLATE" in

  nextjs)
    log_step "Criando projeto Next.js: ${NAME}"
    ensure_node; ensure_pnpm; ensure_pm2
    PORT="$(ask "Porta" "$(next_free_port 3000)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    npx --yes create-next-app@latest "$APP_PATH" --yes --use-pnpm \
        --ts --eslint --app --src-dir --import-alias "@/*" --tailwind
    (cd "$APP_PATH" && pnpm build)
    (cd "$APP_PATH" && pm2 start "pnpm start -- -p ${PORT}" --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "nextjs" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "Next.js '${NAME}' rodando na porta ${PORT}."
    ;;

  vite)
    log_step "Criando projeto Vite: ${NAME}"
    ensure_node; ensure_pnpm; ensure_nginx
    FRAMEWORK="$(ask "Framework (vanilla/react/react-ts/vue/svelte)" "react-ts")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    npx --yes create-vite@latest "$APP_PATH" --template "$FRAMEWORK"
    (cd "$APP_PATH" && pnpm install && pnpm build)
    publish_nginx_static "$DOMAIN" "${APP_PATH}/dist"
    ob_apps_add "$NAME" "vite" "0" "$DOMAIN" "$APP_PATH"
    log_ok "Vite '${NAME}' publicado (build estatico em dist/)."
    [ -n "$DOMAIN" ] && log_info "Acesse: http://${DOMAIN}"
    ;;

  discord)
    log_step "Criando bot Discord: ${NAME}"
    bash "${OB_HOME}/commands/create-bot.sh" "$NAME" <<< "1"
    ;;

  express)
    log_step "Criando API Express: ${NAME}"
    bash "${OB_HOME}/commands/create-api.sh" "$NAME"
    ;;

  nest)
    log_step "Criando projeto NestJS: ${NAME}"
    ensure_node; ensure_pnpm; ensure_pm2
    PORT="$(ask "Porta" "$(next_free_port 3000)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    npx --yes @nestjs/cli new "$NAME" --directory "$APP_PATH" --package-manager pnpm --skip-git
    echo "PORT=${PORT}" > "${APP_PATH}/.env"
    (cd "$APP_PATH" && pnpm build)
    (cd "$APP_PATH" && PORT="$PORT" pm2 start "pnpm start:prod" --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "nest" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "NestJS '${NAME}' rodando na porta ${PORT}."
    ;;

  fastify)
    log_step "Criando API Fastify: ${NAME}"
    ensure_node; ensure_pm2
    PORT="$(ask "Porta" "$(next_free_port 3000)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    mkdir -p "$APP_PATH"
    cat > "${APP_PATH}/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "main": "index.js",
  "scripts": { "start": "node index.js" }, "dependencies": { "fastify": "^4.28.1" } }
PKG
    cat > "${APP_PATH}/index.js" << JS
const fastify = require('fastify')({ logger: true });
const PORT = process.env.PORT || ${PORT};

fastify.get('/', async () => ({ message: 'Fastify rodando via oracle-bootstrap' }));
fastify.get('/health', async () => ({ status: 'ok' }));

fastify.listen({ port: PORT, host: '0.0.0.0' });
JS
    echo "PORT=${PORT}" > "${APP_PATH}/.env"
    (cd "$APP_PATH" && npm install --production --silent)
    (cd "$APP_PATH" && pm2 start index.js --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "fastify" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "Fastify '${NAME}' rodando na porta ${PORT}."
    ;;

  hono)
    log_step "Criando API Hono (Node): ${NAME}"
    ensure_node; ensure_pm2
    PORT="$(ask "Porta" "$(next_free_port 3000)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    mkdir -p "$APP_PATH"
    cat > "${APP_PATH}/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "type": "module", "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "hono": "^4.5.0", "@hono/node-server": "^1.12.0" } }
PKG
    cat > "${APP_PATH}/index.js" << JS
import { serve } from '@hono/node-server';
import { Hono } from 'hono';

const app = new Hono();
app.get('/', (c) => c.json({ message: 'Hono rodando via oracle-bootstrap' }));
app.get('/health', (c) => c.json({ status: 'ok' }));

serve({ fetch: app.fetch, port: ${PORT} });
console.log('Hono ouvindo na porta ${PORT}');
JS
    echo "PORT=${PORT}" > "${APP_PATH}/.env"
    (cd "$APP_PATH" && npm install --production --silent)
    (cd "$APP_PATH" && pm2 start index.js --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "hono" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "Hono '${NAME}' rodando na porta ${PORT}."
    ;;

  python)
    log_step "Criando API Python (FastAPI + uvicorn): ${NAME}"
    ensure_python; ensure_pm2; ensure_node
    PORT="$(ask "Porta" "$(next_free_port 8000)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    mkdir -p "$APP_PATH"
    cat > "${APP_PATH}/requirements.txt" << 'REQ'
fastapi
uvicorn[standard]
REQ
    cat > "${APP_PATH}/main.py" << 'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "FastAPI rodando via oracle-bootstrap"}

@app.get("/health")
def health():
    return {"status": "ok"}
PY
    (cd "$APP_PATH" && python3 -m venv venv && ./venv/bin/pip install -q -r requirements.txt)
    (cd "$APP_PATH" && pm2 start "venv/bin/uvicorn main:app --host 0.0.0.0 --port ${PORT}" --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "python" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "FastAPI '${NAME}' rodando na porta ${PORT}."
    ;;

  go)
    log_step "Criando API Go (net/http): ${NAME}"
    ensure_go; ensure_pm2; ensure_node
    PORT="$(ask "Porta" "$(next_free_port 8080)")"
    DOMAIN="$(ask "Dominio (vazio = so IP)" "")"
    mkdir -p "$APP_PATH"
    cat > "${APP_PATH}/go.mod" << GOMOD
module ${NAME}

go 1.22
GOMOD
    cat > "${APP_PATH}/main.go" << GO
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"message": "Go rodando via oracle-bootstrap"})
	})
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
	log.Println("ouvindo na porta ${PORT}")
	log.Fatal(http.ListenAndServe(":${PORT}", nil))
}
GO
    (cd "$APP_PATH" && go build -o "$NAME" .)
    (cd "$APP_PATH" && pm2 start "./${NAME}" --name "$NAME")
    pm2 save
    publish_nginx_proxy "$DOMAIN" "$PORT"
    ob_apps_add "$NAME" "go" "$PORT" "$DOMAIN" "$APP_PATH"
    log_ok "Go '${NAME}' rodando na porta ${PORT}."
    ;;

  *)
    log_error "Template desconhecido: '${TEMPLATE}'"
    echo "Disponiveis: nextjs, vite, discord, express, nest, fastify, hono, python, go"
    exit 1
    ;;
esac

[ -n "${DOMAIN:-}" ] && echo "Dica: rode 'bootstrap ssl ${DOMAIN}' para ativar HTTPS."
