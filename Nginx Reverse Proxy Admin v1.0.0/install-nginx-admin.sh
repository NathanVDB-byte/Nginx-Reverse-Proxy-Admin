#!/usr/bin/env bash
set -euo pipefail

### CONFIG À ADAPTER AVANT USAGE ###
PANEL_DOMAIN="panel.local"             # domaine du panel (vhost admin)
ADMIN_USER="nginxadmin"                # user système pour l'API
APP_ROOT="/opt/nginx-admin"
API_KEY="$(openssl rand -hex 32)"      # générée automatiquement
ADMIN_LOGIN="admin"                    # login interface web
ADMIN_PASSWORD="ChangeMe123!"          # mot de passe initial (à changer après install)
PHP_FPM_SOCK="/run/php/php8.2-fpm.sock" # chemin socket PHP-FPM (Debian 12 par défaut)


echo "=== Installation Nginx Admin Panel ==="

echo "[1/8] Installation paquets (nginx, php-fpm, certbot, go)..."
apt update
apt install -y nginx php-fpm php-cli php-json php-mbstring php-curl \
               certbot python3-certbot-nginx golang

echo "[2/8] Création de l’utilisateur système ${ADMIN_USER}..."
if ! id "${ADMIN_USER}" >/dev/null 2>&1; then
  adduser --system --group --home "${APP_ROOT}" "${ADMIN_USER}"
fi

echo "[3/8] Création de l’arborescence ${APP_ROOT}..."
mkdir -p "${APP_ROOT}/api/src/cmd/nginx-admin-api"
mkdir -p "${APP_ROOT}/api/src/internal/service"
mkdir -p "${APP_ROOT}/web"
mkdir -p "${APP_ROOT}/scripts"

chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_ROOT}"
chmod -R 750 "${APP_ROOT}"

echo "[4/8] Déploiement des sources Go (copie manuelle requise)..."
cat > "${APP_ROOT}/api/src/go.mod" <<'EOF'
module nginx-admin-api

go 1.22
EOF

cat > "${APP_ROOT}/api/src/cmd/nginx-admin-api/main.go" <<'EOF'
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "strings"

    "nginx-admin-api/internal/service"
)

type Response struct {
    Ok      bool   `json:"ok"`
    Message string `json:"message"`
}

var apiKey string

func main() {
    apiKey = os.Getenv("NGINX_ADMIN_API_KEY")
    if apiKey == "" {
        log.Fatal("NGINX_ADMIN_API_KEY non défini")
    }

    mux := http.NewServeMux()

    mux.Handle("/v1/vhost/create", withAuth(handleCreate))
    mux.Handle("/v1/vhost/enable", withAuth(handleEnable))
    mux.Handle("/v1/vhost/disable", withAuth(handleDisable))
    mux.Handle("/v1/vhost/delete", withAuth(handleDelete))
    mux.Handle("/v1/vhost/save-conf", withAuth(handleSaveConf))
    mux.Handle("/v1/certbot/issue", withAuth(handleCertbot))

    addr := "127.0.0.1:9000"
    log.Printf("nginx-admin-api listening on %s", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        log.Fatal(err)
    }
}

func withAuth(next http.HandlerFunc) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        key := r.Header.Get("X-API-Key")
        if key == "" || key != apiKey {
            w.WriteHeader(http.StatusUnauthorized)
            json.NewEncoder(w).Encode(Response{Ok: false, Message: "Unauthorized"})
            return
        }
        next.ServeHTTP(w, r)
    })
}

func parseForm(r *http.Request) error {
    if err := r.ParseForm(); err != nil {
        return err
    }
    return nil
}

func handleCreate(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }

    domain := strings.TrimSpace(r.Form.Get("domain"))
    aliases := strings.TrimSpace(r.Form.Get("aliases"))
    backendHost := strings.TrimSpace(r.Form.Get("backend_host"))
    backendPort := strings.TrimSpace(r.Form.Get("backend_port"))
    extraHeaders := r.Form.Get("extra_headers")

    if domain == "" || backendHost == "" || backendPort == "" {
        writeErr(w, "Domain, backend host et port sont obligatoires.")
        return
    }

    out, err := service.CreateVhost(domain, aliases, backendHost, backendPort, extraHeaders)
    if err != nil {
        writeErr(w, "Erreur création vhost : "+out)
        return
    }
    writeOk(w, "Vhost créé avec succès.")
}

func handleEnable(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.EnableVhost(domain)
    if err != nil {
        writeErr(w, "Erreur activation : "+out)
        return
    }
    writeOk(w, "Vhost activé.")
}

