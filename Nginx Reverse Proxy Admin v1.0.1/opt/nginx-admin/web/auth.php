<?php
session_start();
try {
    $db = new PDO('sqlite:' . __DIR__ . '/../db/auth.db');
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    http_response_code(500);
    error_log('DB Error: ' . $e->getMessage());
    die('Erreur DB.');
}

if (empty($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header('Location: login.php');
    exit;
}
