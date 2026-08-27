#!/usr/bin/env bash
# config.sh — caminhos e configuracao global do Hadix.app
# Gerencia: apps, usuarios, dominios, planos, nodes (multi-VPS)

export OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
export OB_CONFIG_DIR="${OB_CONFIG_DIR:-${OB_HOME}/config}"
export OB_APPS_FILE="${OB_APPS_FILE:-${OB_CONFIG_DIR}/apps.json}"
export OB_USERS_FILE="${OB_USERS_FILE:-${OB_CONFIG_DIR}/users.json}"
export OB_DOMAINS_FILE="${OB_DOMAINS_FILE:-${OB_CONFIG_DIR}/domains.json}"
export OB_PLANS_FILE="${OB_PLANS_FILE:-${OB_CONFIG_DIR}/plans.json}"
export OB_NODES_FILE="${OB_NODES_FILE:-${OB_CONFIG_DIR}/nodes.json}"
export OB_APPS_DIR="${OB_APPS_DIR:-/var/www}"
export OB_REPO_URL="https://github.com/Fast4gc/hadix.app"
export OB_RAW_URL="https://raw.githubusercontent.com/Fast4gc/hadix.app/main"

# Front oficial do Hadix (exportado para https://hadix.site)
export OB_FRONT_URL="${OB_FRONT_URL:-https://hadix.site}"
export OB_FRONT_DIR="${OB_FRONT_DIR:-/var/www/hadix-front}"
export OB_FRONT_REPO="${OB_FRONT_REPO:-https://github.com/Fast4gc/hadix-front.git}"
export OB_FRONT_PORT="${OB_FRONT_PORT:-3001}"
export OB_PING_TIMEOUT="${OB_PING_TIMEOUT:-6}"
export OB_PING_DELAY="${OB_PING_DELAY:-800}"

# Vetor de versao: sempre le o VERSION file (SemVer MAJOR.MINOR.PATCH)
export OB_VERSION_FILE="${OB_HOME}/VERSION"
if [ -f "$OB_VERSION_FILE" ]; then
    export OB_VERSION="$(tr -d '[:space:]' < "$OB_VERSION_FILE")"
else
    export OB_VERSION="0.0.0"
fi