func handleDisable(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.DisableVhost(domain)
    if err != nil {
        writeErr(w, "Erreur désactivation : "+out)
        return
    }
    writeOk(w, "Vhost désactivé.")
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.DeleteVhost(domain)
    if err != nil {
        writeErr(w, "Erreur suppression : "+out)
        return
    }
    writeOk(w, "Vhost supprimé.")
}

func handleSaveConf(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := r.ParseForm(); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    content := r.Form.Get("content")
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    if content == "" {
        writeErr(w, "Contenu vide.")
        return
    }

    out, err := service.SaveConf(domain, content)
    if err != nil {
        writeErr(w, "Erreur sauvegarde / nginx -t : "+out)
        return
    }
    writeOk(w, "Configuration sauvegardée et Nginx rechargé.")
}

func handleCertbot(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.IssueCert(domain)
    if err != nil {
        writeErr(w, "Erreur Let’s Encrypt : "+out)
        return
    }
    writeOk(w, "Let’s Encrypt lancé pour ce domaine.")
}

func writeOk(w http.ResponseWriter, msg string) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Response{Ok: true, Message: msg})
}

func writeErr(w http.ResponseWriter, msg string) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Response{Ok: false, Message: msg})
}

EOF

cat > "${APP_ROOT}/api/src/internal/service/vhost.go" <<'EOF'
package service

import (
	"bytes"
	"fmt"
	"os/exec"
)

func runScript(name string, args ...string) (string, error) {
	// Lance le script avec sudo
	cmd := exec.Command("sudo", append([]string{name}, args...)...)
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return stderr.String() + out.String(), fmt.Errorf("command failed: %w", err)
	}
	return out.String(), nil
}

func CreateVhost(domain, aliases, backendHost, backendPort, extraHeaders string) (string, error) {
	return runScript(
		"/opt/nginx-admin/scripts/nginx-create-vhost.sh",
		domain, aliases, backendHost, backendPort, extraHeaders,
	)
}

func EnableVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-enable-vhost.sh", domain)
}

func DisableVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-disable-vhost.sh", domain)
}

func DeleteVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-delete-vhost.sh", domain)
}

func SaveConf(domain, content string) (string, error) {
	// On pipe le contenu sur stdin -> script qui lit depuis stdin
	cmd := exec.Command("sudo", "/opt/nginx-admin/scripts/nginx-save-conf.sh", domain)
	cmd.Stdin = bytes.NewBufferString(content)

	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return stderr.String() + out.String(), fmt.Errorf("command failed: %w", err)
	}
	return out.String(), nil
}

func IssueCert(domain string) (string, error) {
	// Certbot aussi lancé avec sudo
	return runScript("/opt/nginx-admin/scripts/nginx-certbot.sh", domain)
}

EOF

chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_ROOT}/api/src"

echo "[5/8] Compilation du binaire Go..."
cd "${APP_ROOT}/api/src"
sudo -u "${ADMIN_USER}" go build -o "${APP_ROOT}/api/nginx-admin-api" ./cmd/nginx-admin-api

echo "[6/8] Déploiement des scripts bash..."
cat > "${APP_ROOT}/scripts/nginx-create-vhost.sh" <<'EOF'
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

EOF

cat > "${APP_ROOT}/scripts/nginx-enable-vhost.sh" <<'EOF'
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

EOF

cat > "${APP_ROOT}/scripts/nginx-disable-vhost.sh" <<'EOF'
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

EOF

cat > "${APP_ROOT}/scripts/nginx-delete-vhost.sh" <<'EOF'
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

EOF

cat > "${APP_ROOT}/scripts/nginx-save-conf.sh" <<'EOF'
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

if ! sudo /usr/sbin/nginx -t; then
  echo "nginx -t failed after save" >&2
  exit 1
fi

sudo /bin/systemctl reload nginx
echo "Saved and reloaded ${DOMAIN}"
exit 0

EOF

cat > "${APP_ROOT}/scripts/nginx-certbot.sh" <<'EOF'
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

EOF

chown -R nginxadmin:nginxadmin "${APP_ROOT}/scripts"
chmod 700 "${APP_ROOT}/scripts/"*.sh

echo "[7/8] Déploiement du frontend PHP..."
# Hash du mot de passe admin
ADMIN_PWD_HASH="$(php -r "echo password_hash('${ADMIN_PASSWORD}', PASSWORD_DEFAULT), PHP_EOL;")"

cat > "${APP_ROOT}/web/config.php" <<EOF
<?php
\$NGINX_SITES_AVAILABLE = '/etc/nginx/sites-available';
\$NGINX_SITES_ENABLED   = '/etc/nginx/sites-enabled';

\$ADMIN_DOMAIN = '${PANEL_DOMAIN}';

\$API_URL = 'http://127.0.0.1:9000/v1';
\$API_KEY = '${API_KEY}';
EOF

