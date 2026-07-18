# oracle-bootstrap

Toolkit de bootstrap e gerenciamento de VPS (Oracle Cloud, ou qualquer VPS
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

Isso instala o projeto em `/opt/oracle-bootstrap`, cria o comando global
`bootstrap` e abre o menu interativo (opcional).

## Uso

```bash
bootstrap                          # menu interativo
bootstrap install docker           # instala um componente específico
bootstrap create nextjs meu-site   # cria projeto a partir de um template
bootstrap create-api minha-api     # API Node/Express + nginx + pm2
bootstrap create-bot meu-bot       # Bot Discord/Telegram/Python + pm2
bootstrap create-site meu-site     # Site estático + nginx
bootstrap create-worker fila-jobs  # Worker em background + pm2
bootstrap list                     # lista apps gerenciados
bootstrap logs <nome>              # logs (pm2/docker/nginx)
bootstrap restart <nome>           # reinicia
bootstrap backup [nome]            # backup (todos, se omitido)
bootstrap restore <arquivo.tar.gz> # restaura backup
bootstrap ssl <dominio>            # emite/renova HTTPS via certbot
bootstrap remove <nome>            # remove app
bootstrap update                   # atualiza o oracle-bootstrap
bootstrap uninstall                # desinstala o oracle-bootstrap
```

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
oracle-bootstrap/
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
│                      # backup, restore, logs, restart, ssl, remove
├── dashboard/          # (reservado) api/web/database para um painel gráfico futuro
└── config/             # apps.json, users.json, domains.json (estado do sistema)
```

## Requisitos

- Uma VPS com Ubuntu/Debian ou RHEL/Oracle Linux, acesso root.
- Acesso à internet de saída (para baixar pacotes, Node, templates via `npx`).

## Segurança

- Rode `bootstrap install ufw` (ou `firewalld`) e `bootstrap install fail2ban`
  logo após a instalação.
- Tokens/segredos (Cloudflare API, DBs) ficam em arquivos `600` fora do
  controle de versão (`/etc/oracle-bootstrap/*.env`, `.env` de cada app).
- `bootstrap ssl <dominio>` configura renovação automática via cron.

## Licença

Use e adapte livremente para seus próprios servidores.
