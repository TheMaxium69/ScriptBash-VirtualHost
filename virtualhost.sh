#!/bin/bash

# --- Vérification et configuration ---

# Vérifier si le domaine a été fourni en argument
if [ -z "$1" ]; then
    echo "Utilisation: $0 <nom_de_domaine>"
    exit 1
fi

DOMAIN_NAME=$1
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN_NAME.conf"
APACHE_SSL_CONF="/etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.fr.conf"
WEB_ROOT="/var/www/$DOMAIN_NAME"
SERVER_ADMIN="officiel@tyrolium.fr"

# Créer le répertoire racine du site
echo "Création du répertoire $WEB_ROOT..."
sudo mkdir -p "$WEB_ROOT"
sudo chown -R $USER:$USER "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

# Créer un fichier index.html par défaut
echo "Création d'un fichier index.html par défaut..."
echo "<h1>Bienvenue sur $DOMAIN_NAME !</h1>" | sudo tee "$WEB_ROOT/index.html" > /dev/null

# --- Étape 1 : Créer la configuration HTTP ---

echo "Création du fichier de configuration Apache pour $DOMAIN_NAME (HTTP)..."
sudo tee "$APACHE_CONF" > /dev/null <<EOF
<VirtualHost *:80>
	ServerAdmin $SERVER_ADMIN

	ServerName  $DOMAIN_NAME

	DocumentRoot $WEB_ROOT
	<Directory $WEB_ROOT>
		AllowOverride None
		Order Allow,Deny
		Allow from All

		<IfModule mod_rewrite.c>
			Options -MultiViews
			RewriteEngine On

			RewriteCond %{REQUEST_FILENAME} !-f
			RewriteRule ^(.*)$ index.html [QSA,L]
		</IfModule>
	</Directory>

	ErrorLog /var/log/apache2/${DOMAIN_NAME}_error.log
	CustomLog /var/log/apache2/${DOMAIN_NAME}_access.log combined
</VirtualHost>
EOF

# Activer le site et redémarrer Apache
echo "Activation du site $DOMAIN_NAME..."
sudo a2ensite "$DOMAIN_NAME.conf"

echo "Redémarrage du service Apache pour prendre en compte le VirtualHost HTTP..."
sudo systemctl restart apache2

# --- Étape 2 : Obtenir les certificats SSL avec Certbot ---

echo "Exécution de Certbot pour obtenir un certificat SSL pour $DOMAIN_NAME..."
sudo certbot --apache -d "$DOMAIN_NAME" --agree-tos --no-eff-email -m "$SERVER_ADMIN"

# Vérifier si Certbot a réussi
if [ ! -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" ]; then
    echo "Erreur : Certbot n'a pas pu obtenir les certificats. Veuillez vérifier les logs."
    exit 1
fi

# --- Étape 3 : Créer la configuration SSL avec redirection ---

echo "Création du fichier de configuration Apache pour $DOMAIN_NAME (HTTPS) avec redirection..."
sudo tee "$APACHE_SSL_CONF" > /dev/null <<EOF
<VirtualHost *:80>
	ServerName  $DOMAIN_NAME

	DocumentRoot /var/www/$DOMAIN_NAME
	<IfModule mod_rewrite.c>
		Options -MultiViews
		RewriteEngine On		# Redirect http to https (only after configurate the SSL)
		RewriteCond %{SERVER_NAME} =$DOMAIN_NAME
		RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]
	</IfModule>
</VirtualHost>
<IfModule mod_ssl.c>
<VirtualHost *:443>
	ServerAdmin $SERVER_ADMIN

	ServerName  $DOMAIN_NAME

	DocumentRoot $WEB_ROOT
	<Directory $WEB_ROOT>
		AllowOverride None
		Order Allow,Deny
		Allow from All

		<IfModule mod_rewrite.c>
			Options -MultiViews
			RewriteEngine On

			RewriteCond %{REQUEST_FILENAME} !-f
			RewriteRule ^(.*)$ index.html [QSA,L]
		</IfModule>
	</Directory>

	ErrorLog /var/log/apache2/${DOMAIN_NAME}_error.log
	CustomLog /var/log/apache2/${DOMAIN_NAME}_access.log combined
	SSLCertificateFile /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
	SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
	Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
EOF

# Activer le VirtualHost SSL et désactiver l'HTTP
echo "Activation du site SSL $DOMAIN_NAME et désactivation de la configuration HTTP temporaire..."
sudo a2ensite "$DOMAIN_NAME-le-ssl.fr.conf"
sudo a2dissite "$DOMAIN_NAME.conf"

# Redémarrage final d'Apache
echo "Redémarrage final du service Apache pour prendre en compte tous les changements..."
sudo systemctl restart apache2

echo "Félicitations ! Le nouveau VirtualHost pour $DOMAIN_NAME est configuré avec SSL et la redirection HTTP vers HTTPS."