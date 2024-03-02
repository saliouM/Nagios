## Étape 1: Mise à jour des packages système
```markdown

```bash
sudo apt update
sudo apt -y upgrade
```

## Étape 2: Installation des packages nécessaires

```bash
sudo apt install php apache2 php8.1-fpm freeradius libapache2-mod-php mariadb-server freeradius-mysql freeradius-utils php-{gd,common,mail,mail-mime,mysql,pear,db,mbstring,xml,curl} -y
```

Après l'installation, configurez le serveur SQL (dans ce cas, le serveur MariaDB).

```bash
sudo mysql_secure_installation
```

Répondez aux questions de l'installation en fonction de vos besoins de sécurité.

## Étape 3: Configuration de MariaDB

Connectez-vous à MariaDB et effectuez les opérations nécessaires.

```bash
sudo mysql -u root -p {mot de passe}
```

Exécutez les commandes SQL pour créer la base de données, un utilisateur pour FreeRadius et accorder les autorisations nécessaires.

```sql
CREATE DATABASE radius;
CREATE USER 'radius'@'localhost' IDENTIFIED by 'PASSWORD';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
FLUSH PRIVILEGES;
quit;
```

Continuez avec la configuration de la base de données pour FreeRadius.

```bash
sudo su -
mysql -u root -p radius < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
exit
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
```

Vérifiez la table créée.

```bash
sudo mysql -u root -p -e "use radius; show tables;"
```

Activez Apache2 et FreeRadius.

```bash
sudo systemctl enable --now apache2 && sudo systemctl enable freeradius
```

Créez un lien symbolique pour le module SQL.

```bash
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
```

Configurez le module SQL.

```bash
sudo nano /etc/freeradius/3.0/mods-enabled/sql
```

## Étape 4: Configuration de FreeRadius

Changez les droits du fichier SQL.

```bash
sudo chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
sudo chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql
sudo systemctl restart freeradius
```

## Configuration des fichiers de clients et d'utilisateurs

Consultez les fichiers "client.conf" et "user" pour configurer les clients autorisés et les utilisateurs.

```bash
su - root
cd /etc/freeradius/3.0
nano clients.conf
nano users
```

## Configuration de "radiusd.conf"

Modifiez le fichier de configuration principal de FreeRadius.

```bash
nano /etc/freeradius/3.0/radiusd.conf
```

Redémarrez le service FreeRadius.

```bash
sudo systemctl restart freeradius.service
```

# Connexion au serveur Radius

## Test de connexion FreeRadius

Utilisez l'outil `radtest` pour tester la connexion.

```bash
radtest john password123 127.0.0.1 0 testing123
```

- Username: Nom d'utilisateur à tester.
- Password: Mot de passe correspondant à l'utilisateur.
- Radius-server[:port]: Adresse IP ou nom de domaine du serveur FreeRadius, suivi éventuellement du port (généralement 1812 pour l'authentification, 1813 pour l'autorisation/accounting).
- NAS-port-number: Numéro du port NAS (Access-Request).
- Secret: Le secret partagé entre le client et le serveur, configuré dans `clients.conf`.
```
