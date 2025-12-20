<?php
session_start();
require __DIR__ . '/config-auth.php';

if (empty($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header('Location: login.php');
    exit;
}
