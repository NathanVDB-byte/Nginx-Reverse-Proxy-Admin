# Nginx Admin Panel

Un **panneau d'administration web minimaliste et sécurisé** pour gérer les vhosts Nginx sur Debian 12 sans éditer manuellement les fichiers de configuration. Créez, activez, désactivez et supprimez des vhosts HTTP, puis générez automatiquement des certificats HTTPS via Let's Encrypt (Certbot --nginx).

Ce projet est conçu par un **administrateur système et réseau**, non développeur, qui souhaite une solution simple et automatisée pour faciliter la gestion du reverse proxy via Nginx, sans passer par l’édition manuelle des fichiers de configuration.

---

## 🎯 Vue d'ensemble

Ce projet fournit une architecture complète et idiomatique :

- **API REST en Go** : endpoints sécurisés (`/v1/vhost/*`, `/v1/certbot/issue`) protégés par clé API
- **Scripts Bash robustes** : gestion des vhosts avec validation, gestion des erreurs et rechargement Nginx
- **Interface PHP** : tableau de bord web avec authentification (session/login)
- **Intégration Certbot** : génération automatique de certificats Let's Encrypt via le plugin `--nginx`
- **Organisation claire** : arborescence structurée, droits limités via `sudoers`, service systemd dédié

**Cible** : administrateurs système / développeurs intermédiaires sur Debian 12 qui souhaitent une architecture maintenable et sécurisée.

---

## 📋 Prérequis

