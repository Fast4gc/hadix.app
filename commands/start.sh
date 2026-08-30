#!/usr/bin/env bash
# commands/start.sh — executor inteligente de apps Hadix (Node/Python/Go/etc)
# Detecta runtime, valida entrypoint, instala deps, gerencia via PM2 com estados
#
# Uso: bootstrap start <nome> [--no-install] [--skip-files]
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
ob_config_init

command_exists() { command -v "$1" >/dev/null 2>&1; }

NAME=""; DO_INSTALL=true; SKIP_FILES=false
for arg in "$@"; do
  case "$arg" in --no-install) DO_INSTALL=false;; --skip-files) SKIP_FILES=true;; --help|-h) echo "Uso: bootstrap start <nome> [--no-install] [--skip-files]"; exit 0;; -*) ;; *) [ -z "$NAME" ] && NAME="$arg";;
  esac
done
[ -z "$NAME" ] && { log_error "Nome do app obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"

# ── resolve metadados ──
info="$(ob_apps_get "$NAME" 2>/dev/null)"
if [ -z "$info" ] || [ "$info" = "null" ]; then
  [ -f "${OB_APPS_FILE:-}" ] && info="$(grep -o "\"${NAME}\"[[:space:]]*:[[:space:]]*{[^}]*}" "$OB_APPS_FILE" 2>/dev/null | head -1)"
fi
detect_from_folder() {
  [ -d "${OB_APPS_DIR:-/var/www}/${NAME}" ] || return 1
  APP_DIR="${OB_APPS_DIR:-/var/www}/${NAME}"; MAIN="index.js"; START=""; PORT=0; DOMAIN=""
  [ -f "$APP_DIR/package.json" ] && command_exists jq && {
    MAIN="$(jq -r '.main // "index.js"' "$APP_DIR/package.json" 2>/dev/null)"
    [ "$(jq -r '.scripts.start // empty' "$APP_DIR/package.json" 2>/dev/null)" != "" ] && START="$(jq -r '.scripts.start' "$APP_DIR/package.json" 2>/dev/null)"
  }
  return 0
}
if [ -z "$info" ]; then detect_from_folder || { log_error "App '${NAME}' nao registrado (e pasta ${OB_APPS_DIR:-/var/www}/${NAME} nao existe)."; exit 1; }; fi
if [ -n "$info" ]; then
  if command_exists jq; then
    APPTYPE="$(echo "$info" | jq -r '.type // "bot"')"; MAIN="$(echo "$info" | jq -r '.main // empty')"; START="$(echo "$info" | jq -r '.start // empty')"; BUILD="$(echo "$info" | jq -r '.build // empty')"
    PORT="$(echo "$info" | jq -r '.port // 0')"; DOMAIN="$(echo "$info" | jq -r '.domain // empty')"; PATHREG="$(echo "$info" | jq -r '.path // empty')"
  else
    APPTYPE="$(echo "$info" | grep -o '"type"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"; [ -z "$APPTYPE" ] && APPTYPE="bot"
    MAIN="$(echo "$info" | grep -o '"main"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
    START="$(echo "$info" | grep -o '"start"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
    PORT="$(echo "$info" | grep -o '"port"[^:]*:[0-9]*' | head -1 | sed 's/.*"port"[^:]*:\([0-9]*\).*/\1/')"; [ -z "$PORT" ] && PORT=0
    DOMAIN="$(echo "$info" | grep -o '"domain"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
    PATHREG="$(echo "$info" | grep -o '"path"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
    BUILD="$(echo "$info" | grep -o '"build"[^:]*:[^"]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
  fi
fi
[ -z "${APP_DIR:-}" ] && [ -n "$PATHREG" ] && APP_DIR="$PATHREG"
[ -z "${APP_DIR:-}" ] && APP_DIR="${OB_APPS_DIR:-/var/www}/${NAME}"
[ -z "${BUILD:-}" ] && BUILD=""
[ -z "$MAIN" ] && MAIN="index.js"; [ -z "$START" ] && [ "$APPTYPE" = "site" ] && START=""

