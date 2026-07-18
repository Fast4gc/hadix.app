#!/usr/bin/env bash
# utils.sh — funcoes utilitarias compartilhadas

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_root() { [ "$(id -u)" -eq 0 ]; }

require_root() {
    if ! is_root; then
        log_error "Este script precisa ser executado como root (use sudo)."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID}"
    else
        echo "unknown"
    fi
}

detect_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${VERSION_ID}"
    else
        echo "unknown"
    fi
}

is_oracle_linux() {
    local os
    os="$(detect_os)"
    [ "$os" = "ol" ] || [ "$os" = "oracle" ]
}

pkg_install() {
    if command_exists dnf; then
        dnf install -y "$@"
    elif command_exists yum; then
        yum install -y "$@"
    elif command_exists apt-get; then
        apt-get update -qq && apt-get install -y "$@"
    else
        log_error "Nenhum gerenciador de pacotes suportado encontrado (dnf/yum/apt)."
        return 1
    fi
}

pkg_update() {
    if command_exists dnf; then
        dnf update -y
    elif command_exists yum; then
        yum update -y
    elif command_exists apt-get; then
        apt-get update -qq && apt-get upgrade -y
    fi
}

confirm() {
    local prompt="${1:-Confirmar?} [s/N]: "
    local answer
    read -r -p "$(echo -e "${YELLOW}${prompt}${NC}")" answer
    case "$answer" in
        [sSyY]*) return 0 ;;
        *) return 1 ;;
    esac
}

ask() {
    local prompt="$1"
    local default="$2"
    local answer
    if [ -n "$default" ]; then
        read -r -p "$(echo -e "${CYAN}${prompt} [${default}]: ${NC}")" answer
        echo "${answer:-$default}"
    else
        read -r -p "$(echo -e "${CYAN}${prompt}: ${NC}")" answer
        echo "$answer"
    fi
}

random_password() {
    local length="${1:-24}"
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

port_is_free() {
    local port="$1"
    ! ss -ltn "( sport = :$port )" 2>/dev/null | grep -q "$port"
}

next_free_port() {
    local start="${1:-3000}"
    local port="$start"
    while ! port_is_free "$port"; do
        port=$((port + 1))
    done
    echo "$port"
}

spinner_run() {
    local msg="$1"; shift
    echo -ne "${DIM}${msg}...${NC}"
    if "$@" >>"$LOG_FILE" 2>&1; then
        echo -e "\r${GREEN}OK${NC} ${msg}          "
    else
        echo -e "\r${RED}FALHOU${NC} ${msg} (veja $LOG_FILE)"
        return 1
    fi
}

get_public_ip() {
    curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "IP_NAO_DETECTADO"
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
