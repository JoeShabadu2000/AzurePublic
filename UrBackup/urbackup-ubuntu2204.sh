### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/urbackup-ubuntu2204.sh | bash

#####Variables#########

managed_identity_clientid=$1
time_zone=$2
keyvault_name=$3

#######General#############

# Open the following ports in Azure: 22, 80, 443, 55415

# Set Time Zone

sudo timedatectl set-timezone $time_zone

# Set swap file size to equal system memory size, and enable

swap_file_size=$(grep MemTotal /proc/meminfo | awk '{print $2}')K

sudo fallocate -l $swap_file_size /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile

# Use crontab to add the swap file to reenable at reboot by adding the following line

echo "@reboot azureuser sudo fallocate -l $swap_file_size /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile" | sudo tee -a /etc/crontab

# Change Ubuntu needrestart behavior so that it does not restart daemons, so as to not freeze up the setup script

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# Install Azure CLI

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure using the VM's user assigned managed identity

az login --identity -u $managed_identity_clientid

# Write variables to the system profile so they become available for future logins for any user

echo "export managed_identity_clientid=$managed_identity_clientid
export keyvault_name=$keyvault_name" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_clientid" | sudo tee -a /home/azureuser/.bashrc

# Pull secrets from Azure Keyvault

ssl_cert_name=$(az keyvault secret show --name ssl-cert-name --vault-name $keyvault_name --query "value" --output tsv)
storage_account_name=$(az keyvault secret show --name storage-account-name --vault-name $keyvault_name --query "value" --output tsv)
storage_account_rg=$(az keyvault secret show --name storage-account-rg --vault-name $keyvault_name --query "value" --output tsv)

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

###############################
# Connect to Azure File Share #
###############################

# Retrieve storage account key #1

storage_account_key=$(az storage account keys list --account-name $storage_account_name --resource-group $storage_account_rg --output tsv | awk 'NR==1{print $4}')

# Create mount directory & credentials file to log into file share

sudo mkdir /mnt/fileshare-urbackup
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/storageurbackup.cred" ]; then
    sudo bash -c 'echo "username='$storage_account_name'" >> /etc/smbcredentials/'$storage_account_name'.cred'
    sudo bash -c 'echo "password='$storage_account_key'" >> /etc/smbcredentials/'$storage_account_name'.cred'
fi
sudo chmod 600 /etc/smbcredentials/$storage_account_name.cred

# Mount file share and update fstab so that it reconnects on reboot

sudo bash -c 'echo "//storageurbackup.file.core.windows.net/fileshare-urbackup /mnt/fileshare-urbackup cifs nofail,credentials=/etc/smbcredentials/'$storage_account_name'.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab'
sudo mount -t cifs //storageurbackup.file.core.windows.net/fileshare-urbackup /mnt/fileshare-urbackup -o credentials=/etc/smbcredentials/$storage_account_name.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

####################
# Install UrBackup #
####################

# Install Docker

curl -fsSL https://get.docker.com -o ./get-docker.sh && sudo sh ./get-docker.sh

# Start UrBackup Docker Container

sudo docker run -d --restart unless-stopped --name urbackup-server-1 -v /mnt/fileshare-urbackup/backups:/backups -v /var/urbackup:/var/urbackup -p 55413-55415:55413-55415 -p 35623:35623/udp uroni/urbackup-server

############################
# Extra Commands if Needed #
############################

# To delete keys in Keyvault
# az keyvault certificate delete --vault-name $keyvault_name --name $ssl_cert_name
# az keyvault certificate purge --vault-name $keyvault_name --name $ssl_cert_name


# To test if SSL certs are working

# Download SSL cert for HTTPS from Key Vault
# az keyvault secret download --name $ssl_cert_name --vault-name $keyvault_name --file ./cert.pfx  --encoding base64

# Split full cert PEM file into separate key and certificate files
# sudo openssl pkcs12 -in ./cert.pfx -clcerts -nokeys -out /etc/ssl/certs/ssl.crt -passin pass:
# sudo openssl pkcs12 -in ./cert.pfx -noenc -nocerts -out /etc/ssl/private/ssl.key -passin pass:

# Install Nginx & update default config & reload
# sudo apt-get install nginx -y

# echo "server {
#     listen 443 ssl;
#     ssl_certificate /etc/ssl/certs/ssl.crt;
#     ssl_certificate_key /etc/ssl/private/ssl.key;
#     server_name $FQDN;
#     access_log /var/log/nginx/nginx.vhost.access.log;
#     error_log /var/log/nginx/nginx.vhost.error.log;
#     location / {
#        root /var/www/html;
#        index index.html index.htm index.nginx-debian.html;
#    }
# }" | sudo tee -a /etc/nginx/sites-available/default

# sudo systemctl reload nginx

# Now try accessing your site via HTTPS