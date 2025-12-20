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
