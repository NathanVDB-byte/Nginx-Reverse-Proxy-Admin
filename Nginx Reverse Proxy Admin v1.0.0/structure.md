```bash
/opt/nginx-admin/
├── api/
│   ├── nginx-admin-api        # Binaire Go compilé (API REST)
│   ├── config.yaml            # Configuration optionnelle de l'API (si utilisée)
│   └── src/                   # Sources Go (optionnel, si conservées sur le serveur)
│       ├── cmd/
│       │   └── nginx-admin-api/
│       │       └── main.go    # Point d'entrée de l'API
│       └── internal/
│           └── service/
│               └── vhost.go   # Logique métier de gestion des vhosts
│
├── web/
│   ├── index.php              # Tableau de bord principal
│   ├── actions.php            # Endpoints d'actions (appels API)
│   ├── login.php              # Formulaire de connexion
│   ├── logout.php             # Déconnexion
│   ├── auth.php               # Vérification d'authentification
│   ├── config.php             # Configuration générale (chemins, API)
│   ├── config-auth.php        # Identifiants et mot de passe hashé
│   ├── css/
│   │   └── style.css          # Styles CSS du panel
│   ├── js/
│   │   └── script.js          # Scripts JS pour l'interface
│   └── templates/
│       └── header.php         # Template d'en-tête réutilisable
│
├── scripts/
│   ├── nginx-create-vhost.sh  # Création d'un vhost HTTP
│   ├── nginx-enable-vhost.sh  # Activation d'un vhost
│   ├── nginx-disable-vhost.sh # Désactivation d'un vhost
│   ├── nginx-delete-vhost.sh  # Suppression d'un vhost
│   ├── nginx-save-conf.sh     # Édition de la configuration d'un vhost
│   └── nginx-certbot.sh       # Émission d'un certificat HTTPS via Certbot
│
└── logs/
    ├── api.log                # Logs de l'API Go (optionnel)
    └── web-error.log          # Logs applicatifs PHP (optionnel)
```
