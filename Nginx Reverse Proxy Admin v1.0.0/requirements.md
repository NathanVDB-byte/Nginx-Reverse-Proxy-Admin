```bash
cd /opt/nginx-admin/api/src
go build -o /opt/nginx-admin/api/nginx-admin-api ./cmd/nginx-admin-api
```

```bash
sudo mkdir -p /opt/nginx-admin/scripts
sudo chown -R root:root /opt/nginx-admin/scripts
sudo chmod 640 /opt/nginx-admin/scripts/*.sh
```

```bash
nginxadmin ALL=(root) NOPASSWD: /usr/sbin/nginx -t, /bin/systemctl reload nginx
nginxadmin ALL=(root) NOPASSWD: ${APP_ROOT}/scripts/nginx-create-vhost.sh, ${APP_ROOT}/scripts/nginx-enable-vhost.sh, ${APP_ROOT}/scripts/nginx-disable-vhost.sh, ${APP_ROOT}/scripts/nginx-delete-vhost.sh, ${APP_ROOT}/scripts/nginx-save-conf.sh, ${APP_ROOT}/scripts/nginx-certbot.sh
```bash

# Faire le lien site-available et site-enabled de l'application
```bash
ln -s /etc/nginx/sites-available/nginx-admin.conf /etc/nginx/sites-enabled/nginx-admin.conf
```

# Pour tester et redemarrer Nginx
```bash
nginx -t && systemctl reload nginx
```

# Pour générer ton propre hash (en root ou user normal) :​
```bash
php -r 'echo password_hash("TonMotDePasseFortIci", PASSWORD_DEFAULT) . PHP_EOL;'
```