# ── deploy atomico ──
mkdir -p "${HADIX_HOSTING_DIR:-/var/hadix}/logs" 2>/dev/null || true
DEPLOY_LOG="${HADIX_HOSTING_DIR:-/var/hadix}/logs/${NAME}.deploy.log"
SNAPSHOT_DIR=""
if [ -d "$APP_DIR" ]; then
  SNAPSHOT_DIR="$(mktemp -d)/${NAME}.snapshot"
  cp -r "$APP_DIR" "$SNAPSHOT_DIR" 2>/dev/null || true
fi
DEPLOY_FAILED=false
rollback() { if [ "$DEPLOY_FAILED" = true ] && [ -n "$SNAPSHOT_DIR" ] && [ -d "$SNAPSHOT_DIR" ]; then rm -rf "$APP_DIR" 2>/dev/null; mv "$SNAPSHOT_DIR" "$APP_DIR" 2>/dev/null; fi; }
deploy_fail() { DEPLOY_FAILED=true; rollback; log_error "$1"; exit 1; }
exec 3> >(tee -a "$DEPLOY_LOG" 2>/dev/null || true)
echo "[$(date -Iseconds)] deploy '${NAME}' inicio" >&3

# ════════════════════════════════════════════════════════════════════
# P0 — RUNTIME DETECTION + VALIDACAO
# ════════════════════════════════════════════════════════════════════
RUN_MAIN="$APP_DIR/$MAIN"
detect_runtime() {
  local ext
  ext="$(echo "$MAIN" | sed 's/.*\.//')"
  case "$ext" in
    js|mjs|cjs)
      [ -f "$APP_DIR/package.json" ] && RUNTIME="node" || RUNTIME="node"
      EXT_LANG="Node.js"
      RUN_CMD="node"
      [ "$ext" = "mjs" ] && RUN_CMD="node --experimental-modules"
      ;;
    ts|mts|cts)
      RUNTIME="node"; EXT_LANG="Node.js (TypeScript)"; RUN_CMD="npx tsx"
      ;;
    py)
      RUNTIME="python"; EXT_LANG="Python"; RUN_CMD="python3"
      ;;
    rb)
      RUNTIME="ruby"; EXT_LANG="Ruby"; RUN_CMD="ruby"
      ;;
    go)
      RUNTIME="go"; EXT_LANG="Go"; RUN_CMD="go run"
      ;;
    rs)
      RUNTIME="rust"; EXT_LANG="Rust"; RUN_CMD="cargo run --bin ${NAME}"
      ;;
    php)
      RUNTIME="php"; EXT_LANG="PHP"; RUN_CMD="php"
      ;;
    lua)
      RUNTIME="lua"; EXT_LANG="Lua"; RUN_CMD="lua"
      ;;
    *)
      # fallback: tenta detectar por arquivos de config
      [ -f "$APP_DIR/package.json" ] && { RUNTIME="node"; EXT_LANG="Node.js"; RUN_CMD="node"; }
      [ -f "$APP_DIR/requirements.txt" ] && { RUNTIME="python"; EXT_LANG="Python"; RUN_CMD="python3"; }
      [ -f "$APP_DIR/go.mod" ] && { RUNTIME="go"; EXT_LANG="Go"; RUN_CMD="go run"; }
      [ -z "${RUNTIME:-}" ] && { RUNTIME="node"; EXT_LANG="Node.js"; RUN_CMD="node"; }
      ;;
  esac
}
detect_runtime

# P0 — VALIDACAO DO ENTRYPOINT
log_step "[VALIDACAO] Entrypoint: ${MAIN} (${EXT_LANG})"
[ ! -f "$RUN_MAIN" ] && deploy_fail "Entrypoint '${MAIN}' nao encontrado em ${APP_DIR}."

