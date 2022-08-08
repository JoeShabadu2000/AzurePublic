### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/letsencryptrenew-ubuntu2204.sh | bash

#####Variables#########

managed_identity_clientid=$1
time_zone=$2
keyvault_name=$3
ssl_cert_name=$4
dns_rg_id=$5

#######General#############

# Open the following ports in Azure: 22, 80, 443

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

# Write managed identity id & ssl cert name to the system profile so it becomes an available variable for future logins for any user

echo "export managed_identity_clientid=$managed_identity_clientid
export ssl_cert_name=$ssl_cert_name
export keyvault_name=$keyvault_name
export dns_rg_id=$dns_rg_id" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_clientid" | sudo tee -a /home/azureuser/.bashrc

# Pull secrets from Azure Keyvault

# dns_root_zone is the name of your managed DNS zone in Azure (example.com)
dns_root_zone=$(az keyvault secret show --name dns-root-zone --vault-name $keyvault_name --query "value" --output tsv)

# FQDN is the full name of the subdomain you are requesting a cert for (www.example.com)
# For wildcard use *.example.com
FQDN=$(az keyvault secret show --name FQDN --vault-name $keyvault_name --query "value" --output tsv)

# letsencrypt_email=$(az keyvault secret show --name letsencrypt-email --vault-name $keyvault_name --query "value" --output tsv)

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

#######################
# Generate Cert & Key #
#######################

# Generate Certificate Request through Keyvault

az keyvault certificate create --vault-name $keyvault_name --name $ssl_cert_name --policy '{"x509CertificateProperties": {"subject":"CN='$FQDN'"},"issuerParameters": {"name": "Unknown"}}'

# Retrieve CSR file that needs to be sent to certificate authority

az keyvault certificate pending show --vault-name $keyvault_name --name $ssl_cert_name --query csr -o tsv | sudo tee ./cert.csr

# Modify CSR File for Letsencrypt

sed -i '1 s/^/-----BEGIN CERTIFICATE REQUEST-----\n/' ./cert.csr

echo "-----END CERTIFICATE REQUEST-----" | sudo tee -a ./cert.csr

# Install certbot and pip, use pip to install certbot Azure DNS plugin

sudo apt-get install certbot pip -y && sudo pip install certbot certbot-dns-azure

# Create config file for Azure DNS plugin

echo "dns_azure_msi_client_id = $managed_identity_clientid
dns_azure_zone = $dns_root_zone:$dns_rg_id" | sudo tee ./azuredns.ini

sudo chmod 600 ./azuredns.ini

# Start Certbot

# sudo certbot certonly --authenticator dns-azure --dns-azure-config ./azuredns.ini --csr ./cert.csr --preferred-challenges dns -n --agree-tos -m $letsencrypt_email -d $FQDN

sudo certbot certonly --authenticator dns-azure --dns-azure-config ./azuredns.ini --csr ./cert.csr --preferred-challenges dns -n --agree-tos --register-unsafely-without-email -d $FQDN

# Upload full certificate to keyvault

az keyvault certificate pending merge --vault-name $keyvault_name --name $ssl_cert_name --file ./0001_chain.pem

# To delete keys in Keyvault
# az keyvault certificate delete --vault-name $keyvault_name --name $ssl_cert_name
# az keyvault certificate purge --vault-name $keyvault_name --name $ssl_cert_name

# Download SSL cert for HTTPS from Key Vault

# az keyvault secret download --name $ssl_cert_name --vault-name $keyvault_name --file ./cert.pfx  --encoding base64

# Split full cert PEM file into separate key and certificate files

# sudo openssl pkcs12 -in ./cert.pfx -clcerts -nokeys -out /etc/ssl/certs/ssl.crt -passin pass:

# sudo openssl pkcs12 -in ./cert.pfx -noenc -nocerts -out /etc/ssl/private/ssl.key -passin pass:

# echo "server {
#     listen 443 ssl;
#     ssl_certificate /etc/ssl/certs/ssl.crt;
#     ssl_certificate_key /etc/ssl/private/ssl.key;
#     server_name www.tabulait.xyz;
#     access_log /var/log/nginx/nginx.vhost.access.log;
#     error_log /var/log/nginx/nginx.vhost.error.log;
#     location / {
#        root /var/www/html;
#        index index.html index.htm index.nginx-debian.html;
#    }
# }" | sudo tee -a /etc/nginx/sites-available/default