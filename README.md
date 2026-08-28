# Hadix.app

Painel completo de bootstrap, monitoramento e gerenciamento de VPS (Oracle Cloud, ou qualquer VPS
Ubuntu/Debian/RHEL/Oracle Linux) via linha de comando: instala a stack básica
(Docker, Nginx, Node, Postgres, Redis, firewall, SSL...) e cria/gerencia apps
(APIs, bots, sites, workers) prontos para produção com **nginx + pm2/docker +
SSL automático**.

## Instalação (uma linha)

```
curl -fsSLO https://raw.githubusercontent.com/Fast4gc/hadix.app/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

ou com wget:

```
wget https://raw.githubusercontent.com/Fast4gc/hadix.app/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

Isso instala o projeto em `/opt/oracle-bootstrap`, cria os comandos globais
`bootstrap` e `hadix` e abre o painel interativo (opcional). Sem argumentos, o comando abre o painel por padrão.

## Uso

```bash
hadix                              # painel interativo Hadix.app
bootstrap                          # tambem abre o painel por padrao
bootstrap install docker           # instala um componente específico
bootstrap create nextjs meu-site   # cria projeto a partir de um template
bootstrap create-api minha-api     # API Node/Express + nginx + pm2
bootstrap create-bot meu-bot       # Bot Discord/Telegram/Python + pm2
bootstrap create-site meu-site     # Site estático + nginx
bootstrap create-worker fila-jobs  # Worker em background + pm2
bootstrap list                     # lista apps gerenciados
bootstrap status [app] [--json]    # status de apps (tipo, processo, porta, dominio)
bootstrap production               # configura a VPS p/ hospedar bots/sites (Discloud/Squarecloud)
bootstrap production --check       # status da stack de hosting (sem alterar)
bootstrap production --dry-run     # simula sem alterar nada
bootstrap vps /var/www             # navegador da VPS: arquivos, deploy, nginx e pm2
bootstrap dashboard                # painel central: contas, planos, bots, nodes
bootstrap dashboard users          # lista contas/usuarios do hadix.site
bootstrap dashboard plans          # lista planos de assinatura e receita
bootstrap dashboard nodes          # lista/adiciona/remove VPS (multi-VPS)
bootstrap dashboard apps           # lista apps e abre ações rápidas
bootstrap monitor                  # resumo de CPU, memoria, disco, servicos e apps
bootstrap monitor --watch          # monitor ao vivo; Ctrl+C volta/encerra
bootstrap front                    # painel do front (prod/dev/ping) — hadix.site
bootstrap front status             # ping e status da VPS ate https://hadix.site
bootstrap front prod               # exporta o front em producao (build + nginx/pm2)
bootstrap front dev                # roda o front em modo desenvolvimento
bootstrap logs <nome>              # logs (pm2/docker/nginx)
bootstrap start <nome>             # sobe/provisiona um app registrado (pm2 + deps)
bootstrap restart <nome>           # reinicia
bootstrap backup [nome]            # backup (todos, se omitido)
bootstrap restore <arquivo.tar.gz> # restaura backup
bootstrap ssl <dominio>            # emite/renova HTTPS via certbot
bootstrap remove <nome>            # remove app
bootstrap version                  # exibe a versao instalada
bootstrap update                   # atualiza o Hadix.app sem reinstalar
bootstrap uninstall                # desinstala o oracle-bootstrap
```

## Painel Hadix.app

O painel inclui opções numeradas para instalar componentes, criar projetos, navegar pelos arquivos da VPS, gerenciar apps, listar apps, monitorar a VPS, exportar o front (`hadix.site`) em produção ou desenvolvimento, atualizar sem reinstalar e abrir ajuda. O cabeçalho do painel carrega um ping automático até `https://hadix.site` e mostra uma bolha de status: **VPS OK** (latência normal), **VPS COM DELAY** (acima de 800ms) ou **VPS OFFLINE**. Nas telas interativas, use `0` para voltar/sair; no monitor ao vivo, `Ctrl+C` retorna ao fluxo.

O menu principal é organizado em **seções** (HOSTING, CRIAR, GERENCIAR, SISTEMA) e já mostra uma linha de status de hosting (se a stack está pronta, nº de apps e ping do front) para você ver de relance se a VPS está "em produção".

## Produzindo a VPS como plataforma de hosting

`bootstrap production` transforma a VPS em uma plataforma de hospedagem de **bots e sites** no estilo Discloud/Squarecloud. É idempotente — pode rodar quantas vezes quiser sem quebrar nada:

