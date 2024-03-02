# Installation des prérequis
sudo apt update sudo apt -y upgrade

# Etape 1 : Installation des packages nécessaires
sudo apt install php apache2 php8.1-fpm freeradius libapache2-mod-php mariadb-server freeradius-mysql freeradius-utils php-{gd,common,mail,mail-mime,mysql,pear,db,mbstring,xml,curl} -y

sudo mysql_secure_installation
# Voici ce qu’on a  répondu lors de l'installation, en fonction de nos besoins de sécurité, On peut  définir un mot de passe root aussi.
Enter current password for root (enter for none): enter

Switch to unix_socket authentication [Y/n] n

Change the root password? [Y/n] n

Remove anonymous users? [Y/n] y

Disallow root login remotely? [Y/n] y

Remove test database and access to it? [Y/n] y

Reload privilege tables now? [Y/n] y


# Etape 2 : Configuration de MariaDB
sudo mysql -u root -p {mot de passe}

# 1-Créer la base de données
CREATE DATABASE radius;

# 2-Créer un utilisateur pour FreeRadius
CREATE USER 'radius'@'localhost' IDENTIFIED by 'PASSWORD';

# 3-Donner les autorisations à l'utilisateur
#Pour accorder les privilèges, On exécute cette commande :
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
# Enfin, On exécute ces commandes pour recharger les privilèges dans la base de données SQL et quitter la session.
FLUSH PRIVILEGES;
quit;

# Pour terminer la configuration de la base de données, nous devons la connecter à FreeRadius. Pour indiquer à FreeRadius que nous utiliserons SQL pour nos connexions, pour cela, On exécute ces commandes ci-dessous une par une.
sudo su -
mysql -u root -p radius < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
exit
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/


# Vérifions  la tables créé: 
sudo mysql -u root -p -e "use radius; show tables;" 

#Ensuite, nous devons activer et démarrer Apache2 ainsi qu' activer FreeRadius. On peut le faire comme suite. 
sudo systemctl enable --now apache2 && sudo systemctl enable freeradius

#On Crée un lien symbolique pour le module SQL sous /etc/freeradius/3.0/mods-enabled/ 
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/ 

#Configurez le module SQL et modifiez les paramètres de connexion à la base de données en fonction de votre environnement. 
sudo nano  /etc/freeradius/3.0/mods-enabled/sql 

#Etape 3 : Indiquer à FreeRadius la connexion SQL
#Maintenant que FreeRadius et le serveur SQL sont connectés, nous devons fournir à FreeRadius la connexion au serveur SQL, ainsi que modifier quelques paramètres. 
sudo nano /etc/freeradius/3.0/mods-enabled/sql

#Il y a quelques éléments qu’ on doit modifier avant de se connecter. Voici les éléments qui doivent être modifiés. Il faut faire défiler et apporter les modifications nécessaires.
driver = "rlm_sql_null" doit être driver = "rlm_sql_${dialect}"
dialect = "sqlite" #doit être dialect = "mysql"
read_clients = yes #doit être décommenté (Non # devant cette ligne)
client_table = « nas » #doit être décommenté (pas de # devant cette ligne)

#Ainsi que dans  cette section on commente tous les paramètres TLS pour que cela ressemble à ceci :

#On peut  maintenant entrer dans la connexion. Recherchez la section qui ressemble à ceci :
#On décommente les lignes indiquant serveur, port, identifiant et mot de passe. (Remarque : décommenter signifie supprimer le #). Entrez dans votre rayon le mot de passe utilisateur pour votre base de données SQL dans le « » où il est écrit « radpass »

#On change les paramètre: 
server=”localhost” 
password=”un mot de passe simple”
#Pour enregistrer les modifications, sur clavier, on clique sur ctrl x, y , suivi de enter .


#Etape 4 : Fin de la configuration de FreeRadius
#On  change le droit de groupe de /etc/freeradius/3.0/mods-enabled/sql 
sudo chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
sudo chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql
sudo systemctl restart freeradius

#Configuration du fichier “clients.conf”
#Ce fichier (clients.conf) spécifie les clients autorisés à se connecter à votre serveur FreeRadius.
#Accéder au fichier comme suite:
su - root
cd  /etc/freeradius/3.0
nano client.config
#Puis copier coller les configuration suivantes et définissons le code secret et le shortname:
client localhost {
    secret = mysecret
    shortname = client1
}

#Configuration du fichier “users”
#Ce fichier contient les informations d'identification des utilisateurs autorisés à se connecter.
#On y accède comme suite en tant que superuser.
nano /etc/freeradius/3.0/user
#On  modifie "john" par un nom et on donne un mot de passe simple comme " passer123"
#pour le test.
john Cleartext-Password := "password123"
    Service-Type = Framed-User,
    Framed-Protocol = PPP

#Configuration du fichier “radiusd.conf”
#Ce fichier est le fichier de configuration principal de FreeRadius. Il comprend de nombreuses configurations générales pour le serveur.
#On y accède comme suite.
nano /etc/freeradius/3.0/radiusd.conf

#On copie-colle cette configuration dans le fichier "radiusd.conf"
log {
    destination = files
    file = /var/log/freeradius/radius.log
    syslog_facility = daemon
    stripped_names = no
    auth = no
    auth_badpass = no
    auth_goodpass = no
}

security {
    max_attributes = 200
    reject_delay = 1
    status_server = yes
}

#On redémarre le service Freeradius : 
sudo systemctl restart freeradius.service 


#2- Connexion au serveur Radius

#Test de connexion au serveur FreeRadius
#Pour le test de connexion FreeRadius,On utilise l'outil en ligne de commande `radtest` ou `radclient`. Voici comment On procéder avec `radtest` :

radtest john password123 127.0.0.1 0 testing123

#Username : Nom d'utilisateur à tester.
#Password : Mot de passe correspondant à l'utilisateur.
#Radius-server[:port] : Adresse IP ou nom de domaine du serveur FreeRadius, suivi éventuellement du port (généralement 1812 pour l'authentification, 1813 pour l'autorisation/accounting).
#NAS-port-number : Numéro du port NAS (Access-Request).
#Secret : Le secret partagé entre le client et le serveur, configuré dans `clients.conf`.

#Syntaxe Exemple 
radtest john password123 127.0.0.1 0 testing123

#127.0.0.1  : est l'adresse IP du serveur FreeRadius.
#0 : est le NAS-port-number (Access-Request).
#testing123 : est le secret partagé.


