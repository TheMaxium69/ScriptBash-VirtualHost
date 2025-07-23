#!/bin/bash

# --- Vérification et configuration ---

# Vérifier si le domaine a été fourni en argument
if [ -z "$1" ]; then
    echo "Utilisation: $0 <nom_de_domaine>"
    exit 1
fi

DOMAIN_NAME=$1
APACHE_CONF="/etc/apache2/sites-available/000-default.conf"
WEB_ROOT="/var/www/html"
SERVER_ADMIN="officiel@tyrolium.fr"

git clone https://github.com/TheMaxium69/Tyrolium-Uptime-InServer.git $WEB_ROOT

# --- Étape 1 : Créer la configuration HTTP ---

echo "Création du fichier de configuration Apache pour $DOMAIN_NAME (HTTP)..."
sudo tee "$APACHE_CONF" > /dev/null <<EOF
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName $DOMAIN_NAME

        ServerAdmin $SERVER_ADMIN
        DocumentRoot /var/www/html

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

echo "Redémarrage du service Apache pour prendre en compte le VirtualHost HTTP..."
sudo systemctl restart apache2

# --- Étape 2 : Obtenir les certificats SSL avec Certbot ---

echo "Exécution de Certbot pour obtenir un certificat SSL pour $DOMAIN_NAME..."
sudo certbot --apache -d "$DOMAIN_NAME" --agree-tos --no-eff-email -m "$SERVER_ADMIN"

# Redémarrage final d'Apache
echo "Redémarrage final du service Apache pour prendre en compte tous les changements..."
sudo systemctl restart apache2

echo "Félicitations ! Le nouveau VirtualHost pour $DOMAIN_NAME est configuré avec SSL et la redirection HTTP vers HTTPS."