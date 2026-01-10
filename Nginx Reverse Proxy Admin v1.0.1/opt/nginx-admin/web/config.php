<?php
// Chemins Nginx pour les vhosts
$NGINX_SITES_AVAILABLE = '/etc/nginx/sites-available';
$NGINX_SITES_ENABLED   = '/etc/nginx/sites-enabled';

// Domaine du panel pour ne pas lister son vhost
$ADMIN_DOMAIN = 'panel.local'; // adapte selon ton vhost d’admin

// API Go
$API_URL = 'http://127.0.0.1:9000/v1';
$API_KEY = 'CHANGE_ME_API_KEY'; // doit matcher NGINX_ADMIN_API_KEY dans le service systemd
