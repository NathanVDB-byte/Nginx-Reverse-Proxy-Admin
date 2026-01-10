```txt
/opt/nginx-admin/
├── api/
│   ├── nginx-admin-api        # binaire Go compilé
│   ├── config.yaml            # éventuelle conf API (si tu en veux une)
│   └── src/                   # (optionnel) sources Go si tu les gardes sur le serveur
│       ├── cmd/
│       │   └── nginx-admin-api/
│       │       └── main.go
│       └── internal/
│           └── service/
│               └── vhost.go
│
├── db/
│   └── auth.db
│
├── web/
│   ├── index.php
│   ├── actions.php
│   ├── login.php
│   ├── logout.php
│   ├── auth.php
│   ├── config.php
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   └── script.js
│   └── templates/
│       └── header.php
│
├── scripts/
│   ├── nginx-create-vhost.sh
│   ├── nginx-enable-vhost.sh
│   ├── nginx-disable-vhost.sh
│   ├── nginx-delete-vhost.sh
│   ├── nginx-save-conf.sh
│   └── nginx-certbot.sh
│
└── logs/
    ├── api.log        # si tu logues l’API ici
    └── web-error.log  # éventuels logs applicatifs PHP
```
