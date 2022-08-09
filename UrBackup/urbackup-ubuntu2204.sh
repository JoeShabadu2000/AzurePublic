### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/urbackup-ubuntu2204.sh | bash

#####Variables#########

managed_identity_clientid=$1
time_zone=$2
keyvault_name=$3

#######General#############

# Open the following ports in Azure: 22, 80, 443, 35622, 55413-55415

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
export keyvault_name=$keyvault_name
export dns_rg_id=$dns_rg_id" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_clientid" | sudo tee -a /home/azureuser/.bashrc

# Pull secrets from Azure Keyvault

# ssl_cert_name=$(az keyvault secret show --name ssl-cert-name --vault-name $keyvault_name --query "value" --output tsv)

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

# Connect to Azure File Share

sudo mkdir /mnt/fileshare-urbackup
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/storageurbackup.cred" ]; then
    sudo bash -c 'echo "username=storageurbackup" >> /etc/smbcredentials/storageurbackup.cred'
    sudo bash -c 'echo "password=RtCbHPS+S9mOm/BQ4RBD5MY2hzut4oagaibQ1S2GisL+g9h4QYzNVUXeoSMlXezP3JbNk6hu1HVp+AStls2YUg==" >> /etc/smbcredentials/storageurbackup.cred'
fi
sudo chmod 600 /etc/smbcredentials/storageurbackup.cred

sudo bash -c 'echo "//storageurbackup.file.core.windows.net/fileshare-urbackup /mnt/fileshare-urbackup cifs nofail,credentials=/etc/smbcredentials/storageurbackup.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab'
sudo mount -t cifs //storageurbackup.file.core.windows.net/fileshare-urbackup /mnt/fileshare-urbackup -o credentials=/etc/smbcredentials/storageurbackup.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30



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