cat > "${APP_ROOT}/web/config-auth.php" <<EOF
<?php
const ADMIN_USERNAME = '${ADMIN_LOGIN}';
const ADMIN_PASSWORD_HASH = '${ADMIN_PWD_HASH}';
EOF

# login.php, logout.php, auth.php, actions.php, index.php, edit.php
# (on injecte ici les versions complètes déjà écrites)
cat > "${APP_ROOT}/web/auth.php" <<'EOF'
<?php
session_start();
require __DIR__ . '/config-auth.php';

if (empty($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header('Location: login.php');
    exit;
}

EOF

cat > "${APP_ROOT}/web/login.php" <<'EOF'
<?php
session_start();
require __DIR__ . '/config-auth.php';

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if ($username === '' || $password === '') {
        $error = 'Identifiant ou mot de passe manquant.';
    } elseif ($username !== ADMIN_USERNAME || !password_verify($password, ADMIN_PASSWORD_HASH)) {
        $error = 'Identifiant ou mot de passe incorrect.';
    } else {
        session_regenerate_id(true);
        $_SESSION['loggedin'] = true;
        header('Location: index.php');
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Connexion - Nginx Reverse Proxy Admin</title>
    <style>
        :root {
            --bg: #f5f5f5;
            --card-bg: #ffffff;
            --primary: #2563eb;
            --primary-hover: #1d4ed8;
            --border: #e5e7eb;
            --text-main: #111827;
            --text-muted: #6b7280;
            --danger: #dc2626;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            padding: 0;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: radial-gradient(circle at top, #dbeafe 0, #f5f5f5 45%);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .card {
            width: 100%;
            max-width: 380px;
            background: var(--card-bg);
            border-radius: 16px;
            padding: 24px 24px 20px;
            box-shadow: 0 20px 40px rgba(15,23,42,0.18);
            border: 1px solid var(--border);
        }
        h1 {
            margin: 0 0 4px;
            font-size: 22px;
        }
        .subtitle {
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-size: 13px;
            margin-bottom: 4px;
            font-weight: 500;
        }
        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 9px 11px;
            border-radius: 10px;
            border: 1px solid var(--border);
            font-size: 14px;
        }
        input:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 1px rgba(37,99,235,0.25);
        }
        .form-group { margin-bottom: 12px; }
        .btn-primary {
            width: 100%;
            border: none;
            border-radius: 999px;
            padding: 9px 12px;
            font-size: 14px;
            cursor: pointer;
            background: var(--primary);
            color: #ffffff;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-top: 8px;
        }
        .btn-primary:hover {
            background: var(--primary-hover);
        }
        .error {
            margin-bottom: 10px;
            padding: 8px 10px;
            border-radius: 8px;
            font-size: 13px;
            color: #b91c1c;
            background: #fee2e2;
            border: 1px solid #fecaca;
        }
        .footer {
            margin-top: 16px;
            font-size: 12px;
            color: var(--text-muted);
            text-align: center;
        }
    </style>
</head>
<body>
<div class="card">
    <h1>Connexion</h1>
    <div class="subtitle">Nginx Reverse Proxy Admin</div>

    <?php if ($error): ?>
        <div class="error"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="post" action="login.php">
        <div class="form-group">
            <label for="username">Identifiant</label>
            <input type="text" id="username" name="username" autocomplete="username" required>
        </div>
        <div class="form-group">
            <label for="password">Mot de passe</label>
            <input type="password" id="password" name="password" autocomplete="current-password" required>
        </div>
        <button type="submit" class="btn-primary">Se connecter</button>
    </form>

    <div class="footer">
        Accès réservé à l’administration du reverse proxy.
    </div>
</div>
</body>
</html>

EOF

cat > "${APP_ROOT}/web/logout.php" <<'EOF'
<?php
session_start();
$_SESSION = [];

if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000,
        $params["path"], $params["domain"],
        $params["secure"], $params["httponly"]
    );
}

session_destroy();
header('Location: login.php');
exit;

EOF

cat > "${APP_ROOT}/web/actions.php" <<'EOF'
<?php
require __DIR__ . '/auth.php';
require __DIR__ . '/config.php';

header('Content-Type: application/json');

function respond(bool $ok, string $message, array $extra = []): void {
    echo json_encode(array_merge([
        'ok'      => $ok,
        'message' => $message,
    ], $extra));
    exit;
}

/**
 * Appelle l’API Go via HTTP POST form-url-encoded
 */
