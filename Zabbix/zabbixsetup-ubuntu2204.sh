### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Zabbix/zabbixsetup-ubuntu2204.sh | sudo bash

#####Variables#########

secrets_url=https://keyvaultstorage227.blob.core.windows.net/blob-zabbixsecrets/zabbixsecrets.txt
time_zone=America/New_York
swap_file_size=1G
mysql_root_password=
mysql_zabbix_password=
letsencrypt_email=
letsencrypt_domain=

#######General#############

# Open the following ports in Azure: 22, 80, 443, 10050, 10051

# Set Time Zone to America/New_York

sudo timedatectl set-timezone $time_zone

# Set up swap file and enable

sudo fallocate -l $swap_file_size /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile

# Use crontab to add the swap file to reenable at reboot by adding the following line

echo "@reboot azureuser sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile" | sudo tee -a /etc/crontab

# Change Ubuntu needrestart behavior so that it does not restart daemons, so as to not freeze up the script

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# Install Azure CLI

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure using the VM's user assigned managed identity

az login --identity

# Download zabbixsecrets.txt file from private blob storage, authenticated using VM's user managed identity

az storage blob download --blob-url $secrets_url --file zabbixsecrets.txt

# Add zabbixsecrets.txt as a source, to pull in the variables contained within

source zabbixsecrets.txt

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

#######Install Zabbix#######

# Install Zabbix Repo

sudo wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-3+ubuntu22.04_all.deb && sudo dpkg -i zabbix-release_6.0-3+ubuntu22.04_all.deb && sudo apt update

# Install Zabbix server, frontend, agent

sudo apt-get install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent -y

# Install mySQL server

sudo apt-get install mysql-server -y

# Edit MySQL config file to disable binary logging (to prevent log files from getting too large)

echo -e "[mysqld]\n\nskip-log-bin" | sudo tee -a /etc/init/mysql.conf

# Set root password to mySQL

sudo mysqladmin -u root password $mysql_root_password

# Create database named zabbix, user zabbix, and password specified at start of script

sudo mysql -uroot -p$mysql_root_password -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;create user zabbix@localhost identified by '$mysql_zabbix_password';grant all privileges on zabbix.* to zabbix@localhost;SET GLOBAL log_bin_trust_function_creators = 1;"

# Import schema into Zabbix database (may appear to hang, be patient)

sudo zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p$mysql_zabbix_password zabbix

# Copy database password into zabbix config file

sudo sed -i "s/# DBPassword=/DBPassword=$mysql_zabbix_password/g" "/etc/zabbix/zabbix_server.conf"

# Start Zabbix server and agent processes

sudo systemctl restart zabbix-server zabbix-agent apache2

sudo systemctl enable zabbix-server zabbix-agent apache2

# Install Let's Encrypt certificate for frontend

# sudo apt-get install certbot python3-certbot-apache -y

# sudo certbot --apache -m $letsencrypt_email --agree-tos --non-interactive -d $letsencrypt_domain

# Point Apache directly to /usr/share/zabbix so that your FQDN takes you
# directly to the Zabbix interface

# sudo sed -i 's#DocumentRoot /var/www/html#DocumentRoot /usr/share/zabbix#g' /etc/apache2/sites-available/000-default-le-ssl.conf

# sudo systemctl restart apache2

# You should be able to log in to web interface by going to your FQDN
# Default u: Admin  p: zabbix


# To Backup MySql database and config files every night

sudo mkdir /backup/ && sudo chmod 777 /backup/

echo '00 02 * * * azureuser sudo mysqldump --no-tablespaces -uzabbix -p'$mysql_zabbix_password' zabbix | sudo gzip -c > /backup/ZabbixSQLBackup.`date +\%a`.sql.gz' | sudo tee -a /etc/crontab

echo '00 02 * * * azureuser sudo tar -zcf /backup/ZabbixConfigBackup.`date +\%a`.tar.gz -C /etc/zabbix/ .' | sudo tee -a /etc/crontab
