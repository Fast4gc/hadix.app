#!/usr/bin/env bash
# update.sh — atualiza o Hadix.app sem reinstalar
# Robusto: nunca reporta sucesso falso, remove arquivos obsoletos e
# preserva config/ (estado runtime da VPS: apps/usuarios/planos/nodes).
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"
source "${OB_HOME}/bootstrap/version.sh"

require_root

OLD_VERSION="$(ob_version)"
OLD_HEAD=""
[ -d "$OB_HOME/.git" ] && OLD_HEAD="$(git -C "$OB_HOME" rev-parse HEAD 2>/dev/null || true)"

log_title "Atualizador Hadix.app"
log_step "Atualizando arquivos do painel em ${OB_HOME}"
log_info "Versao atual: ${BOLD}${OLD_VERSION}${NC}"

# ---------------------------------------------------------------- via git
git_update() {
    local branch remote
    branch="$(git -C "$OB_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    remote="$(git -C "$OB_HOME" config --get remote.origin.url || echo origin)"

    # remove config/ do versionamento mantendo os arquivos locais (migracao)
    if git -C "$OB_HOME" ls-files config/ | grep -q .; then
        echo "  ${CYAN}${DOT}${NC} config/ ainda versionado — removendo do git (arquivos locais preservados)"
        git -C "$OB_HOME" rm -r --cached config/ >/dev/null 2>&1
        git -C "$OB_HOME" commit -m "chore: untrack config (runtime state)" >/dev/null 2>&1 || true
    fi

    # garante que a arvore fique IGUAL ao remoto (sem estados parciais/cache)
    if ! git -C "$OB_HOME" fetch origin "$branch" 2>/dev/null; then
        return 1
    fi
    if git -C "$OB_HOME" rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        # descarta qualquer mudanca local em arquivos rastreados (config/ nao conta mais)
        git -C "$OB_HOME" reset --hard "origin/$branch" >/dev/null 2>&1
    else
        git -C "$OB_HOME" pull --ff-only >/dev/null 2>&1
    fi
    git -C "$OB_HOME" submodule update --init --recursive >/dev/null 2>&1 || true
    return 0
}

# ---------------------------------------------------------------- via ZIP
zip_update() {
    local tmp_dir src
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    if ! curl -fsSL "https://github.com/Fast4gc/hadix.app/archive/refs/heads/main.zip" -o "$tmp_dir/hadix.zip" 2>/dev/null; then
        log_error "Falha ao baixar atualizacao. Verifique a internet e tente novamente."
        return 1
    fi
    if ! unzip -q "$tmp_dir/hadix.zip" -d "$tmp_dir" 2>/dev/null; then
        log_error "Falha ao extrair o ZIP."
        return 1
    fi
    src="$(find "$tmp_dir" -maxdepth 1 -type d -name 'hadix.app-*' | head -1)"
    [ -z "$src" ] && { log_error "Estrutura do ZIP inesperada."; return 1; }

    if command_exists rsync; then
        rsync -a --delete --exclude config/ --exclude .git/ "$src/" "$OB_HOME/"
    else
        # fallback sem rsync: copia novos (incl. dotfiles) e remove obsoletos
        (cd "$src" && tar cf - --exclude=.git --exclude=config .) | (cd "$OB_HOME" && tar xf -)
        # remove arquivos que existiam mas nao estao mais no novo pacote (preserva config/)
        (cd "$OB_HOME" && find . -path ./.git -prune -o -path ./config -prune -o -type f -print) | while IFS= read -r f; do
            [ -f "$src/$f" ] || rm -f "$OB_HOME/$f"
        done
        # remove diretorios vazios obsoletos
        find "$OB_HOME" -type d -empty -not -path '*/.git*' -not -path '*/config*' -delete 2>/dev/null || true
    fi
    return 0
}

# ---------------------------------------------------------------- executar
UPDATED=false
if [ -d "$OB_HOME/.git" ]; then
    if git_update; then
        log_ok "Repositorio atualizado via git"
        UPDATED=true
    else
        log_warn "Falha via git. Tentando pacote ZIP do branch main..."
        if zip_update; then
            log_ok "Arquivos atualizados via ZIP"
            UPDATED=true
        else
            log_error "Atualizacao falhou (git e ZIP)."
            exit 1
        fi
    fi
else
    log_warn "Instalacao nao e um repositorio git. Atualizando por ZIP sem apagar config/."
    if zip_update; then
        log_ok "Arquivos atualizados via ZIP"
        UPDATED=true
    else
        log_error "Atualizacao falhou (ZIP)."
        exit 1
    fi
fi

# ---------------------------------------------------------------- pos-update
chmod +x "$OB_HOME"/*.sh "$OB_HOME"/bootstrap/*.sh "$OB_HOME"/installers/*.sh "$OB_HOME"/commands/*.sh 2>/dev/null

# garante config/ presente (cria vazio se faltar)
ob_config_init

NEW_VERSION="$(ob_version)"
NEW_HEAD=""
[ -d "$OB_HOME/.git" ] && NEW_HEAD="$(git -C "$OB_HOME" rev-parse HEAD 2>/dev/null || true)"

if [ "$NEW_VERSION" != "$OLD_VERSION" ]; then
    log_ok "Versao atualizada: ${BOLD}${OLD_VERSION}${NC} $RIGHT ${BOLD}${NEW_VERSION}${NC}"
elif [ -n "$OLD_HEAD" ] && [ -n "$NEW_HEAD" ] && [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
    log_ok "Codigo atualizado (versao mantida em ${BOLD}${NEW_VERSION}${NC})"
elif [ "$NEW_VERSION" = "$OLD_VERSION" ] && [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    log_ok "Voce ja esta atualizado (v${BOLD}${NEW_VERSION}${NC})."
fi

cat > /usr/local/bin/bootstrap << WRAPPER
#!/usr/bin/env bash
export OB_HOME="${OB_HOME}"
exec bash "${OB_HOME}/bootstrap/bootstrap.sh" "\$@"
WRAPPER
chmod +x /usr/local/bin/bootstrap
ln -sf /usr/local/bin/bootstrap /usr/local/bin/hadix
log_ok "Comandos globais prontos: bootstrap e hadix"

if confirm "Atualizar pacotes do sistema (apt/dnf/yum upgrade)?"; then
    log_step "Atualizando pacotes do sistema"
    pkg_update
fi

if command_exists pm2 && confirm "Atualizar daemon/apps gerenciados pelo PM2?"; then
    pm2 update
fi

log_ok "Atualizacao concluida. Use 'hadix' ou 'bootstrap' para abrir o painel."