- **Système** : Debian 12 (stretch)
- **Outils** : Nginx, Certbot, PHP-FPM (8.2+), OpenSSL, `sudo`
- **Langages** : Go 1.20+, Bash 4.0+, PHP 8.2+
- **Permissions** : accès root (pour l'installation), puis gestion des droits limités pour l'API

### Installation des dépendances

```bash
sudo apt-get update
sudo apt-get install -y \
  nginx \
  certbot \
  python3-certbot-nginx \
  php8.2-fpm \
  php8.2-cli \
  curl \
  openssl \
  golang-go
```

---

## 🚀 Installation rapide (2 CHOIX)

### 1. Cloner le dépôt

```bash
git clone https://github.com/yourusername/nginx-admin-panel.git
cd nginx-admin-panel
```

### 2. Lancer l'installation automatisée

Le projet inclut un script d'installation (`install-nginx-admin.sh`) qui automatise :
- Création du répertoire `/opt/nginx-admin`
- Création de l'utilisateur système `nginxadmin`
- Compilation de l'API Go
- Déploiement des scripts bash
- Configuration du frontend PHP
- Mise en place du service systemd

```bash
apt install sudo
sudo nano install-nginx-admin.sh
sudo chmod +x install-nginx-admin.sh
sudo ./install-nginx-admin.sh
```

**À adapter dans le script avant lancement** :
- `PANEL_DOMAIN` : domaine du panel d'administration (défaut : `panel.local`)
- `ADMIN_LOGIN` / `ADMIN_PASSWORD` : identifiants initial pour la web UI
- `API_KEY` : générée automatiquement (clé secrète pour l'API)

### 3. Vérifier l'installation

```bash
# API Go
systemctl status nginx-admin-api

# Frontend PHP
curl http://127.0.0.1:80/index.php
```

---

## 📁 Structure du projet

```
nginx-admin-panel/
├── README.md                          # Ce fichier
├── install.sh                         # Script d'installation complet
│
├── api/
│   └── src/
│       └── cmd/
│           └── nginx-admin-api/
│               └── main.go            # API REST en Go (port 9000)
│
├── scripts/                           # Scripts bash (déployés dans /opt/nginx-admin/scripts/)
│   ├── nginx-create-vhost.sh         # Créer un vhost HTTP
│   ├── nginx-enable-vhost.sh         # Activer un vhost
│   ├── nginx-disable-vhost.sh        # Désactiver un vhost
│   ├── nginx-delete-vhost.sh         # Supprimer un vhost
│   ├── nginx-save-conf.sh            # Sauvegarder/éditer un vhost
│   └── nginx-certbot.sh              # Émettre un certificat HTTPS
│
└── web/                              # Frontend PHP (déployé dans /var/www/nginx-admin/)
    ├── index.php                     # Tableau de bord
    ├── login.php                     # Authentification
    ├── logout.php                    # Déconnexion
    ├── actions.php                   # Endpoints d'actions (appels API)
    ├── edit.php                      # Édition de vhost
    ├── config.php                    # Config générale (API_URL, API_KEY)
    └── config-auth.php               # Config authentification (hash du mot de passe)
```

---

## 🔧 Architecture et composants

### API REST (Go)

L'API écoute sur `127.0.0.1:9000` et expose les endpoints suivants :

#### Gestion des vhosts

| Méthode | Endpoint | Paramètres | Description |
|---------|----------|-----------|------------|
| `POST` | `/v1/vhost/create` | `domain`, `aliases_csv`, `backend_host`, `backend_port`, `extra_headers_b64` | Créer un nouveau vhost HTTP |
| `POST` | `/v1/vhost/enable` | `domain` | Activer un vhost (créer symlink) |
| `POST` | `/v1/vhost/disable` | `domain` | Désactiver un vhost (supprimer symlink) |
| `POST` | `/v1/vhost/delete` | `domain` | Supprimer complètement un vhost |
| `POST` | `/v1/vhost/save` | `domain`, `content` | Sauvegarder/éditer la conf d'un vhost |

#### Gestion HTTPS (Certbot)

| Méthode | Endpoint | Paramètres | Description |
|---------|----------|-----------|------------|
| `POST` | `/v1/certbot/issue` | `domain`, `aliases_csv` | Émettre un certificat HTTPS via Certbot |

#### Sécurité

- **Authentification** : clé API via header `X-API-Key`
- **Validation** : tous les paramètres sont validés (regex domaine, ports, etc.)
- **Logging** : les appels API sont enregistrés dans les logs Go

**Exemple d'appel API** :

```bash
curl -X POST http://127.0.0.1:9000/v1/vhost/create \
  -H "X-API-Key: YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "example.com",
    "aliases_csv": "www.example.com",
    "backend_host": "127.0.0.1",
    "backend_port": "3000",
    "extra_headers_b64": ""
  }'
```

### Scripts Bash

Tous les scripts se trouvent dans `/opt/nginx-admin/scripts/` et sont exécutés via l'API Go avec `sudo`.

#### `nginx-create-vhost.sh <domain> <aliases_csv> <backend_host> <backend_port> [extra_headers_b64]`

Crée un vhost HTTP dans `/etc/nginx/sites-available/{domain}.conf` :
- Configure le proxy vers le backend (port 80)
- Ajoute les headers de proxy standard (`Host`, `X-Real-IP`, `X-Forwarded-*`)
- Permet les headers personnalisés via `extra_headers_b64` (base64)
- Valide la conf avec `nginx -t` et recharge Nginx

```bash
sudo /opt/nginx-admin/scripts/nginx-create-vhost.sh \
  "example.com" \
  "www.example.com,alias.example.com" \
  "127.0.0.1" \
  "3000"
```

#### `nginx-enable-vhost.sh <domain>`

Active un vhost existant en créant un symlink vers `sites-enabled` :

```bash
sudo /opt/nginx-admin/scripts/nginx-enable-vhost.sh "example.com"
```

#### `nginx-disable-vhost.sh <domain>`

Désactive un vhost en supprimant le symlink :

```bash
sudo /opt/nginx-admin/scripts/nginx-disable-vhost.sh "example.com"
```

#### `nginx-delete-vhost.sh <domain>`

Supprime complètement un vhost (fichier + symlink) :

```bash
sudo /opt/nginx-admin/scripts/nginx-delete-vhost.sh "example.com"
```

#### `nginx-save-conf.sh <domain>`

Remplace la configuration d'un vhost. Le contenu est passé via `stdin` :

```bash
cat > new-config.conf <<EOF
server {
  listen 80;
  server_name example.com;
  location / {
    proxy_pass http://127.0.0.1:3000;
  }
}
EOF

cat new-config.conf | sudo /opt/nginx-admin/scripts/nginx-save-conf.sh "example.com"
```

#### `nginx-certbot.sh <domain> [aliases_csv]`

Émet un certificat HTTPS via Certbot (plugin `--nginx`) :

```bash
sudo /opt/nginx-admin/scripts/nginx-certbot.sh "example.com" "www.example.com"
```

Certbot modifie automatiquement la configuration Nginx pour ajouter :
- Bloc `server` sur le port 443
- Redirection HTTP → HTTPS
- Certificat SSL

---

### Interface PHP

Accès via `http://panel.local/` (ou le domaine configuré).

#### Pages principales

- **`index.php`** : tableau de bord listant les vhosts, avec boutons pour créer/éditer/activer/désactiver
- **`login.php`** : formulaire d'authentification (session PHP)
- **`logout.php`** : déconnexion et suppression de session
- **`actions.php`** : endpoints internes qui appellent l'API Go via `cURL`
- **`edit.php`** : formulaire d'édition d'une configuration vhost

#### Flux d'authentification

1. Utilisateur accède `index.php`
2. Si pas de session valide → redirection vers `login.php`
3. Soumission du formulaire (identifiant/mot de passe)
4. Vérification du hash du mot de passe (`password_verify()`)
5. Création de `$_SESSION['loggedin']` et redirection vers `index.php`

Le mot de passe initial est hashé lors de l'installation dans `config-auth.php`.

#### Configuration

Deux fichiers de configuration PHP sont générés par `install.sh` :

**`config.php`** :
```php
<?php
$NGINX_SITES_AVAILABLE = '/etc/nginx/sites-available';
$NGINX_SITES_ENABLED   = '/etc/nginx/sites-enabled';

$ADMIN_DOMAIN = 'panel.local';

$API_URL = 'http://127.0.0.1:9000/v1';
$API_KEY = '...votre clé API...';
```

**`config-auth.php`** :
```php
<?php
const ADMIN_USERNAME = 'admin';
const ADMIN_PASSWORD_HASH = '$2y$10$...hash bcrypt...';
```

---

## 🔐 Sécurité et permissions

### Utilisateur système

Un utilisateur dédié `nginxadmin` est créé lors de l'installation, propriétaire de l'API Go :

```bash
id nginxadmin
# uid=1001(nginxadmin) gid=1001(nginxadmin) groups=1001(nginxadmin)
```

### Sudoers limité

Les droits `sudo` sont restreints au strict nécessaire via `/etc/sudoers.d/nginx-admin` :

```bash
# Permettre à nginxadmin d'exécuter les scripts bash sans mot de passe
nginxadmin ALL=(root) NOPASSWD: /opt/nginxadmin/scripts/nginx-create-vhost.sh, /opt/nginxadmin/scripts/nginx-enable-vhost.sh, /opt/nginxadmin/scripts/nginx-disable-vhost.sh, /opt/nginxadmin/scripts/nginx-delete-vhost.sh, /opt/nginxadmin/scripts/nginx-save-conf.sh, /opt/nginxadmin/scripts/nginx-certbot.sh

# Permettre à nginxadmin d'exécuter nginx -t et systemctl reload nginx sans mot de passe
nginxadmin ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
nginxadmin ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
```

### Droits des fichiers

| Chemin | Propriétaire | Permissions | Notes |
|--------|--------------|-----------|--------|
| `/opt/nginx-admin/api/` | `nginxadmin:nginxadmin` | 750 | API Go exécutable |
| `/opt/nginx-admin/scripts/` | `root:root` | 700 | Scripts bash (exec root) |
| `/var/www/nginx-admin/` | `www-data:www-data` | 750 | Web files PHP |
| `/etc/nginx/sites-available/` | `root:root` | 750 | Vhosts générés (props root) |

### Service systemd

Le service `nginx-admin-api` s'exécute en tant que `nginxadmin` :

```ini
[Unit]
Description=Nginx Admin Panel API
After=network.target

[Service]
Type=simple
User=nginxadmin
WorkingDirectory=/opt/nginx-admin
ExecStart=/opt/nginx-admin/api/nginx-admin-api
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

---

## 🌐 Flux d'utilisation

### Créer un vhost avec HTTPS

1. **Interface web** : remplir le formulaire (domaine, alias, backend)
2. **PHP → API Go** : appel POST `/v1/vhost/create`
3. **Go → Bash** : exécution de `nginx-create-vhost.sh` via `sudo`
4. **Bash** : création de `/etc/nginx/sites-available/domain.conf` et activation du symlink
5. **Validation** : `nginx -t` et `systemctl reload nginx`

6. **Interface web** : cliquer sur "Générer certificat HTTPS"
7. **PHP → API Go** : appel POST `/v1/certbot/issue`
8. **Go → Bash** : exécution de `nginx-certbot.sh` via `sudo`
9. **Bash** : `certbot --nginx -d domain -d www.domain`
10. **Certbot** : modifie automatiquement `/etc/nginx/sites-available/domain.conf` pour ajouter le port 443, SSL et la redirection

Résultat final : vhost HTTP + HTTPS, certificat auto-renouvelable via Certbot.

---

## 🛠️ Configuration post-installation

### Changer le mot de passe admin

```bash
# Générer un nouveau hash
sudo php8.2 -r "echo password_hash('NewPassword123!', PASSWORD_DEFAULT), PHP_EOL;"

# Mettre à jour config-auth.php
sudo nano /var/www/nginx-admin/config-auth.php
# const ADMIN_PASSWORD_HASH = '... nouveau hash ...';
```

### Modifier les domaines/ports

Éditer `/opt/nginx-admin/web/config.php` :
- `$ADMIN_DOMAIN` : domaine d'accès du panel
- `$API_URL` : adresse de l'API (par défaut `127.0.0.1:9000`)

### Ajouter des alias à un vhost existant

Via l'interface web : cliquer sur le vhost, éditer la conf, ajouter dans `server_name`:

```nginx
server_name example.com www.example.com newalias.example.com;
```

Puis soumettre. Le changement est immédiat après validation Nginx.

---

## 📊 Logs et dépannage

### Logs de l'API Go

```bash
journalctl -u nginx-admin-api -f
```

### Logs Nginx

```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Logs Certbot

```bash
tail -f /var/log/letsencrypt/letsencrypt.log
```

### Test manuel d'un endpoint API

```bash
# Créer un vhost
curl -X POST http://127.0.0.1:9000/v1/vhost/create \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.local",
    "aliases_csv": "www.test.local",
    "backend_host": "127.0.0.1",
    "backend_port": "8000",
    "extra_headers_b64": ""
  }'

# Émettre un certificat
curl -X POST http://127.0.0.1:9000/v1/certbot/issue \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.local",
    "aliases_csv": "www.test.local"
  }'
```

### Problèmes courants

| Problème | Cause | Solution |
|----------|-------|----------|
| API ne démarre pas | Port 9000 occupé | `lsof -i :9000` et arrêter le processus |
| `sudo: nginx-*.sh: command not found` | Droits sudoers mal configurés | Vérifier `/etc/sudoers.d/nginx-admin` |
| PHP ne peut pas appeler l'API | `curl` manquant | `sudo apt install curl` |
| Nginx rechargement échoue | Erreur de syntax dans conf | `nginx -t` pour vérifier |
| Certbot échoue | Domaine non résolvable | S'assurer que DNS pointe vers le serveur |

---

## 🚧 Roadmap / Améliorations futures

- [ ] Support du HTTP/2 et HTTP/3
- [ ] Gestion des certificats wildcard
- [ ] Intégration d'un gestionnaire de logs rotatifs
- [ ] Tableau de bord de monitoring (uptime, perf)
- [ ] Versioning des configurations et rollback
- [ ] Export/import de configurations
- [ ] Authentification LDAP/OAuth2
- [ ] Tests automatisés (Go, Bash, PHP)

---

## 📝 Licence

MIT License - Voir le fichier `LICENSE` pour plus de détails.

---

## 🤝 Contribution

Les contributions sont bienvenues ! Pour signaler un bug ou proposer une amélioration :

1. Ouvrir une **Issue** sur GitHub
2. Forker le dépôt et créer une branche feature (`git checkout -b feature/ma-feature`)
3. Commit vos changements (`git commit -am 'Add: description'`)
4. Push la branche (`git push origin feature/ma-feature`)
5. Ouvrir une **Pull Request**

---

## 📧 Support

Pour des questions, remarques ou support :
- Ouvrir une **Issue** sur le dépôt GitHub
- Consulter la documentation complète dans `/docs/` (si disponible)

---

**Dernier update** : décembre 2025 | **Debian** : 12 | **Go** : 1.20+ | **PHP** : 8.2+