function call_api(string $endpoint, array $data, string $apiUrl, string $apiKey): array {
    $postData = http_build_query($data);

    $context = stream_context_create([
        'http' => [
            'method'  => 'POST',
            'header'  =>
                "Content-Type: application/x-www-form-urlencoded\r\n" .
                "X-API-Key: " . $apiKey . "\r\n",
            'content' => $postData,
            'timeout' => 15,
        ],
    ]);

    $url = rtrim($apiUrl, '/') . '/' . ltrim($endpoint, '/');

    $resp = @file_get_contents($url, false, $context);
    if ($resp === false) {
        respond(false, 'Erreur appel API Go (' . $endpoint . ').');
    }

    $data = json_decode($resp, true);
    if (!is_array($data)) {
        respond(false, 'Réponse API invalide (' . $endpoint . ').');
    }
    return $data;
}

$action = trim($_POST['action'] ?? '');

if ($action === '') {
    respond(false, 'Action manquante.');
}

if ($action === 'create') {

    $domain        = trim($_POST['domain'] ?? '');
    $aliases       = trim($_POST['aliases'] ?? '');
    $backend_host  = trim($_POST['backend_host'] ?? '');
    $backend_port  = trim($_POST['backend_port'] ?? '');
    $extra_headers = trim($_POST['extra_headers'] ?? '');
    $auto_cert     = ($_POST['auto_cert'] ?? '') === '1';

    if ($domain === '' || $backend_host === '' || $backend_port === '') {
        respond(false, 'Domain, backend host et port sont obligatoires.');
    }

    $payload = [
        'domain'       => $domain,
        'aliases'      => $aliases,
        'backend_host' => $backend_host,
        'backend_port' => $backend_port,
        'extra_headers'=> $extra_headers,
    ];

    // 1) Création du vhost
    $data = call_api('vhost/create', $payload, $API_URL, $API_KEY);
    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (create).');
    }

    // 2) Activation immédiate
    $dataEnable = call_api('vhost/enable', ['domain' => $domain], $API_URL, $API_KEY);
    if (empty($dataEnable['ok'])) {
        respond(false, 'Vhost créé mais erreur à l’activation : ' . ($dataEnable['message'] ?? 'Erreur API (enable).'));
    }

    // 3) Optionnel : Certbot
    if ($auto_cert) {
        $data2 = call_api('certbot/issue', ['domain' => $domain], $API_URL, $API_KEY);
        if (empty($data2['ok'])) {
            respond(true, 'Vhost créé et activé mais erreur Let’s Encrypt : ' . ($data2['message'] ?? 'Erreur API.'));
        }
        respond(true, 'Vhost créé, activé et Let’s Encrypt lancé.');
    }

    respond(true, 'Vhost créé et activé avec succès.');

} elseif ($action === 'enable') {

    $domain = trim($_POST['domain'] ?? '');
    if ($domain === '') {
        respond(false, 'Domaine manquant.');
    }

    $data = call_api('vhost/enable', ['domain' => $domain], $API_URL, $API_KEY);
    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (enable).');
    }
    respond(true, $data['message'] ?? 'Vhost activé.');

} elseif ($action === 'disable') {

    $domain = trim($_POST['domain'] ?? '');
    if ($domain === '') {
        respond(false, 'Domaine manquant.');
    }

    $data = call_api('vhost/disable', ['domain' => $domain], $API_URL, $API_KEY);
    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (disable).');
    }
    respond(true, $data['message'] ?? 'Vhost désactivé.');

} elseif ($action === 'delete') {

    $domain = trim($_POST['domain'] ?? '');
    if ($domain === '') {
        respond(false, 'Domaine manquant.');
    }

    $data = call_api('vhost/delete', ['domain' => $domain], $API_URL, $API_KEY);
    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (delete).');
    }
    respond(true, $data['message'] ?? 'Vhost supprimé.');

} elseif ($action === 'certbot') {

    $domain = trim($_POST['domain'] ?? '');
    if ($domain === '') {
        respond(false, 'Domaine manquant.');
    }

    $data = call_api('certbot/issue', ['domain' => $domain], $API_URL, $API_KEY);
    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (certbot).');
    }
    respond(true, $data['message'] ?? 'Let’s Encrypt lancé.');

} elseif ($action === 'save_conf') {

    $domain  = trim($_POST['domain'] ?? '');
    $content = $_POST['content'] ?? '';

    if ($domain === '') {
        respond(false, 'Domaine manquant.');
    }
    if ($content === '') {
        respond(false, 'Contenu vide.');
    }

    $data = call_api('vhost/save-conf', [
        'domain'  => $domain,
        'content' => $content,
    ], $API_URL, $API_KEY);

    if (empty($data['ok'])) {
        respond(false, $data['message'] ?? 'Erreur API (save_conf).');
    }
    respond(true, $data['message'] ?? 'Configuration sauvegardée.');

} else {
    respond(false, 'Action inconnue.');
}

EOF

cat > "${APP_ROOT}/web/index.php" <<'EOF'
<?php
require __DIR__ . '/auth.php';
require __DIR__ . '/config.php';

