#!/usr/bin/env bash
# commands/create-bot.sh — cria um bot (Discord/Telegram) gerenciado via pm2
set -uo pipefail
OB_HOME="${OB_HOME:-/opt/oracle-bootstrap}"
source "${OB_HOME}/bootstrap/colors.sh"; source "${OB_HOME}/bootstrap/logger.sh"
source "${OB_HOME}/bootstrap/utils.sh"; source "${OB_HOME}/bootstrap/config.sh"
ob_config_init
require_root

NAME="${1:-$(ask "Nome do bot" "")}"
[ -z "$NAME" ] && { log_error "Nome obrigatorio."; exit 1; }
NAME="$(slugify "$NAME")"

echo "Tipo de bot:  1) Discord.js   2) Telegram (node-telegram-bot-api)   3) Python (discord.py)"
TYPE_CHOICE="$(ask "Escolha" "1")"

APP_PATH="${OB_APPS_DIR}/${NAME}"
[ -d "$APP_PATH" ] && { log_error "Diretorio ${APP_PATH} ja existe."; exit 1; }
mkdir -p "$APP_PATH"

TOKEN="$(ask "Cole o token do bot (pode deixar vazio e editar .env depois)" "")"
echo "TOKEN=${TOKEN}" > "${APP_PATH}/.env"

case "$TYPE_CHOICE" in
    2)
        cat > "${APP_PATH}/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "node-telegram-bot-api": "^0.66.0", "dotenv": "^16.4.5" } }
PKG
        cat > "${APP_PATH}/index.js" << 'JS'
require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api');
const bot = new TelegramBot(process.env.TOKEN, { polling: true });

bot.onText(/\/start/, (msg) => {
    bot.sendMessage(msg.chat.id, 'Bot online via oracle-bootstrap!');
});
JS
        command_exists node || bash "${OB_HOME}/installers/node.sh"
        (cd "$APP_PATH" && npm install --production --silent)
        command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
        (cd "$APP_PATH" && pm2 start index.js --name "$NAME")
        ;;
    3)
        cat > "${APP_PATH}/requirements.txt" << 'REQ'
discord.py
python-dotenv
REQ
        cat > "${APP_PATH}/bot.py" << 'PY'
import os
import discord
from dotenv import load_dotenv

load_dotenv()
intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

@client.event
async def on_ready():
    print(f'Bot conectado como {client.user}')

client.run(os.getenv('TOKEN'))
PY
        command_exists python3 || pkg_install python3 python3-pip
        (cd "$APP_PATH" && python3 -m venv venv && ./venv/bin/pip install -q -r requirements.txt)
        command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
        (cd "$APP_PATH" && pm2 start "venv/bin/python bot.py" --name "$NAME")
        ;;
    *)
        cat > "${APP_PATH}/package.json" << PKG
{ "name": "${NAME}", "version": "1.0.0", "private": true, "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "discord.js": "^14.15.3", "dotenv": "^16.4.5" } }
PKG
        cat > "${APP_PATH}/index.js" << 'JS'
require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');
const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent] });

client.once('ready', () => console.log(`Bot conectado como ${client.user.tag}`));
client.on('messageCreate', (msg) => {
    if (msg.content === '!ping') msg.reply('pong! (oracle-bootstrap)');
});

client.login(process.env.TOKEN);
JS
        command_exists node || bash "${OB_HOME}/installers/node.sh"
        (cd "$APP_PATH" && npm install --production --silent)
        command_exists pm2 || bash "${OB_HOME}/installers/pm2.sh"
        (cd "$APP_PATH" && pm2 start index.js --name "$NAME")
        ;;
esac

pm2 save
ob_apps_add "$NAME" "bot" "0" "" "$APP_PATH"
log_ok "Bot '${NAME}' criado e rodando (pm2 logs ${NAME})."