# P0 — VALIDACAO DE COERENCIA RUNTIME <-> PROJETO
# Impede misturar linguagens: o runtime deve bater com a configuracao do app.
case "$RUNTIME" in
  node)
    # MAIN e Node (.js/.mjs/.cjs) mas o projeto parece Python -> erro de config
    [ -f "${APP_DIR}/requirements.txt" ] && [ ! -f "$APP_DIR/package.json" ] \
      && deploy_fail "Runtime mismatch: '$MAIN' e Node.js, mas ha requirements.txt (projeto Python). Use $MAIN com extensao .py ou remova requirements.txt."
    ;;
  python)
    # MAIN e Python (.py) mas o projeto parece Node -> erro de config
    [ -f "$APP_DIR/package.json" ] && [ ! -f "${APP_DIR}/requirements.txt" ] \
      && deploy_fail "Runtime mismatch: '$MAIN' e Python, mas ha package.json (projeto Node). Use extensao .js/.mjs/.cjs ou remova package.json."
    ;;
esac

# P0 — VERIFICA RUNTIME DISPONIVEL
RUNTIME_BIN="${RUN_CMD%% *}"
command_exists "$RUNTIME_BIN" || deploy_fail "Runtime '${RUNTIME_BIN}' (${EXT_LANG}) nao instalado. Rode: bootstrap production"
log_ok "Runtime detectado: ${EXT_LANG} (${RUN_CMD})"

# P0 — VERIFICA CONFIG DE DEPENDENCIAS + PREPARA
DEPS_FILE=""; DEPS_CMD=""
case "$RUNTIME" in
  node)
    [ -f "$APP_DIR/package.json" ] || deploy_fail "package.json nao encontrado — necessario para apps Node.js."
    if [ -f "$APP_DIR/pnpm-lock.yaml" ]; then
      DEPS_FILE="pnpm-lock.yaml"; DEPS_CMD="pnpm install --no-frozen-lockfile"
    elif [ -f "$APP_DIR/bun.lockb" ] || [ -f "$APP_DIR/bun.lock" ]; then
      DEPS_FILE="bun.lock"; DEPS_CMD="bun install"
    elif [ -f "$APP_DIR/yarn.lock" ]; then
      DEPS_FILE="yarn.lock"; DEPS_CMD="yarn install"
    elif [ -f "$APP_DIR/package-lock.json" ]; then
      DEPS_FILE="package-lock.json"; DEPS_CMD="npm ci"
    else
      DEPS_FILE="package.json"; DEPS_CMD="npm install"
    fi
    # le scripts.start do package.json
    command_exists jq && {
      PKG_START="$(jq -r '.scripts.start // empty' "$APP_DIR/package.json" 2>/dev/null)"
      [ -n "$PKG_START" ] && START="$PKG_START"
      PKG_MAIN="$(jq -r '.main // empty' "$APP_DIR/package.json" 2>/dev/null)"
      [ -n "$PKG_MAIN" ] && MAIN="$PKG_MAIN"
    }
    log_ok "Node.js: ${DEPS_FILE} detectado, comando install: ${DEPS_CMD}"
    ;;
  python)
    [ -f "$APP_DIR/requirements.txt" ] || deploy_fail "requirements.txt nao encontrado — necessario para apps Python."
    DEPS_FILE="requirements.txt"; DEPS_CMD="pip install -r requirements.txt"
    log_ok "Python: requirements.txt detectado"
    ;;
esac

# P1 — PRE-DEPLOY VALIDATION SUMMARY
log_step "VALIDACAO"
echo "  ${GREEN}${TICK}${NC} Entrypoint: ${MAIN} (${EXT_LANG})" >&3
echo "  ${GREEN}${TICK}${NC} Runtime: ${RUNTIME} (${RUN_CMD})" >&3
echo "  ${GREEN}${TICK}${NC} Dependencias: ${DEPS_FILE:-nenhum}" >&3
echo "  ${GREEN}${TICK}${NC} Ambiente: ${APP_DIR}" >&3
echo "  ${GREEN}${TICK}${NC} App pronto para deploy" >&3

