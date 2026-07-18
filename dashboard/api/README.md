# dashboard/api

Reservado para uma futura API do painel web (ex: Express/Fastify) que expõe
os dados de `config/apps.json`, status de pm2/docker e ações (restart, logs,
backup) via HTTP, para consumo pelo `dashboard/web`.

Ainda não implementado nesta versão — os comandos `bootstrap create-*`,
`bootstrap list`, `bootstrap logs`, etc. já cobrem o essencial via CLI.