$sites = [];
foreach (glob($NGINX_SITES_AVAILABLE . '/*.conf') as $file) {
    $basename = basename($file);
    $domain   = preg_replace('/\.conf$/', '', $basename);

    if ($domain === $ADMIN_DOMAIN) {
        continue;
    }

    $enabled = file_exists($NGINX_SITES_ENABLED . '/' . $basename);

    $content = @file_get_contents($file);
    $serverName = 'N/A';
    $backend    = 'N/A';

    if (preg_match('/server_name\s+([^;]+);/i', $content, $m)) {
        $serverName = trim($m[1]);
    }
    if (preg_match('/proxy_pass\s+http:\/\/([^;]+);/i', $content, $m)) {
        $backend = trim($m[1]);
    }

    $sites[] = [
        'domain'      => $domain,
        'file'        => $basename,
        'enabled'     => $enabled,
        'server_name' => $serverName,
        'backend'     => $backend,
    ];
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Nginx Reverse Proxy Admin</title>
    <!-- même CSS inline que ta version actuelle -->
    <style>
        :root {
            --bg: #f5f5f5;
            --card-bg: #ffffff;
            --primary: #2563eb;
            --primary-hover: #1d4ed8;
            --danger: #dc2626;
            --danger-hover: #b91c1c;
            --border: #e5e7eb;
            --text-main: #111827;
            --text-muted: #6b7280;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            padding: 0;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: var(--bg);
            color: var(--text-main);
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 24px;
        }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
        }
        header h1 {
            margin: 0;
            font-size: 24px;
        }
        header p {
            margin: 4px 0 0;
            color: var(--text-muted);
        }
        .stats {
            display: flex;
            gap: 12px;
            font-size: 14px;
            color: var(--text-muted);
        }
        .badge {
            background: #e5f0ff;
            color: #1d4ed8;
            padding: 4px 8px;
            border-radius: 999px;
        }
        .layout {
            display: flex;
            gap: 24px;
            align-items: flex-start;
        }
        .col { flex: 1; }
        .card {
            background: var(--card-bg);
            border-radius: 12px;
            padding: 16px 20px;
            box-shadow: 0 8px 20px rgba(15,23,42,0.06);
            border: 1px solid var(--border);
        }
        .card + .card { margin-top: 12px; }
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }
        .card-title { font-weight: 600; }
        .card-subtitle {
            font-size: 13px;
            color: var(--text-muted);
        }
        .pill {
            font-size: 12px;
            padding: 4px 8px;
            border-radius: 999px;
        }
        .pill-on {
            background: #dcfce7;
            color: #166534;
        }
        .pill-off {
            background: #fef2f2;
            color: #b91c1c;
        }
        .card-body {
            font-size: 14px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }
        .card-footer {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }
        button, .btn-link {
            border: none;
            border-radius: 999px;
            padding: 6px 12px;
            font-size: 13px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            text-decoration: none;
        }
        .btn-primary {
            background: var(--primary);
            color: #ffffff;
        }
        .btn-primary:hover {
            background: var(--primary-hover);
        }
        .btn-danger {
            background: #dc2626;
            color: #ffffff;
        }
        .btn-danger:hover {
            background: #b91c1c;
        }
        .btn-outline {
            background: #ffffff;
            border: 1px solid var(--border);
            color: #111827;
        }
        .btn-outline:hover {
            background: #f3f4f6;
        }
        .btn-secondary {
            background: #f3f4f6;
            color: #111827;
        }
        .btn-secondary:hover {
            background: #e5e7eb;
        }
        .badge-small {
            font-size: 11px;
            padding: 2px 6px;
            border-radius: 999px;
            background: #f3f4f6;
            color: var(--text-muted);
        }
        .form-group {
            margin-bottom: 12px;
        }
        label {
            display: block;
            font-size: 13px;
            margin-bottom: 4px;
            font-weight: 500;
        }
        input[type="text"],
        input[type="number"],
        textarea {
            width: 100%;
            padding: 8px 10px;
            border-radius: 8px;
            border: 1px solid var(--border);
            font-size: 14px;
        }
        input:focus, textarea:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 1px rgba(37,99,235,0.25);
        }
        .help {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 2px;
        }
        .checkbox-row {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 13px;
        }
        .actions-row {
            display: flex;
            gap: 8px;
            margin-top: 8px;
        }
        #toast {
            position: fixed;
            bottom: 16px;
            right: 16px;
            min-width: 200px;
            max-width: 320px;
            padding: 10px 14px;
            border-radius: 10px;
            font-size: 13px;
            display: none;
            z-index: 9999;
        }
        #toast.ok {
            background: #16a34a;
            color: #fff;
        }
        #toast.err {
            background: #dc2626;
            color: #fff;
        }
        @media (max-width: 900px) {
            .layout { flex-direction: column; }
            header {
                flex-direction: column;
                align-items: flex-start;
                gap: 8px;
            }
        }
    </style>