# ════════════════════════════════════════════════════════════════════
# P1 — INSTALL DEPENDENCIAS  
# ════════════════════════════════════════════════════════════════════
if [ "$DO_INSTALL" = true ]; then
  log_step "Instalando dependencias..."
  case "$RUNTIME" in
    node)
      if [ -f "$APP_DIR/pnpm-lock.yaml" ]; then
        command_exists pnpm || deploy_fail "pnpm-lock.yaml encontrado, mas pnpm nao esta instalado. Rode: bootstrap production"
        (cd "$APP_DIR" && pnpm install --no-frozen-lockfile) >&3 2>&1 || deploy_fail "pnpm install falhou — veja ${DEPLOY_LOG}"
      elif { [ -f "$APP_DIR/bun.lockb" ] || [ -f "$APP_DIR/bun.lock" ]; }; then
        command_exists bun || deploy_fail "Lockfile do Bun encontrado, mas bun nao esta instalado. Rode: bootstrap production"
        (cd "$APP_DIR" && bun install) >&3 2>&1 || deploy_fail "bun install falhou — veja ${DEPLOY_LOG}"
      elif [ -f "$APP_DIR/yarn.lock" ]; then
        command_exists yarn || deploy_fail "yarn.lock encontrado, mas yarn nao esta instalado."
        (cd "$APP_DIR" && yarn install) >&3 2>&1 || deploy_fail "yarn install falhou — veja ${DEPLOY_LOG}"
      elif [ -f "$APP_DIR/package-lock.json" ] && command_exists npm; then
        (cd "$APP_DIR" && npm ci --no-audit --no-fund) >&3 2>&1 || (cd "$APP_DIR" && npm install --no-audit --no-fund) >&3 2>&1 || deploy_fail "npm install/ci falhou — veja ${DEPLOY_LOG}"
      elif command_exists npm; then
        (cd "$APP_DIR" && npm install --no-audit --no-fund) >&3 2>&1 || deploy_fail "npm install falhou — veja ${DEPLOY_LOG}"
      elif command_exists pnpm; then
        (cd "$APP_DIR" && pnpm install --no-frozen-lockfile) >&3 2>&1 || deploy_fail "pnpm install falhou"
      fi
      log_ok "Dependencias Node instaladas"
      ;;
    python)
      # ambiente virtual isolado
      VENV_DIR="$APP_DIR/.venv"
      if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR" >&3 2>&1 || deploy_fail "python3 -m venv falhou"
      fi
      "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt" >&3 2>&1 || deploy_fail "pip install falhou — veja ${DEPLOY_LOG}"
      RUN_CMD="$VENV_DIR/bin/python"
      log_ok "Dependencias Python instaladas (venv: ${VENV_DIR})"
      ;;
  esac
fi

# BUILD e opcional. Sem ele, os manifests acima ainda instalam dependencias.
# Quando declarado pela dashboard/hadix.config, executa somente depois da
# instalacao ter terminado e propaga a falha para o deployment.
AUTO_BUILD=""
if [ -z "$BUILD" ] && [ -f "$APP_DIR/package.json" ] && command_exists jq; then
  if [ -n "$(jq -r '.scripts.build // empty' "$APP_DIR/package.json" 2>/dev/null)" ]; then
    if [ -f "$APP_DIR/pnpm-lock.yaml" ]; then AUTO_BUILD="pnpm run build"
    elif [ -f "$APP_DIR/bun.lockb" ] || [ -f "$APP_DIR/bun.lock" ]; then AUTO_BUILD="bun run build"
    elif [ -f "$APP_DIR/yarn.lock" ]; then AUTO_BUILD="yarn build"
    else AUTO_BUILD="npm run build"
    fi
  fi
fi
BUILD_CMD="${BUILD:-$AUTO_BUILD}"
if [ -n "$BUILD_CMD" ]; then
  log_step "Executando BUILD: ${BUILD_CMD}${AUTO_BUILD:+ (detectado automaticamente)}"
  (cd "$APP_DIR" && bash -lc "$BUILD_CMD") >&3 2>&1 || deploy_fail "BUILD falhou — veja ${DEPLOY_LOG}"
  log_ok "BUILD concluido"
fi

# ════════════════════════════════════════════════════════════════════
# P1 — ENVIRONMENT VARIABLES
# ════════════════════════════════════════════════════════════════════
ENV_FILE="$APP_DIR/.env"
HADIX_ENV_DIR="${HADIX_HOSTING_DIR:-/var/hadix}/envs"
if [ -f "$HADIX_ENV_DIR/${NAME}.env" ]; then
  # copia env especifico do app (se existir no diretorio central)
  cp "$HADIX_ENV_DIR/${NAME}.env" "$ENV_FILE" 2>/dev/null || true
  chmod 600 "$ENV_FILE" 2>/dev/null || true
