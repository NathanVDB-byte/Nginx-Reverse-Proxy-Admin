#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
ALIASES_CSV="${2:-}"
BACKEND_HOST="${3:-}"
BACKEND_PORT="${4:-80}"
EXTRA_HEADERS_B64="${5:-}"

if [[ -z "$DOMAIN" || -z "$BACKEND_HOST" || -z "$BACKEND_PORT" ]]; then
  echo "Missing parameters" >&2
  echo "Usage: $0 <domain> <aliases_csv> <backend_host> <backend_port> <extra_headers_b64>" >&2
  exit 1
fi

SITES_AVAILABLE="/etc/nginx/sites-available"
CONF_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"

IFS=',' read -r -a ALIASES <<< "$ALIASES_CSV"
SERVER_NAMES="$DOMAIN"
for a in "${ALIASES[@]}"; do
  [[ -n "$a" ]] && SERVER_NAMES+=" $a"
done

EXTRA_HEADERS="$(printf '%s' "$EXTRA_HEADERS_B64" | base64 -d || true)"

{
  echo "server {"
  echo "    listen 80;"
  echo "    server_name ${SERVER_NAMES};"
  echo ""
  echo "    location / {"
  echo "        proxy_pass http://${BACKEND_HOST}:${BACKEND_PORT};"
  echo "        proxy_set_header Host \$host;"
  echo "        proxy_set_header X-Real-IP \$remote_addr;"
  echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
  echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
  if [[ -n "$EXTRA_HEADERS" ]]; then
    echo "${EXTRA_HEADERS}"
  fi
  echo "    }"
  echo "}"
} > "$CONF_FILE"

if ! sudo /usr/sbin/nginx -t; then
  echo "sudo nginx -t failed after create" >&2
  rm -f "$CONF_FILE"
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Created vhost $DOMAIN and reloaded Nginx"
exit 0
