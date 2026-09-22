#!/bin/bash
# Usage: send_discord.sh "<title>" "<message>" "<url>"
# Reads DISCORD_WEBHOOK_URL from .env in the same directory and posts a Discord embed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

TITLE="${1:-}"
MESSAGE="${2:-}"
URL="${3:-}"

if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
	echo "Usage: $0 <title> <message> [url]" >&2
	exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
	echo "Error: .env not found at $ENV_FILE" >&2
	exit 1
fi

DISCORD_WEBHOOK_URL="$(grep -m1 '^DISCORD_WEBHOOK_URL=' "$ENV_FILE" | cut -d '=' -f2-)"

if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
	echo "Error: DISCORD_WEBHOOK_URL is not set in .env" >&2
	exit 1
fi

PAYLOAD="$(TITLE="$TITLE" MESSAGE="$MESSAGE" URL="$URL" python3 -c '
import json, os
title = os.environ["TITLE"]
message = os.environ["MESSAGE"]
url = os.environ.get("URL", "")

embed = {"title": title, "description": message}
if url:
	embed["url"] = url

print(json.dumps({"embeds": [embed]}))
')"

HTTP_STATUS="$(curl -sS -o /dev/null -w "%{http_code}" \
	-H "Content-Type: application/json" \
	-X POST \
	-d "$PAYLOAD" \
	"$DISCORD_WEBHOOK_URL")"

if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
	echo "Discord notification sent (HTTP $HTTP_STATUS)"
else
	echo "Error: Discord notification failed (HTTP $HTTP_STATUS)" >&2
	exit 1
fi