fi
log_ok "Variaveis de ambiente carregadas (${ENV_FILE})" >&3

# ════════════════════════════════════════════════════════════════════
# P0 — PM2 PROCESS MANAGEMENT
# ════════════════════════════════════════════════════════════════════
command_exists pm2 || deploy_fail "pm2 nao instalado — rode bootstrap production"

# comando de execucao
case "$RUNTIME" in
  node)
    if [ -n "$START" ] && [ "$START" != "node ${MAIN}" ]; then
      # se scripts.start existe, usa npm start que respeita o script
      PM2_CMD="npm -- start"
      PM2_ARGS=""
    else
      PM2_CMD="$MAIN"
      PM2_ARGS=""
    fi
    ;;
  python)
    if [ -n "$START" ]; then
      PM2_CMD="$START"
    else
      PM2_CMD="$MAIN"
      PM2_ARGS="--interpreter python3"
    fi
    ;;
  *)
    PM2_CMD="$MAIN"
    PM2_ARGS=""
    ;;
esac

# se ja existe no pm2, restart
if pm2 describe "$NAME" >/dev/null 2>&1; then
  pm2 restart "$NAME" >&3 2>&1
  log_ok "'${NAME}' reiniciado via pm2"
else
  log_step "Iniciando com PM2..."
  # P1 — STRUCTURED LOG: pm2 com --time (adiciona timestamp) + log
  if [ "$RUNTIME" = "node" ] && [ -n "$START" ]; then
    # usa npm start para respeitar scripts.start
    (cd "$APP_DIR" && pm2 start npm --name "$NAME" --cwd "$APP_DIR" -- run start --time --restart-delay 3000 --max-restarts 10 --merge-logs) >&3 2>&1
  elif [ "$RUNTIME" = "python" ]; then
    (cd "$APP_DIR" && pm2 start "$MAIN" --name "$NAME" --interpreter "$RUN_CMD" --cwd "$APP_DIR" --time --restart-delay 3000 --max-restarts 10 --merge-logs) >&3 2>&1
  else
    (cd "$APP_DIR" && pm2 start "$MAIN" --name "$NAME" --cwd "$APP_DIR" --time --restart-delay 3000 --max-restarts 10 --merge-logs) >&3 2>&1
  fi
  pm2 save >&3 2>&1 || true
  # verifica estado apos inicio
  sleep 3
  _status="$(pm2 jlist 2>/dev/null | jq -r --arg n "$NAME" '.[] | select(.name==$n) | .pm2_env.status' 2>/dev/null || echo "stopped")"
  if [ "$_status" = "online" ]; then
    log_ok "'${NAME}' online via pm2 (${RUNTIME})"
  else
    # P1 — CRASHED STATE: mostra saida real do pm2
    _err="$(pm2 jlist 2>/dev/null | jq -r --arg n "$NAME" '.[] | select(.name==$n) | .pm2_env.pm_err_log_path // empty' 2>/dev/null)"
    _err_msg=""
    [ -n "$_err" ] && [ -f "$_err" ] && _err_msg="$(tail -5 "$_err" 2>/dev/null)"
    deploy_fail "App '${NAME}' nao ficou online (status=${_status}). Erro: ${_err_msg}"
  fi
fi

# ════════════════════════════════════════════════════════════════════
# P1 — UPDATE APP STATE ON apps.json
# ════════════════════════════════════════════════════════════════════
if command_exists jq && [ -f "$OB_APPS_FILE" ]; then
  tmp="$(mktemp)"
  jq --arg n "$NAME" --arg p "$APP_DIR" --arg r "$RUNTIME" --arg s "online" \
    '.[$n].path = $p | .[$n].runtime = $r | .[$n].status = $s' "$OB_APPS_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$OB_APPS_FILE" 2>/dev/null
fi

echo ""
log_ok "App '${NAME}' online (${RUNTIME}). Logs: bootstrap logs ${NAME} | Status: bootstrap status ${NAME}"
exec 3>&- 2>/dev/null || true
exit 0
