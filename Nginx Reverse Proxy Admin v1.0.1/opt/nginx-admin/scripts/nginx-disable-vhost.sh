#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Domain required" >&2
  exit 1
fi

SITES_ENABLED="/etc/nginx/sites-enabled"
LINK_FILE="${SITES_ENABLED}/${DOMAIN}.conf"

if [[ -L "$LINK_FILE" || -f "$LINK_FILE" ]]; then
  rm -f "$LINK_FILE"
fi

if ! sudo /usr/sbin/nginx -t; then
  echo "nginx -t failed" >&2
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Disabled ${DOMAIN}"
exit 0
