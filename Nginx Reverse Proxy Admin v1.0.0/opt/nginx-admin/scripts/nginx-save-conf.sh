#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Domain required" >&2
  exit 1
fi

SITES_AVAILABLE="/etc/nginx/sites-available"
CONF_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"

# Lit le nouveau contenu depuis STDIN et écrase le fichier
cat > "$CONF_FILE"

if ! sudo /usr/sbin/nginx; then
  echo "nginx -t failed after save" >&2
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Saved and reloaded ${DOMAIN}"
exit 0
