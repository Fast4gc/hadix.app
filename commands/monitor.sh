#!/usr/bin/env bash
# monitor.sh — painel de monitoramento da VPS Hadix.app
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"

bytes_to_human() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN { split("B KB MB GB TB", u); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf "%.1f %s", b, u[i] }'
}

service_state() {
    local svc="$1"
    if ! command_exists systemctl; then
        echo "indisponivel"
    elif systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "ativo"
    else
        echo "parado"
    fi
}

monitor_once() {
    local hostname uptime_info load cpu_line mem_line disk_line public_ip os_name kernel apps_count
    hostname="$(hostname 2>/dev/null || echo desconhecido)"
    uptime_info="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo indisponivel)"
    load="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || echo indisponivel)"
    cpu_line="$(awk -F: '/model name/{gsub(/^ /,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null || echo indisponivel)"
    mem_line="$(free -h 2>/dev/null | awk '/Mem:/ {print $3" / "$2" ("$7" livre)"}' || echo indisponivel)"
    disk_line="$(df -h / 2>/dev/null | awk 'NR==2 {print $3" / "$2" usado ("$5")"}' || echo indisponivel)"
    public_ip="$(get_public_ip 2>/dev/null || echo indisponivel)"
    os_name="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-desconhecido}" || echo desconhecido)"
    kernel="$(uname -r 2>/dev/null || echo desconhecido)"
    apps_count="$(jq 'length' "$OB_APPS_FILE" 2>/dev/null || echo 0)"

    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║${NC}              ${BOLD}Hadix.app — Monitor da VPS${NC}                 ${MAGENTA}${BOLD}║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}Atualizado em $(date '+%d/%m/%Y %H:%M:%S') — pressione Ctrl+C para voltar.${NC}\n"
    printf "${CYAN}%-18s${NC} %s\n" "Servidor:" "$hostname"
    printf "${CYAN}%-18s${NC} %s\n" "Sistema:" "$os_name"
    printf "${CYAN}%-18s${NC} %s\n" "Kernel:" "$kernel"
    printf "${CYAN}%-18s${NC} %s\n" "IP publico:" "$public_ip"
    printf "${CYAN}%-18s${NC} %s\n" "Uptime:" "$uptime_info"
    printf "${CYAN}%-18s${NC} %s\n" "Load average:" "$load"
    printf "${CYAN}%-18s${NC} %s\n" "CPU:" "$cpu_line"
    printf "${CYAN}%-18s${NC} %s\n" "Memoria:" "$mem_line"
    printf "${CYAN}%-18s${NC} %s\n" "Disco /:" "$disk_line"
    printf "${CYAN}%-18s${NC} %s\n" "Apps Hadix:" "$apps_count"
    echo ""
    echo -e "${BOLD}Servicos principais${NC}"
    for svc in nginx docker redis postgresql fail2ban ufw; do
        printf "  ${CYAN}%-12s${NC} %s\n" "$svc" "$(service_state "$svc")"
    done
    if command_exists pm2; then
        echo ""
        echo -e "${BOLD}PM2${NC}"
        pm2 jlist 2>/dev/null | jq -r '.[] | "  \(.name) — \(.pm2_env.status) — restarts: \(.pm2_env.restart_time)"' 2>/dev/null || pm2 status
    fi
}

case "${1:-}" in
    --watch|-w)
        trap 'echo; exit 0' INT
        while true; do clear; monitor_once; sleep "${2:-5}"; done
        ;;
    *)
        monitor_once
        ;;
esac
