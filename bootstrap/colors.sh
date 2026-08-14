#!/usr/bin/env bash
# colors.sh — paleta de cores usada em todo o projeto
# Cores ANSI + suporte a 256/truecolor quando disponivel em /dev/tty.

NC='\033[0m'          # reset
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'

# Cores basicas 8/16 cores
BLACK='\033[0;30m'; RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
CYAN='\033[0;36m'; WHITE='\033[0;37m'

# Cores 256-color
GRAY='\033[38;5;244m'
LIGHT_GRAY='\033[38;5;250m'
DARK_GRAY='\033[38;5;235m'
ORANGE='\033[38;5;214m'
PINK='\033[38;5;211m'
PURPLE='\033[38;5;141m'
LIME='\033[38;5;154m'
TEAL='\033[38;5;79m'
NAVY='\033[38;5;33m'
SKY='\033[38;5;117m'
AQUA='\033[38;5;52m'
ROSE='\033[38;5;204m'
GOLD='\033[38;5;178m'
SILVER='\033[38;5;7m'

# Fundos
BG_BLACK='\033[48;5;234m'
BG_DARK='\033[48;5;236m'
BG_GRAY='\033[48;5;240m'
BG_RED='\033[48;5;196m'
BG_GREEN='\033[48;5;46m'
BG_YELLOW='\033[48;5;220m'
BG_BLUE='\033[48;5;27m'
BG_MAGENTA='\033[48;5;200m'
BG_CYAN='\033[48;5;51m'
BG_WHITE='\033[48;5;15m'

# Grossuras de linha usadas nos "quadros" do painel
THIN_T='─'; THIN_V='│'
THICK_T='═'; THICK_V='║'
CORNER_UL='┌'; CORNER_UR='┐'; CORNER_DL='└'; CORNER_DR='┘'
BOX_TL='╔'; BOX_TR='╗'; BOX_BL='╚'; BOX_BR='╝'

# Simbolos "icon" mais profissionais
TICK='✓'; CROSS='✗'; WARN='⚠'; INFO='ℹ'
RIGHT='→'; DOT='•'; SEARCH='⌕'; SPIN='⟳'

# Fallback ASCII quando o terminal/localidade nao renderiza UTF-8 corretamente.
# Evita saidas como "��������" em consoles web/SSH mal configurados.
_OB_LOCALE_CHECK="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
if ! printf '%s' "$_OB_LOCALE_CHECK" | tr '[:upper:]' '[:lower:]' | grep -Eq 'utf-?8'; then
    THIN_T='-'; THIN_V='|'
    THICK_T='='; THICK_V='|'
    CORNER_UL='+'; CORNER_UR='+'; CORNER_DL='+'; CORNER_DR='+'
    BOX_TL='+'; BOX_TR='+'; BOX_BL='+'; BOX_BR='+'
    TICK='OK'; CROSS='X'; WARN='!'; INFO='i'
    RIGHT='>'; DOT='-'; SEARCH='?'; SPIN='*'
fi

exit_codes_supported() {
    [ -t 0 ] && [ "${TERM:-}" != "dumb" ]
}

color_enabled() {
    exit_codes_supported && [ -z "${NO_COLOR:-}" ]
}

# Se cores estao desligadas, esvazia tudo (portabilidade)
if ! color_enabled; then
    NC=''; BOLD=''; DIM=''; ITALIC=''; UNDERLINE=''; BLINK=''; REVERSE=''
    BLACK=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''
    GRAY=''; LIGHT_GRAY=''; DARK_GRAY=''; ORANGE=''; PINK=''; PURPLE=''
    TEAL=''; NAVY=''; SKY=''; AQUA=''; ROSE=''; GOLD=''; SILVER=''
    BG_BLACK=''; BG_DARK=''; BG_GRAY=''; BG_RED=''; BG_GREEN=''; BG_YELLOW=''
    BG_BLUE=''; BG_MAGENTA=''; BG_CYAN=''; BG_WHITE=''
fi