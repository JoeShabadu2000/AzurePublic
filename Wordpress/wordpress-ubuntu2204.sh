### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/unifi-ubuntu2204.sh | bash

#####Variables#########

managed_identity_clientid=$1
time_zone=$2
keyvault_name=$3
admin_username=$4

# Write variables to the system profile so they become available for future logins for any user

echo "export managed_identity_clientid=$managed_identity_clientid
time_zone=$time_zone
export keyvault_name=$keyvault_name
export admin_username=$admin_username" | sudo tee -a /etc/profile

##########################
# General Setup / PreReq #
##########################

# Open the following ports in Azure: 22, 80, 443, 3478, 8080, 8443

# Set Time Zone & VIM Colorscheme

sudo timedatectl set-timezone $time_zone && echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

# Set swap file size to equal system memory size, and enable (swapfile is on Azure Temp Drive sdb1 /mnt/)

swap_file_size=$(grep MemTotal /proc/meminfo | awk '{print $2}')K

sudo fallocate -l $swap_file_size /mnt/swapfile && sudo chmod 600 /mnt/swapfile && sudo mkswap /mnt/swapfile && sudo swapon /mnt/swapfile

# Use crontab to add the swap file to reenable at reboot by adding the following line

echo "@reboot $admin_username sudo fallocate -l $swap_file_size /mnt/swapfile && sudo chmod 600 /mnt/swapfile && sudo mkswap /mnt/swapfile && sudo swapon /mnt/swapfile" | sudo tee -a /etc/crontab

# Change Ubuntu needrestart behavior so that it does not restart daemons, so as to not freeze up the setup script

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# Install system updates

sudo apt-get update && sudo apt-get upgrade -y

# Install Docker

curl -fsSL https://get.docker.com -o ./get-docker.sh && sudo sh ./get-docker.sh

######################################
# Install Azure CLI Docker Container #
######################################

# Make directory to store Azure CLI login credentials

sudo mkdir /home/$admin_username/.azure

# Create "az" alias to allow for az to be run from command line, and add alias to /etc/profile for future logins

alias az="sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az "

echo "alias az='sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az '" | sudo tee -a /etc/profile

# Pull Azure CLI Docker image

sudo docker pull mcr.microsoft.com/azure-cli:2.39.0

# Login to Azure using the VM's user assigned managed identity

sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az login --identity -u $managed_identity_clientid

# Edit .bashrc for $admin_username so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_clientid" | sudo tee -a /home/$admin_username/.bashrc

# Pull secrets from Azure Keyvault

ssl_cert_name=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name ssl-cert-name --vault-name $keyvault_name --query "value" --output tsv)
storageaccount_name=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name storageaccount-name --vault-name $keyvault_name --query "value" --output tsv)
storageaccount_rg=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name storageaccount-rg --vault-name $keyvault_name --query "value" --output tsv)
FQDN=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name FQDN --vault-name $keyvault_name --query "value" --output tsv)

# Write variables to the system profile so they become available for future logins for any user

echo "export ssl_cert_name=$ssl_cert_name
export storageaccount_name=$storageaccount_name
export storageaccount_rg=$storageaccount_rg
export FQDN=$FQDN" | sudo tee -a /etc/profile

###############################
# Connect to Azure File Share #
###############################

# # Retrieve storage account key #1

# storageaccount_key=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az storage account keys list --account-name $storageaccount_name --resource-group $storageaccount_rg --output tsv | awk 'NR==1{print $4}')

# # Create mount directory & credentials file to log into file share

# sudo mkdir /mnt/fileshare-unifi
# if [ ! -d "/etc/smbcredentials" ]; then
# sudo mkdir /etc/smbcredentials
# fi
# if [ ! -f "/etc/smbcredentials/$storageaccount_name.cred" ]; then
#     sudo bash -c 'echo "username='$storageaccount_name'" >> /etc/smbcredentials/'$storageaccount_name'.cred'
#     sudo bash -c 'echo "password='$storageaccount_key'" >> /etc/smbcredentials/'$storageaccount_name'.cred'
# fi
# sudo chmod 600 /etc/smbcredentials/$storageaccount_name.cred

