#!/usr/bin/env bash
# logger.sh — logging padronizado com saída em tela + arquivo

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

log_info()    { _log "INFO"  "$*"; echo -e "${BLUE}i${NC}  $*"; }
log_ok()      { _log "OK"    "$*"; echo -e "${GREEN}OK${NC}  $*"; }
log_warn()    { _log "WARN"  "$*"; echo -e "${YELLOW}!${NC}  $*"; }
log_error()   { _log "ERROR" "$*"; echo -e "${RED}x${NC}  $*" >&2; }
log_step()    { _log "STEP"  "$*"; echo -e "\n${CYAN}${BOLD}==> $*${NC}"; }
log_title()   {
    echo -e "\n${MAGENTA}${BOLD}=========================================${NC}"
    echo -e "${MAGENTA}${BOLD}  $*${NC}"
    echo -e "${MAGENTA}${BOLD}=========================================${NC}\n"
}
