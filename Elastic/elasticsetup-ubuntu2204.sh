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

# Write managed identity id to the system profile so it becomes an available variable for future logins for any user

echo "export managed_identity_id=$managed_identity_id" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_id" | sudo tee -a /home/azureuser/.bashrc

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

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get update && sudo apt-get install elasticsearch -y

# Disable xpack security features

sudo sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/g' /etc/elasticsearch/elasticsearch.yml

# Start Elasticsearch service and set to start after reboot

sudo /bin/systemctl daemon-reload && sudo /bin/systemctl start elasticsearch.service && sudo /bin/systemctl enable elasticsearch.service

# To reset password of built-in elastic account
# sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
#
# To confirm Elasticsearch is running (login with elastic password)
# sudo curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic https://localhost:9200

##################
# Install Kibana #
##################

sudo apt-get install kibana -y

# Edit Kibana config to allow connections from remote hosts

sudo sed -i 's/#server.host: "localhost"/server.host: 0.0.0.0/g' /etc/kibana/kibana.yml

# Enable and start Kibana

sudo systemctl enable kibana && sudo systemctl start kibana

# Download IPTables, forward port 80 to 5601 for Kibana GUI

# sudo apt install iptables

# sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 5601

# Re-enable iptables routing after reboots by adding it to crontab

# echo "@reboot root iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 5601" | sudo tee -a /etc/crontab

# To generate new enrollment token to connect with Elasticsearch
# sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana

# Install Caddy & set to reverse proxy HTTPS to Kibana

# sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
# sudo apt update
# sudo apt install caddy
# sudo caddy reverse-proxy --from tabulaelastic.eastus.cloudapp.azure.com --to 127.0.0.1:5601
# echo "sudo caddy reverse-proxy --from tabulaelastic.eastus.cloudapp.azure.com --to 127.0.0.1:5601" | sudo tee -a /etc/crontab

# To Backup MySql database and config files every night

# sudo mkdir /backup/ && sudo chmod 777 /backup/

# echo '00 02 * * * azureuser sudo mysqldump --no-tablespaces -uzabbix -p'$mysql_zabbix_password' zabbix | sudo gzip -c > /backup/ZabbixSQLBackup.`date +\%a`.sql.gz' | sudo tee -a /etc/crontab

# echo '00 02 * * * azureuser sudo tar -zcf /backup/ZabbixConfigBackup.`date +\%a`.tar.gz -C /etc/zabbix/ .' | sudo tee -a /etc/crontab