# # Mount file share and update fstab so that it reconnects on reboot

# sudo bash -c 'echo "//tabulaunifistorage.file.core.windows.net/fileshare-unifi /mnt/fileshare-unifi cifs nofail,credentials=/etc/smbcredentials/'$storageaccount_name'.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab'
# sudo mount -t cifs //tabulaunifistorage.file.core.windows.net/fileshare-unifi /mnt/fileshare-unifi -o credentials=/etc/smbcredentials/$storageaccount_name.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

########################
# Install UniFi Docker #
########################

# Start Wordpress Docker Container

sudo docker run -d --init --restart=unless-stopped \
    --name wordpress \
    -p 8080:80 \
    -v /home/$admin_username/wordpress:/var/www/html \
    -e WORDPRESS_DB_HOST=mysql-wordpresstabula.mysql.database.azure.com \
    -e WORDPRESS_DB_USER=wordpressuser \
    -e WORDPRESS_DB_PASSWORD=q24TE#jrTA3Y38 \
    -e WORDPRESS_DB_NAME=wordpress \
    wordpress:6.0.1


####################################################
# Download New or Updated SSL Cert to use in Nginx #
####################################################

# Download .pfx file containing key and cert from Key Vault

sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret download --name $ssl_cert_name --vault-name $keyvault_name --file /root/ssl.pfx  --encoding base64

# Split .pfx file into separate key and certificate files

sudo openssl pkcs12 -in /home/$admin_username/ssl.pfx -clcerts -nokeys -out /etc/ssl/certs/ssl.crt -passin pass:
sudo openssl pkcs12 -in /home/$admin_username/ssl.pfx -noenc -nocerts -out /etc/ssl/private/ssl.key -passin pass:

# Remove .pfx file from local drive after cert and key files have been created

sudo rm /home/$admin_username/ssl.pfx

# Add line to /etc/crontab to download a new cert weekly and restart nginx (no downtime for nginx)

echo "0 0 * * 0 azureuser az login --identity -u $managed_identity_clientid && az keyvault secret download --name $ssl_cert_name --vault-name $keyvault_name --file /root/ssl.pfx  --encoding base64 && sudo openssl pkcs12 -in /home/$admin_username/ssl.pfx -clcerts -nokeys -out /etc/ssl/certs/ssl.crt -passin pass: && sudo openssl pkcs12 -in /home/$admin_username/ssl.pfx -noenc -nocerts -out /etc/ssl/private/ssl.key -passin pass: && sudo rm /home/$admin_username/ssl.pfx && sudo systemctl restart nginx" | sudo tee -a /etc/crontab

#############################
# Install Nginx HTTPS Proxy #
#############################

# Install Nginx & update default config

sudo apt-get install nginx -y

echo "server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl.crt;
    ssl_certificate_key /etc/ssl/private/ssl.key;
    server_name $FQDN;
    access_log /var/log/nginx/nginx.vhost.access.log;
    error_log /var/log/nginx/nginx.vhost.error.log;
    location / {
        proxy_pass_header Authorization;
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}" | sudo tee -a /etc/nginx/sites-available/default

# Redirect HTTP to HTTPS & reload

sudo sed -i '25i return 301 https://$host$request_uri;' /etc/nginx/sites-available/default

sudo systemctl reload nginx

#################
# Setup Backups #
#################

# Modify /etc/crontab to upload Unifi autobackup folder to Azure blob storage every night

# echo "0 0 * * * azureuser az storage blob upload-batch --auth-mode login --overwrite false --destination blob-unifibackup --account-name tabulaunifibackup --source /root/unifi/data/backup/autobackup" | sudo tee -a /etc/crontab