json_number() {
    local value="${1:-0}"
    value="${value//,/.}"
    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "$value"
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# Inicializacao: cria arquivos JSON vazios se nao existirem
# ---------------------------------------------------------------------------
ob_config_init() {
    mkdir -p "$OB_CONFIG_DIR" "$OB_APPS_DIR" 2>/dev/null || true
    [ -f "$OB_APPS_FILE" ]    || echo '{}' > "$OB_APPS_FILE" 2>/dev/null || true
    [ -f "$OB_USERS_FILE" ]   || echo '{}' > "$OB_USERS_FILE" 2>/dev/null || true
    [ -f "$OB_DOMAINS_FILE" ] || echo '{}' > "$OB_DOMAINS_FILE" 2>/dev/null || true
    [ -f "$OB_PLANS_FILE" ]   || echo '{}' > "$OB_PLANS_FILE" 2>/dev/null || true
    [ -f "$OB_NODES_FILE" ]   || echo '[]' > "$OB_NODES_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Apps (sites, bots, APIs, workers)
# ---------------------------------------------------------------------------
ob_apps_add() {
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

ob_apps_count() {
    jq 'length' "$OB_APPS_FILE" 2>/dev/null || echo 0
}

ob_apps_count_by_type() {
    local type="$1"
    jq -r --arg t "$type" '[to_entries[] | select(.value.type == $t)] | length' "$OB_APPS_FILE" 2>/dev/null || echo 0
}

ob_apps_count_by_owner() {
    local owner="$1"
    jq -r --arg o "$owner" '[to_entries[] | select(.value.owner == $o)] | length' "$OB_APPS_FILE" 2>/dev/null || echo 0
}

ob_apps_list_by_type() {
    local type="$1"
    jq -r --arg t "$type" 'to_entries[] | select(.value.type == $t) | .key' "$OB_APPS_FILE" 2>/dev/null
}

ob_apps_list_by_owner() {
    local owner="$1"
    jq -r --arg o "$owner" 'to_entries[] | select(.value.owner == $o) | .key' "$OB_APPS_FILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Usuarios (contas do hadix.site)
# Schema: { "username": { "name", "email", "discord_id", "plan", "plan_status",
#           "bots_limit", "sites_limit", "bots_used", "sites_used",
#           "created", "last_login", "status" } }
# ---------------------------------------------------------------------------
ob_users_count() {
    jq 'length' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_active() {
    jq '[to_entries[] | select(.value.status == "active")] | length' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_expired() {
    jq '[to_entries[] | select(.value.plan_status == "expired")] | length' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_expiring() {
    local days="${1:-7}"
    local cutoff
    cutoff="$(date -d "+${days} days" -Iseconds 2>/dev/null || date -v+"${days}"d -Iseconds 2>/dev/null || echo "")"
    if [ -n "$cutoff" ]; then
        jq --arg d "$cutoff" '[to_entries[] | select(.value.plan_status == "active" and .value.plan_expires != null and .value.plan_expires < $d)] | length' "$OB_USERS_FILE" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

ob_users_total_bots_used() {
    jq '[to_entries[] | .value.bots_used // 0] | add // 0' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_total_sites_used() {
    jq '[to_entries[] | .value.sites_used // 0] | add // 0' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_total_bots_limit() {
    jq '[to_entries[] | .value.bots_limit // 0] | add // 0' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_total_sites_limit() {
    jq '[to_entries[] | .value.sites_limit // 0] | add // 0' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_users_by_plan() {
    local plan="$1"
    jq -r --arg p "$plan" '[to_entries[] | select(.value.plan == $p)] | length' "$OB_USERS_FILE" 2>/dev/null || echo 0
}

ob_user_add() {
    local username="$1" name="$2" email="$3" discord_id="$4" plan="$5"
    local bots_limit="$6" sites_limit="$7"
    bots_limit="$(json_number "$bots_limit")"
    sites_limit="$(json_number "$sites_limit")"
    local tmp
    tmp="$(mktemp)"
    jq --arg u "$username" --arg n "$name" --arg e "$email" --arg d "$discord_id" \
       --arg p "$plan" --arg bl "$bots_limit" --arg sl "$sites_limit" \
       --arg created "$(date -Iseconds)" \
       '.[$u] = {name: $n, email: $e, discord_id: $d, plan: $p, plan_status: "active", bots_limit: ($bl|tonumber), sites_limit: ($sl|tonumber), bots_used: 0, sites_used: 0, created: $created, last_login: null, status: "active"}' \
       "$OB_USERS_FILE" > "$tmp" && mv "$tmp" "$OB_USERS_FILE"
}

ob_user_get() {
    local username="$1"
    jq -r --arg u "$username" '.[$u] // empty' "$OB_USERS_FILE"
}

ob_user_set() {
    local username="$1" field="$2" value="$3"
    local tmp
    tmp="$(mktemp)"
    jq --arg u "$username" --arg f "$field" --arg v "$value" \
       '.[$u][$f] = $v' "$OB_USERS_FILE" > "$tmp" && mv "$tmp" "$OB_USERS_FILE"
}

# ---------------------------------------------------------------------------
# Planos (assinaturas do hadix.site)
# Schema: { "plan_id": { "name", "price", "currency", "interval",
#           "bots_limit", "sites_limit", "features", "active_users" } }
# ---------------------------------------------------------------------------
ob_plans_count() {
    jq 'length' "$OB_PLANS_FILE" 2>/dev/null || echo 0
}

ob_plans_list() {
    jq -r 'keys[]' "$OB_PLANS_FILE" 2>/dev/null
}

ob_plan_get() {
    local plan_id="$1"
    jq -r --arg p "$plan_id" '.[$p] // empty' "$OB_PLANS_FILE"
}

ob_plan_add() {
    local plan_id="$1" name="$2" price="$3" currency="$4" interval="$5"
    local bots_limit="$6" sites_limit="$7" features="$8"
    price="$(json_number "$price")"
    bots_limit="$(json_number "$bots_limit")"
    sites_limit="$(json_number "$sites_limit")"
    local tmp
    tmp="$(mktemp)"
    jq --arg id "$plan_id" --arg n "$name" --arg pr "$price" --arg c "$currency" \
       --arg i "$interval" --arg bl "$bots_limit" --arg sl "$sites_limit" --arg f "$features" \
       '.[$id] = {name: $n, price: ($pr|tonumber), currency: $c, interval: $i, bots_limit: ($bl|tonumber), sites_limit: ($sl|tonumber), features: $f, active_users: 0}' \
       "$OB_PLANS_FILE" > "$tmp" && mv "$tmp" "$OB_PLANS_FILE"
}

ob_plan_remove() {
    local plan_id="$1"
    local tmp
    tmp="$(mktemp)"
    jq --arg p "$plan_id" 'del(.[$p])' "$OB_PLANS_FILE" > "$tmp" && mv "$tmp" "$OB_PLANS_FILE"
}

ob_plans_total_revenue() {
    jq '[to_entries[] | .value.price * .value.active_users] | add // 0' "$OB_PLANS_FILE" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# Nodes (multi-VPS)
# Schema: [ { "name", "ip", "region", "os", "status", "ram_total",
#            "disk_total", "cpu_cores", "apps_count", "last_ping", "role" } ]
# ---------------------------------------------------------------------------
ob_nodes_count() {
    jq 'length' "$OB_NODES_FILE" 2>/dev/null || echo 0
}

ob_nodes_online() {
    jq '[.[] | select(.status == "online")] | length' "$OB_NODES_FILE" 2>/dev/null || echo 0
}

ob_nodes_offline() {
    jq '[.[] | select(.status == "offline")] | length' "$OB_NODES_FILE" 2>/dev/null || echo 0
}

ob_nodes_list() {
    jq -r '.[] | .name' "$OB_NODES_FILE" 2>/dev/null
}

ob_node_add() {
    local name="$1" ip="$2" region="$3" os="$4" role="$5"
    local tmp
    tmp="$(mktemp)"
    jq --arg n "$name" --arg ip "$ip" --arg r "$region" --arg o "$os" --arg rl "$role" \
       --arg created "$(date -Iseconds)" \
       '. += [{name: $n, ip: $ip, region: $r, os: $o, status: "pending", ram_total: "0", disk_total: "0", cpu_cores: 0, apps_count: 0, last_ping: null, role: $rl, created: $created}]' \
       "$OB_NODES_FILE" > "$tmp" && mv "$tmp" "$OB_NODES_FILE"
}

ob_node_remove() {
    local name="$1"
    local tmp
    tmp="$(mktemp)"
    jq --arg n "$name" '[.[] | select(.name != $n)]' "$OB_NODES_FILE" > "$tmp" && mv "$tmp" "$OB_NODES_FILE"
}

ob_node_set() {
    local name="$1" field="$2" value="$3"
    local tmp
    tmp="$(mktemp)"
    jq --arg n "$name" --arg f "$field" --arg v "$value" \
       '[.[] | if .name == $n then .[$f] = $v else . end]' \
       "$OB_NODES_FILE" > "$tmp" && mv "$tmp" "$OB_NODES_FILE"
}

ob_node_get() {
    local name="$1"
    jq -r --arg n "$name" '.[] | select(.name == $n)' "$OB_NODES_FILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Domínios
# ---------------------------------------------------------------------------
ob_domains_list() {
    jq -r 'keys[]' "$OB_DOMAINS_FILE" 2>/dev/null
}

ob_domains_count() {
    jq 'length' "$OB_DOMAINS_FILE" 2>/dev/null || echo 0
}