- **Stack completa**: nginx, Node, pnpm, pm2, Docker, Redis, Postgres, ufw (22/80/443), fail2ban, Certbot (SSL) e Netdata (monitor).
- **Estrutura de hosting**: `/var/www`, `/var/hadix/{domains,ssl,logs,backups,envs}`.
- **Usuário `hadix`** (não-root) com pm2 próprio + boot persistente via systemd (`pm2-hadix.service`) — mais seguro para rodar apps.
- **Nginx presets** de proxy/static/websocket para bots e sites.
- **Manifesto `hadix.toml`** por app (padrão Discloud/Squarecloud: `type`, `start`, `port`, `domain`, `pm2`, `[limits]`, `[env]`) gerado automaticamente para apps existentes sem sobrescrever os já criados.
- **`/var/hadix/host.json`**: manifesto da VPS (recursos + IP + contagem de apps) consumível pelo front `hadix.site`.

```bash
bootstrap production              # configurar (idempotente)
bootstrap production --check      # ver o que ja esta instalado/ativo
bootstrap production --dry-run    # simular sem alterar
bootstrap production --reset      # refazer configs mantendo os apps
bootstrap status                  # tabela de apps (tipo, processo, porta, dominio)
bootstrap status meu-app          # detalhe do app + hadix.toml
bootstrap status --json           # saida JSON p/ o frontend
```

## Sobe um app (bootstrap start)

O comando `bootstrap start <nome>` garante que um app registrado em `apps.json`
fique **online**: cria a pasta `/var/www/<nome>` se faltar, escreve arquivos
starter (package.json, main, .env) quando o código ainda não foi enviado, instala
as dependências e inicia via pm2 com o mesmo nome do app. Isso faz com que
`bootstrap logs <nome>` e `bootstrap status <nome>` passem a resolver o processo.

```bash
bootstrap start meu-bot              # cria/instala/inicia (idempotente)
bootstrap start meu-bot --no-install # nao roda npm install
bootstrap start meu-bot --skip-files # nao cria starter em pasta vazia
```

O `vps-api` (server.js) chama `hadix start <nome>` automaticamente quando o
front `hadix.site` registra um app via `/config/apps/add`, então bots/sites
publicados passam a subir sozinhos.

## Dashboard Central (bootstrap dashboard)

O painel central responde às perguntas do dia a dia de um host:

- **Contas** — quantas contas existem no hadix.site, quantas estão ativas, expiradas ou vencendo (7 dias), e quantas por plano.
- **Planos** — planos cadastrados, preço, limites de bots/sites e receita estimada mensal.
- **Bots e sites hospedados** — total de apps, separados por tipo (bot/site/api/worker), uso vs. limite contratado e top apps.
- **Multi-VPS** — quantas VPS (nodes) estão registradas, online/offline, recursos (RAM/CPU/disco) e apps por node.
- **Front** — ping/latência até `https://hadix.site`.

O dashboard lê de `config/`:

| Arquivo | Conteúdo |
|---|---|
| `apps.json` | apps hospedados (tipo, porta, domínio, owner) |
| `users.json` | contas do hadix.site (plano, limites, uso) |
| `plans.json` | planos de assinatura (preço, limites, usuários ativos) |
| `nodes.json` | nodes/VPS da rede multi-VPS |

Os dados podem ser populados pela API do hadix.site (no front) ou editados diretamente nos JSONs.


## Navegador da VPS e operações de hospedagem

O comando `bootstrap vps [diretorio]` abre um painel de arquivos para administrar a VPS sem sair do Hadix.app. Ele foi pensado para operações essenciais de uma plataforma de hospedagem no estilo Squarecloud:

- navegar por diretórios, abrir arquivos e editar configurações;
- criar `.env` padrão para novos apps;
- executar `git pull`, instalar dependências e rodar build;
- registrar o projeto atual no PM2;
- publicar domínio no Nginx como proxy ou site estático;
- ajustar permissões do diretório de app;
- usar fallback ASCII quando o terminal não renderiza UTF-8, evitando caracteres quebrados.

## Front (hadix.site)

O Hadix.app exporta o front oficial para `https://hadix.site`, em produção ou desenvolvimento:

```bash
bootstrap front            # painel interativo do front (status + menu)
bootstrap front status     # ping/latência até hadix.site (VPS OK / DELAY / OFFLINE)
bootstrap front prod       # clona/atualiza, instala deps, build e publica (nginx ou pm2)
bootstrap front dev        # sobe dev server na porta OB_FRONT_PORT (padrão 3001)
bootstrap front stop       # para front prod e dev
bootstrap front log        # logs do front via pm2
bootstrap front clean      # remove node_modules/caches/builds para liberar disco
```

