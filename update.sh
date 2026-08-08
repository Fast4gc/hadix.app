#!/usr/bin/env bash
# update.sh — atualiza o Hadix.app sem reinstalar
set -uo pipefail

OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"
source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"
source "${OB_HOME}/bootstrap/config.sh"

require_root

log_title "Atualizador Hadix.app"
log_step "Atualizando arquivos do painel em ${OB_HOME}"

if [ -d "$OB_HOME/.git" ]; then
    if git -C "$OB_HOME" fetch --all --prune && git -C "$OB_HOME" pull --ff-only; then
        log_ok "Repositorio atualizado via git"
    else
        log_warn "Nao foi possivel atualizar via git. Tentando pacote ZIP do branch main..."
        tmp_dir="$(mktemp -d)"
        if curl -fsSL "https://github.com/Fast4gc/hadix.app/archive/refs/heads/main.zip" -o "$tmp_dir/hadix.zip" 2>/dev/null; then
            unzip -q "$tmp_dir/hadix.zip" -d "$tmp_dir"
            if command_exists rsync; then
                rsync -a --delete --exclude config/ "$tmp_dir/hadix.app-main/" "$OB_HOME/"
            else
                cp -r "$tmp_dir/hadix.app-main/"* "$OB_HOME/"
            fi
            log_ok "Arquivos atualizados via ZIP"
        else
            log_error "Falha ao baixar atualizacao. Verifique a internet e tente novamente."
        fi
        rm -rf "$tmp_dir"
    fi
else
    log_warn "Instalacao nao e um repositorio git. Atualizando por ZIP sem apagar config/."
    tmp_dir="$(mktemp -d)"
    if curl -fsSL "https://github.com/Fast4gc/hadix.app/archive/refs/heads/main.zip" -o "$tmp_dir/hadix.zip"; then
        unzip -q "$tmp_dir/hadix.zip" -d "$tmp_dir"
        if command_exists rsync; then
            rsync -a --delete --exclude config/ "$tmp_dir/hadix.app-main/" "$OB_HOME/"
        else
            cp -r "$tmp_dir/hadix.app-main/"* "$OB_HOME/"
        fi
        log_ok "Arquivos atualizados via ZIP"
    else
        log_error "Falha ao baixar atualizacao. Verifique a internet e tente novamente."
    fi
    rm -rf "$tmp_dir"
fi

chmod +x "$OB_HOME"/*.sh "$OB_HOME"/bootstrap/*.sh "$OB_HOME"/installers/*.sh "$OB_HOME"/commands/*.sh 2>/dev/null

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
