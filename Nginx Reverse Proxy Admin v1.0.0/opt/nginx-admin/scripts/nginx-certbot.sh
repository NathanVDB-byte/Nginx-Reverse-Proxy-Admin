#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
ALIASES_CSV="${2:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Domain required" >&2
  exit 1
fi

DOMAINS=(-d "$DOMAIN")
IFS=',' read -r -a ALIASES <<< "$ALIASES_CSV"
for a in "${ALIASES[@]}"; do
  [[ -n "$a" ]] && DOMAINS+=(-d "$a")
done

# Script exécuté en root via sudo depuis IssueCert() (Go)
certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email "${DOMAINS[@]}"

if ! sudo /usr/sbin/nginx -t; then
  echo "nginx -t failed after certbot" >&2
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Certbot OK for ${DOMAIN}"
exit 0
