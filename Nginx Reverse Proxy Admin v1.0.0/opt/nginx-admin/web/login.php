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
