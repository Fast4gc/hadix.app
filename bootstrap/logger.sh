#!/usr/bin/env bash
# logger.sh — logging padronizado com saída em tela + arquivo
# Fonte: bootstrap/colors.sh (deve ser carregado antes)

LOG_DIR="/var/log/oracle-bootstrap"
LOG_FILE="${LOG_DIR}/bootstrap.log"

_ensure_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp/oracle-bootstrap"
        mkdir -p "$LOG_DIR" 2>/dev/null
        LOG_FILE="${LOG_DIR}/bootstrap.log"
    fi
}
_ensure_log_dir

_log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null
}

log_info()    { _log "INFO"  "$*"; echo -e "${SKY}${INFO}${NC}  $*"; }
log_ok()      { _log "OK"    "$*"; echo -e "${GREEN}${TICK}${NC}  $*"; }
log_warn()    { _log "WARN"  "$*"; echo -e "${YELLOW}${WARN}${NC}  $*"; }
log_error()   { _log "ERROR" "$*"; echo -e "${RED}${CROSS}${NC}  $*" >&2; }
log_step()    { _log "STEP"  "$*"; echo -e "\n${CYAN}${BOLD}==> $*${NC}"; }
log_title()   {
    local w
    w="$(tput cols 2>/dev/null || echo 70)"
    [ "$w" -gt 70 ] && w=70
    echo ""
    echo -e "${MAGENTA}${BOLD}${BOX_TL}$(repeat_char $((w - 2)) "$THICK_T")${BOX_TR}${NC}"
    echo -e "${MAGENTA}${BOLD}${THICK_V}${NC} ${BOLD}${*}${NC} $(repeat_char $((w - ${#*} - 5)) ' ')${MAGENTA}${THICK_V}${NC}"
    echo -e "${MAGENTA}${BOLD}${BOX_BL}$(repeat_char $((w - 2)) "$THICK_T")${BOX_BR}${NC}"
    echo ""
}

repeat_char() {
    local count="$1" ch="$2"
    printf '%*s' "$count" '' | tr ' ' "$ch"
}