### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/letsencryptrenew-ubuntu2204.sh | bash

#####Variables#########

managed_identity_clientid=$1
time_zone=$2
keyvault_name=$3
dns_rg_id=$4
admin_username=$5

# Write managed identity id & ssl cert name to the system profile so it becomes an available variable for future logins for any user

echo "export managed_identity_clientid=$managed_identity_clientid
export keyvault_name=$keyvault_name
export dns_rg_id=$dns_rg_id
export admin_username=$admin_username" | sudo tee -a /etc/profile

##########################
# General Setup / PreReq #
##########################

# Open the following ports in Azure: 22, 80, 443

# Set Time Zone & VIM Colorscheme

sudo timedatectl set-timezone $time_zone && echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

# Set swap file size to equal system memory size, and enable (swapfile is on Azure Temp Drive sdb1 /mnt/)

swap_file_size=$(grep MemTotal /proc/meminfo | awk '{print $2}')K

sudo fallocate -l $swap_file_size /mnt/swapfile && sudo chmod 600 /mnt/swapfile && sudo mkswap /mnt/swapfile && sudo swapon /mnt/swapfile

# Use crontab to add the swap file to reenable at reboot by adding the following line

echo "@reboot $admin_username sudo fallocate -l $swap_file_size /mnt/swapfile && sudo chmod 600 /mnt/swapfile && sudo mkswap /mnt/swapfile && sudo swapon /mnt/swapfile" | sudo tee -a /etc/crontab

# Change Ubuntu needrestart behavior so that it does not restart daemons, so as to not freeze up the setup script

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

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

# dns_root_zone is the name of your managed DNS zone in Azure (example.com)
dns_root_zone=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name dns-root-zone --vault-name $keyvault_name --query "value" --output tsv)

# FQDN is the full name of the subdomain you are requesting a cert for (www.example.com)
# For wildcard use *.example.com
FQDN=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name FQDN --vault-name $keyvault_name --query "value" --output tsv)

# Name of the SSL cert in Azure
ssl_cert_name=$(sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault secret show --name ssl-cert-name --vault-name $keyvault_name --query "value" --output tsv)

#######################
# Generate Cert & Key #
#######################

# Generate Certificate Request through Keyvault

sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault certificate create --vault-name $keyvault_name --name $ssl_cert_name --policy '{"x509CertificateProperties": {"subject":"CN='$FQDN'"},"issuerParameters": {"name": "Unknown"}}'

# Retrieve CSR file that needs to be sent to certificate authority

sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault certificate pending show --vault-name $keyvault_name --name $ssl_cert_name --query csr -o tsv | sudo tee /home/$admin_username/cert.csr

# Modify CSR File for Letsencrypt

sed -i '1 s/^/-----BEGIN CERTIFICATE REQUEST-----\n/' /home/$admin_username/cert.csr

echo "-----END CERTIFICATE REQUEST-----" | sudo tee -a /home/$admin_username/cert.csr

# Install certbot and pip, use pip to install certbot Azure DNS plugin

sudo apt-get install certbot pip -y && sudo pip install certbot certbot-dns-azure

# Create config file for Azure DNS plugin

echo "dns_azure_msi_client_id = $managed_identity_clientid
dns_azure_zone = $dns_root_zone:$dns_rg_id" | sudo tee /home/$admin_username/azuredns.ini

sudo chmod 600 /home/$admin_username/azuredns.ini

# Start Certbot

sudo certbot certonly --authenticator dns-azure --dns-azure-config /home/$admin_username/azuredns.ini --csr /home/$admin_username/cert.csr --cert-path /home/$admin_username/ssl.pem --preferred-challenges dns -n --agree-tos --register-unsafely-without-email -d $FQDN

# Upload full certificate to keyvault

# sudo docker run -v /home/$admin_username/.azure:/root/.azure -v /home/$admin_username:/root mcr.microsoft.com/azure-cli:2.39.0 az keyvault certificate pending merge --vault-name $keyvault_name --name $ssl_cert_name --file /root/0002_chain.pem

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