Configuração (via `bootstrap/config.sh` ou variáveis de ambiente):

| Variável | Padrão | Descrição |
|---|---|---|
| `OB_FRONT_URL` | `https://hadix.site` | URL pública do front |
| `OB_FRONT_DIR` | `/var/www/hadix-front` | diretório do código no VPS |
| `OB_FRONT_REPO` | `https://github.com/Fast4gc/hadix-front.git` | repositório do front |
| `OB_FRONT_PORT` | `3001` | porta do dev server |
| `OB_PING_TIMEOUT` | `6` | timeout do ping em segundos |
| `OB_PING_DELAY` | `800` | limite de latência (ms) para considerar delay |

Para VPS com pouco disco, use `bootstrap front clean` após deploys/testes locais para remover `node_modules`, caches e builds antigos do front.

O ping também aparece no cabeçalho do painel principal e no `bootstrap monitor`.

## O diferencial: templates prontos

```bash
bootstrap create nextjs   meu-site      # Next.js (App Router, TS, Tailwind)
bootstrap create vite     meu-front     # Vite (react-ts/react/vue/svelte/vanilla)
bootstrap create discord  meu-bot       # Bot Discord (discord.js)
bootstrap create express  minha-api     # API Express
bootstrap create nest     minha-api     # API NestJS
bootstrap create fastify  minha-api     # API Fastify
bootstrap create hono     minha-api     # API Hono (Node)
bootstrap create python   minha-api     # API FastAPI + uvicorn
bootstrap create go       minha-api     # API Go (net/http)
```

Cada template:
1. Instala as dependências necessárias (Node, pnpm, Python, Go...) se faltarem.
2. Faz o scaffold do projeto em `/var/www/<nome>`.
3. Sobe o processo com **pm2** (ou build estático, no caso de Vite).
4. Se você informar um domínio, configura o **Nginx** automaticamente
   (proxy reverso ou arquivos estáticos).
5. Registra o app em `config/apps.json` para aparecer em `bootstrap list`,
   `logs`, `restart`, `backup` e `remove`.
6. Sugere rodar `bootstrap ssl <dominio>` para ativar HTTPS via Let's Encrypt.

## Estrutura

```
hadix.app/
├── install.sh / update.sh / uninstall.sh
├── bootstrap/       # núcleo: dispatcher, menu, cores, logger, utils, config
├── installers/       # docker, nginx, node, pnpm, bun, postgres, redis,
│                      # fail2ban, ufw, cloudflare, ssl, pm2, github,
│                      # certbot, monitoring
├── templates/
│   ├── nginx/        # api.conf, static.conf, websocket.conf
│   ├── docker/        # compose.yml
│   ├── github/        # deploy.yml (GitHub Actions -> deploy via SSH)
│   └── systemd/       # app.service (alternativa ao pm2)
├── commands/          # create-api/bot/site/worker, create.sh (templates),
│                      # backup, restore, logs, restart, ssl, remove,
│                      # dashboard (painel central), front (hadix.site)
├── dashboard/          # (removido) painel gráfico não é mais usado
└── config/             # apps.json, users.json, domains.json, plans.json,
                       # nodes.json (estado do sistema)
```

## Requisitos

- Uma VPS com Ubuntu/Debian ou RHEL/Oracle Linux, acesso root.
- Acesso à internet de saída (para baixar pacotes, Node, templates via `npx`).

## Segurança

- Rode `bootstrap install ufw` (ou `firewalld`) e `bootstrap install fail2ban`
  logo após a instalação.
- Tokens/segredos (Cloudflare API, DBs) ficam em arquivos `600` fora do
  controle de versão (`/etc/hadix.app/*.env`, `.env` de cada app).
- `bootstrap ssl <dominio>` configura renovação automática via cron.

## Versões

A versão fica no arquivo `VERSION` da raiz do repositório (SemVer, ex: `1.6.0`)
e é a fonte única usada pelo painel, `bootstrap version`, `bootstrap --help`
e pelo aviso de atualização. O `update.sh` baixa o `VERSION` novo do
repositório, compara com a instalada e mostra o diff. Para atualizar o branch:
edite o arquivo `VERSION`, faça commit e `bootstrap update` na VPS.

## Licença

Use e adapte livremente para seus próprios servidores.
