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
