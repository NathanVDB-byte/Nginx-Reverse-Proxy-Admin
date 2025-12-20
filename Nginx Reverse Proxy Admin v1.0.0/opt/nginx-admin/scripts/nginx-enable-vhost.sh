#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Domain required" >&2
  exit 1
fi

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"

CONF_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"
LINK_FILE="${SITES_ENABLED}/${DOMAIN}.conf"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "Config not found: $CONF_FILE" >&2
  exit 1
fi

ln -sf "$CONF_FILE" "$LINK_FILE"

if ! sudo /usr/sbin/nginx -t; then
  echo "nginx -t failed" >&2
  rm -f "$LINK_FILE"
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Enabled ${DOMAIN}"
exit 0
