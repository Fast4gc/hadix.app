#!/usr/bin/env bash
# version.sh — sistema de versao do Hadix.app (SemVer)
# Fonte unica da versao: ${OB_HOME}/VERSION (arquivo com MAJOR.MINOR.PATCH)

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
VERSION_FILE="${OB_HOME}/VERSION"

# Le a versao corrente do arquivo VERSION
ob_version() {
    if [ -f "$VERSION_FILE" ]; then
        tr -d '[:space:]' < "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Compara duas versoes SemVer. Imprime 0 (iguais), 1 (a>b), -1 (a<b)
ob_version_compare() {
    local a="$1" b="$2"
    local am bn
    am="$(printf '%s\n' "$a" | tr -d '[:space:]' | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')"
    bn="$(printf '%s\n' "$b" | tr -d '[:space:]' | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')"
    if [ "$am" -gt "$bn" ]; then echo 1
    elif [ "$am" -lt "$bn" ]; then echo -1
    else echo 0; fi
}

# Verifica se ha versao nova no repositorio. Imprime a nova ou vazio.
ob_version_latest() {
    local latest
    latest="$(curl -fsSL --max-time 10 "${OB_RAW_URL}/VERSION" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$latest" ] && echo "$latest"
}

# Exibe "X.Y.Z" se existir atualizacao, senao nada.
ob_version_check() {
    local cur latest
    cur="$(ob_version)"
    latest="$(ob_version_latest)"
    [ -z "$latest" ] && return 0
    if [ "$(ob_version_compare "$latest" "$cur")" -gt 0 ]; then
        echo "$latest"
    fi
}