</head>
<body>
<div class="container">
    <header>
        <div>
            <h1>Nginx Reverse Proxy Admin</h1>
            <p>Gestion simple des vhosts reverse proxy (Debian 12).</p>
        </div>
        <div style="display:flex; align-items:center; gap:12px;">
            <div class="stats">
                <span class="badge"><?= count($sites) ?> vhost(s)</span>
                <span class="badge">
                    <?= count(array_filter($sites, fn($s) => $s['enabled'])) ?> activé(s)
                </span>
            </div>
            <a href="logout.php" class="btn-secondary btn-link">
                Déconnexion
            </a>
        </div>
    </header>

    <div class="layout">
        <div class="col">
            <div class="card">
                <div class="card-header">
                    <div>
                        <div class="card-title">Vhosts existants</div>
                        <div class="card-subtitle">Basés sur sites-available / sites-enabled</div>
                    </div>
                </div>
                <?php if (empty($sites)): ?>
                    <p class="card-body">Aucun vhost trouvé dans <code>sites-available</code>.</p>
                <?php endif; ?>
            </div>

            <?php foreach ($sites as $site): ?>
                <div class="card">
                    <div class="card-header">
                        <div>
                            <div class="card-title"><?= htmlspecialchars($site['domain']) ?></div>
                            <div class="card-subtitle"><?= htmlspecialchars($site['server_name']) ?></div>
                        </div>
                        <div>
                            <?php if ($site['enabled']): ?>
                                <span class="pill pill-on">Activé</span>
                            <?php else: ?>
                                <span class="pill pill-off">Désactivé</span>
                            <?php endif; ?>
                        </div>
                    </div>
                    <div class="card-body">
                        Backend : <strong><?= htmlspecialchars($site['backend']) ?></strong><br>
                        Fichier : <span class="badge-small"><?= htmlspecialchars($site['file']) ?></span>
                    </div>
                    <div class="card-footer">
                        <?php if ($site['enabled']): ?>
                            <button class="btn-outline" onclick="actionDisable('<?= htmlspecialchars($site['domain']) ?>')">
                                Désactiver
                            </button>
                        <?php else: ?>
                            <button class="btn-outline" onclick="actionEnable('<?= htmlspecialchars($site['domain']) ?>')">
                                Activer
                            </button>
                        <?php endif; ?>

                        <button class="btn-outline" onclick="actionCertbot('<?= htmlspecialchars($site['domain']) ?>')">
                            Certificat Let’s Encrypt
                        </button>

                        <button class="btn-outline" onclick="window.location.href='edit.php?domain=<?= urlencode($site['domain']) ?>'">
                            Éditer
                        </button>

                        <button class="btn-danger" onclick="actionDelete('<?= htmlspecialchars($site['domain']) ?>')">
                            Supprimer
                        </button>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>

        <div class="col">
            <div class="card">
                <div class="card-header">
                    <div>
                        <div class="card-title">Nouveau reverse proxy</div>
                        <div class="card-subtitle">Création d’un vhost HTTP (Certbot gère le HTTPS)</div>
                    </div>
                </div>
                <div class="card-body">
                    <form id="createForm">
                        <div class="form-group">
                            <label for="domain">Domaine principal</label>
                            <input type="text" id="domain" name="domain" required placeholder="ex : app.mondomaine.fr">
                            <div class="help">Servira aussi de nom de fichier <code>app.mondomaine.fr.conf</code>.</div>
                        </div>

                        <div class="form-group">
                            <label for="aliases">Alias (optionnel)</label>
                            <input type="text" id="aliases" name="aliases" placeholder="ex : www.mondomaine.fr, autre.mondomaine.fr">
                            <div class="help">Liste de domaines séparés par des virgules.</div>
                        </div>

                        <div class="form-group">
                            <label for="backend_host">Backend (host/IP)</label>
                            <input type="text" id="backend_host" name="backend_host" required placeholder="ex : 10.0.0.5 ou service.local">
                        </div>

                        <div class="form-group">
                            <label for="backend_port">Port backend</label>
                            <input type="number" id="backend_port" name="backend_port" required value="80">
                        </div>

                        <div class="form-group">
                            <label for="extra_headers">Headers additionnels (optionnel)</label>
                            <textarea id="extra_headers" name="extra_headers" rows="3" placeholder="# lignes Nginx injectées dans le bloc location"></textarea>
                        </div>

                        <div class="form-group checkbox-row">
                            <input type="checkbox" id="auto_cert" name="auto_cert" value="1">
                            <label for="auto_cert">Lancer Let’s Encrypt juste après la création</label>
                        </div>

                        <div class="actions-row">
                            <button class="btn-primary" type="submit">Créer le vhost</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>

