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
