#!/usr/bin/env bash
# config.sh — caminhos e configuracao global do Hadix.app

export OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
export OB_CONFIG_DIR="${OB_HOME}/config"
export OB_APPS_FILE="${OB_CONFIG_DIR}/apps.json"
export OB_USERS_FILE="${OB_CONFIG_DIR}/users.json"
export OB_DOMAINS_FILE="${OB_CONFIG_DIR}/domains.json"
export OB_APPS_DIR="/var/www"
export OB_REPO_URL="https://github.com/Fast4gc/hadix.app"
export OB_RAW_URL="https://raw.githubusercontent.com/Fast4gc/hadix.app/main"
export OB_VERSION="1.1.0"

ob_config_init() {
    mkdir -p "$OB_CONFIG_DIR" "$OB_APPS_DIR"
    [ -f "$OB_APPS_FILE" ]    || echo '{}' > "$OB_APPS_FILE"
    [ -f "$OB_USERS_FILE" ]   || echo '{}' > "$OB_USERS_FILE"
    [ -f "$OB_DOMAINS_FILE" ] || echo '{}' > "$OB_DOMAINS_FILE"
}

# Le/edita registros das configs JSON usando jq (instalado como dependencia)
ob_apps_add() {
    # ob_apps_add <nome> <tipo> <porta> <dominio> <path>
    local name="$1" type="$2" port="$3" domain="$4" path="$5"
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$name" --arg type "$type" --arg port "$port" \
       --arg domain "$domain" --arg path "$path" --arg created "$(date -Iseconds)" \
       '.[$name] = {type: $type, port: ($port|tonumber), domain: $domain, path: $path, created: $created, status: "active"}' \
       "$OB_APPS_FILE" > "$tmp" && mv "$tmp" "$OB_APPS_FILE"
}

ob_apps_remove() {
    local name="$1"
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$name" 'del(.[$name])' "$OB_APPS_FILE" > "$tmp" && mv "$tmp" "$OB_APPS_FILE"
}

ob_apps_get() {
    local name="$1"
    jq -r --arg name "$name" '.[$name]' "$OB_APPS_FILE"
}

ob_apps_list() {
    jq -r 'keys[]' "$OB_APPS_FILE" 2>/dev/null
}