<div id="toast"></div>

<script>
async function callAction(payload) {
    const resp = await fetch('actions.php', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: new URLSearchParams(payload)
    });

    let data;
    try {
        data = await resp.json();
    } catch (e) {
        showToast('Réponse invalide du serveur', false);
        return;
    }

    showToast(data.message || (data.ok ? 'OK' : 'Erreur'), data.ok);
    if (data.ok) {
        setTimeout(() => location.reload(), 800);
    }
}

function showToast(msg, ok) {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = ok ? 'ok' : 'err';
    t.style.display = 'block';
    setTimeout(() => { t.style.display = 'none'; }, 3000);
}

function actionEnable(domain) {
    callAction({action: 'enable', domain});
}
function actionDisable(domain) {
    if (!confirm('Désactiver ce vhost ?')) return;
    callAction({action: 'disable', domain});
}
function actionCertbot(domain) {
    callAction({action: 'certbot', domain});
}
function actionDelete(domain) {
    if (!confirm('Supprimer complètement ce vhost ?')) return;
    callAction({action: 'delete', domain});
}

document.getElementById('createForm').addEventListener('submit', function (e) {
    e.preventDefault();
    const form = e.target;
    const payload = {
        action: 'create',
        domain: form.domain.value,
        aliases: form.aliases.value,
        backend_host: form.backend_host.value,
        backend_port: form.backend_port.value,
        extra_headers: form.extra_headers.value,
        auto_cert: form.auto_cert.checked ? '1' : '0'
    };
    callAction(payload);
});
</script>
</body>
</html>

EOF

cat > "${APP_ROOT}/web/edit.php" <<'EOF'
<?php
require __DIR__ . '/auth.php';
require __DIR__ . '/config.php';

$domain = $_GET['domain'] ?? '';
$domain = trim($domain);

if ($domain === '') {
    http_response_code(400);
    echo "Domaine manquant.";
    exit;
}

$confFile = $NGINX_SITES_AVAILABLE . '/' . $domain . '.conf';
if (!is_file($confFile)) {
    http_response_code(404);
    echo "Fichier de configuration introuvable : " . htmlspecialchars($confFile);
    exit;
}

$content = file_get_contents($confFile);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Éditer vhost - <?= htmlspecialchars($domain) ?></title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: #f5f5f5;
            color: #111827;
        }
        .container {
            max-width: 1100px;
            margin: 24px auto;
            padding: 16px 16px;
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 8px 20px rgba(15,23,42,0.06);
            border: 1px solid #e5e7eb;
        }
        h1 {
            margin-top: 0;
            font-size: 22px;
        }
        .path {
            font-size: 13px;
            color: #6b7280;
            margin-bottom: 12px;
        }
        textarea {
            width: 100%;
            box-sizing: border-box;
            height: 500px;
            font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            font-size: 13px;
            border-radius: 8px;
            border: 1px solid #e5e7eb;
            padding: 10px;
            resize: vertical;
            white-space: pre;
        }
        textarea:focus {
            outline: none;
            border-color: #2563eb;
            box-shadow: 0 0 0 1px rgba(37,99,235,0.25);
        }
        .actions {
            margin-top: 12px;
            display: flex;
            gap: 8px;
        }
        button {
            border: none;
            border-radius: 999px;
            padding: 6px 12px;
            font-size: 13px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
        }
        .btn-primary {
            background: #2563eb;
            color: #ffffff;
        }
        .btn-primary:hover {
            background: #1d4ed8;
        }
        .btn-outline {
            background: #ffffff;
            border: 1px solid #e5e7eb;
            color: #111827;
        }
        .btn-outline:hover {
            background: #f3f4f6;
        }
        .alert {
            margin-top: 12px;
            padding: 8px 10px;
            border-radius: 8px;
            font-size: 13px;
        }
        .alert-info {
            background: #eff6ff;
            color: #1d4ed8;
            border: 1px solid #bfdbfe;
        }
        #toast {
            position: fixed;
            bottom: 16px;
            right: 16px;
            min-width: 200px;
            max-width: 320px;
            padding: 10px 14px;
            border-radius: 10px;
            font-size: 13px;
            display: none;
            z-index: 9999;
        }
        #toast.ok {
            background: #16a34a;
            color: #fff;
        }
        #toast.err {
            background: #dc2626;
            color: #fff;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Éditer le vhost : <?= htmlspecialchars($domain) ?></h1>
    <div class="path">
        Fichier : <code><?= htmlspecialchars($confFile) ?></code>
    </div>

    <div class="alert alert-info">
        Modifie la configuration Nginx à tes risques. Pense à tes backups / Git avant de toucher à la prod.
    </div>

    <form id="editForm">
        <input type="hidden" name="action" value="save_conf">
        <input type="hidden" name="domain" value="<?= htmlspecialchars($domain) ?>">
        <textarea name="content"><?= htmlspecialchars($content) ?></textarea>

        <div class="actions">
            <button class="btn-primary" type="submit">Enregistrer &amp; recharger Nginx</button>
            <button type="button" class="btn-outline" onclick="window.location.href='index.php'">
                Retour à la liste
            </button>
        </div>
    </form>
