### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/elasticsetup-ubuntu2204.sh | bash

#####Variables#########

managed_identity_id=$1
time_zone=$2
swap_file_size=$3
keyvault_name=$4
mysql_root_password=
mysql_zabbix_password=
letsencrypt_email=
letsencrypt_domain=

#######General#############

# Open the following ports in Azure: 22, 80, 443, 5140

# Set Time Zone

sudo timedatectl set-timezone $time_zone

# Set up swap file and enable

sudo fallocate -l $swap_file_size /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile

# Use crontab to add the swap file to reenable at reboot by adding the following line

echo "@reboot azureuser sudo fallocate -l $swap_file_size /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile" | sudo tee -a /etc/crontab

# Change Ubuntu needrestart behavior so that it does not restart daemons, so as to not freeze up the setup script

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# Install Azure CLI

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure using the VM's user assigned managed identity

az login --identity -u $managed_identity_id

# Pull secrets from Azure Keyvault (the sed section is to strip first and last characters (quotes) from the JSON output)

# mysql_root_password=$(az keyvault secret show --name mysql-root-password --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# mysql_zabbix_password=$(az keyvault secret show --name mysql-zabbix-password --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# letsencrypt_email=$(az keyvault secret show --name letsencrypt-email --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# letsencrypt_domain=$(az keyvault secret show --name letsencrypt-domain --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

#########################
# Install Elasticsearch #
#########################

# Install Open Java JDK & Nginx

# sudo apt-get install default-jre default-jdk nginx -y

# Install Elasticsearch

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get update && sudo apt-get install elasticsearch -y

sudo /bin/systemctl daemon-reload

sudo /bin/systemctl start elasticsearch.service

sudo /bin/systemctl enable elasticsearch.service










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

# sudo mkdir /backup/ && sudo chmod 777 /backup/

# echo '00 02 * * * azureuser sudo mysqldump --no-tablespaces -uzabbix -p'$mysql_zabbix_password' zabbix | sudo gzip -c > /backup/ZabbixSQLBackup.`date +\%a`.sql.gz' | sudo tee -a /etc/crontab

# echo '00 02 * * * azureuser sudo tar -zcf /backup/ZabbixConfigBackup.`date +\%a`.tar.gz -C /etc/zabbix/ .' | sudo tee -a /etc/crontab
