<?php
// Identifiant unique pour accéder au panel
const ADMIN_USERNAME = 'admin';

// Hash du mot de passe (généré avec password_hash)
const ADMIN_PASSWORD_HASH = '$2y$10$changemoi.................'; // à remplacer

// Pour générer un hash :
// php -r 'echo password_hash("TonMotDePasseFortIci", PASSWORD_DEFAULT), PHP_EOL;'