</div>

<div id="toast"></div>

<script>
async function callAction(payload) {
    const resp = await fetch('actions.php', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: new URLSearchParams(payload)
    });

    let data;
    try {
        data = await resp.json();
    } catch (e) {
        showToast('Réponse invalide du serveur', false);
        return;
    }

    showToast(data.message || (data.ok ? 'OK' : 'Erreur'), data.ok);
    if (data.ok) {
        setTimeout(() => window.location.href = 'index.php', 800);
    }
}

function showToast(msg, ok) {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = ok ? 'ok' : 'err';
    t.style.display = 'block';
    setTimeout(() => { t.style.display = 'none'; }, 3000);
}

document.getElementById('editForm').addEventListener('submit', function (e) {
    e.preventDefault();
    const form = e.target;
    const payload = {
        action: form.action.value,
        domain: form.domain.value,
        content: form.content.value
    };
    callAction(payload);
});
</script>
</body>
</html>

EOF

chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_ROOT}/web"
chmod -R 640 "${APP_ROOT}/web"/*.php

echo "[8/8] Configuration Nginx + systemd + sudoers..."

# Vhost panel
cat > /etc/nginx/sites-available/nginx-admin.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${PANEL_DOMAIN};

    root ${APP_ROOT}/web;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
    }
}
EOF

ln -sf /etc/nginx/sites-available/nginx-admin.conf /etc/nginx/sites-enabled/nginx-admin.conf
rm -f /etc/nginx/sites-enabled/default || true

nginx -t
systemctl reload nginx

# Service systemd
cat > /etc/systemd/system/nginx-admin-api.service <<EOF
[Unit]
Description=Nginx admin backend API (Go)
After=network.target

[Service]
Type=simple
User=${ADMIN_USER}
WorkingDirectory=${APP_ROOT}/api
Environment=NGINX_ADMIN_API_KEY=${API_KEY}
ExecStart=${APP_ROOT}/api/nginx-admin-api
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now nginx-admin-api

# Sudoers
cat > /etc/sudoers.d/nginxadmin <<EOF
${ADMIN_USER} ALL=(root) NOPASSWD: /usr/sbin/nginx -t, /bin/systemctl reload nginx
${ADMIN_USER} ALL=(root) NOPASSWD: ${APP_ROOT}/scripts/nginx-create-vhost.sh, ${APP_ROOT}/scripts/nginx-enable-vhost.sh, ${APP_ROOT}/scripts/nginx-disable-vhost.sh, ${APP_ROOT}/scripts/nginx-delete-vhost.sh, ${APP_ROOT}/scripts/nginx-save-conf.sh, ${APP_ROOT}/scripts/nginx-certbot.sh
EOF
chmod 440 /etc/sudoers.d/nginxadmin

# Ajout de www-data dans le groupe nginxadmin
echo "[*] Ajout de www-data dans le groupe nginxadmin..."
if ! id -nG www-data | grep -qw nginxadmin; then
    usermod -aG nginxadmin www-data
    echo "    -> www-data ajouté au groupe nginxadmin"
else
    echo "    -> www-data est déjà dans le groupe nginxadmin"
fi

# Redémarrage de nginx et php-fpm pour prise en compte du nouveau groupe
echo "[*] Redémarrage de nginx et php-fpm..."
systemctl restart nginx

if systemctl list-units --type=service | grep -q 'php.*fpm'; then
    systemctl restart "$(systemctl list-units --type=service | awk '/php.*fpm/ {print $1; exit}')"
fi

echo "[*] Fin de l'installation. Les groupes et services sont à jour."

echo
echo "=== Installation terminée ==="
echo "Domaine panel      : http://${PANEL_DOMAIN}"
echo "Identifiant admin  : ${ADMIN_LOGIN}"
echo "Mot de passe admin : ${ADMIN_PASSWORD}"
echo "Clé API (Go/PHP)   : ${API_KEY}"
echo
echo "Pense à :"
echo " - ajouter ${PANEL_DOMAIN} dans ton DNS (ou /etc/hosts pour tes tests),"
echo " - changer le mot de passe admin après la première connexion."

read -p "Redémarrer la VM pour appliquer les permissions (Y/n) ? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "[*] Redémarrage de la VM..."
    reboot
else
    echo "[*] Redémarrage annulé."
fi
