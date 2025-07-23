#!/bin/bash

# Vérifier si le domaine a été fourni en argument
if [ -z "$1" ]; then
    echo "Usage: $0 <nom_de_domaine>"
    exit 1
fi

DOMAIN_NAME=$1
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN_NAME.conf"
APACHE_SSL_CONF="/etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.conf"
WEB_ROOT="/var/www/$DOMAIN_NAME"
SERVER_ADMIN="officiel@tyrolium.fr"

# Créer le répertoire de la racine du site web
echo "Création du répertoire $WEB_ROOT..."
sudo mkdir -p "$WEB_ROOT"
sudo chown -R $USER:$USER "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

# Créer un fichier index.html par défaut
echo "Création d'un fichier index.html par défaut..."
echo "<h1>Bienvenue sur $DOMAIN_NAME !</h1>" | sudo tee "$WEB_ROOT/index.html" > /dev/null

# Créer le fichier de configuration VirtualHost pour HTTP
echo "Création du fichier de configuration Apache pour $DOMAIN_NAME (HTTP)..."
sudo tee "$APACHE_CONF" > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin $SERVER_ADMIN
    ServerName $DOMAIN_NAME
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

# Activer le site
echo "Activation du site $DOMAIN_NAME..."
sudo a2ensite "$DOMAIN_NAME.conf"

# Redémarrer Apache pour prendre en compte le nouveau VirtualHost
echo "Redémarrage du service Apache..."
sudo systemctl restart apache2

# Obtenir un certificat SSL avec Certbot
echo "Exécution de Certbot pour obtenir un certificat SSL pour $DOMAIN_NAME..."
sudo certbot --apache -d "$DOMAIN_NAME" --agree-tos --no-eff-email -m "$SERVER_ADMIN"

# Vérifier si Certbot a créé la configuration SSL et modifier le fichier HTTP pour la redirection
if [ -f "$APACHE_SSL_CONF" ]; then
    echo "Certbot a créé la configuration SSL. Modification du fichier HTTP pour la redirection..."
    # On modifie le VirtualHost initial pour y ajouter la redirection
    sudo sed -i '/<VirtualHost \*:80>/,/<\/VirtualHost>/ {
        /<VirtualHost \*:80>/! {
            /ServerName/! {
                /DocumentRoot/! {
                    /Directory/! {
                        /ErrorLog/! {
                            /CustomLog/! {
                                /ServerAdmin/! {
                                    /AllowOverride/! {
                                        /Order Allow,Deny/! {
                                            /Allow from All/! {
                                                /<IfModule mod_rewrite.c>/! {
                                                    /Options -MultiViews/! {
                                                        /RewriteEngine On/! {
                                                            /RewriteCond %{REQUEST_FILENAME} !-f/! {
                                                                /RewriteRule ^(.*)$ index.html \[QSA,L\]/! {
                                                                    /<\/IfModule>/! {
                                                                        /<\/Directory>/! {
                                                                            /ServerAdmin officiel@tyrolium.fr/! {
                                                                                a\
        RewriteEngine On\
        RewriteCond %{SERVER_NAME} ='$DOMAIN_NAME'\
        RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }' "$APACHE_CONF"

    # Supprimer le fichier de configuration SSL créé par Certbot si on veut tout centraliser dans le fichier initial
    # echo "Suppression du fichier de configuration SSL de Certbot (optionnel)..."
    # sudo rm "$APACHE_SSL_CONF"

    # Pour l'exemple, on va simplement redémarrer Apache
    echo "Redémarrage final du service Apache..."
    sudo systemctl restart apache2
    echo "Le nouveau VirtualHost pour $DOMAIN_NAME est prêt avec la redirection HTTPS !"
else
    echo "Erreur : Certbot n'a pas pu créer la configuration SSL. Veuillez vérifier les logs."
fi