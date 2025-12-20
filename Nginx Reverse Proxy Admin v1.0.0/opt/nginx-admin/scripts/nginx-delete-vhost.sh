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

if [[ -e "$LINK_FILE" ]]; then
  rm -f "$LINK_FILE"
fi

if [[ -e "$CONF_FILE" ]]; then
  rm -f "$CONF_FILE"
fi

if ! sudo /usr/sbin/nginx -t; then
  echo "nginx -t failed after delete" >&2
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Deleted ${DOMAIN}"
exit 0
