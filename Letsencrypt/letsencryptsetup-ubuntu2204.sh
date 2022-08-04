### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/letsencryptsetup-ubuntu2204.sh | bash

#####Variables#########

managed_identity_id=$1
time_zone=$2
swap_file_size=$3
keyvault_name=$4
ssl_cert_name=$5

#######General#############

# Open the following ports in Azure: 22, 80, 443

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

# Write managed identity id & ssl cert name to the system profile so it becomes an available variable for future logins for any user

echo "export managed_identity_id=$managed_identity_id
export ssl_cert_name=$ssl_cert_name
export keyvault_name=$keyvault_name" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_id" | sudo tee -a /home/azureuser/.bashrc

# Pull secrets from Azure Keyvault (the sed section is to strip first and last characters (quotes) from the JSON output)

FQDN=$(az keyvault secret show --name FQDN --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# mysql_zabbix_password=$(az keyvault secret show --name mysql-zabbix-password --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

letsencrypt_email=$(az keyvault secret show --name letsencrypt-email --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

# letsencrypt_domain=$(az keyvault secret show --name letsencrypt-domain --vault-name $keyvault_name --query "value" | sed -e 's/^.//' -e 's/.$//')

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

# Install and run certbot to obtain certificates

sudo apt-get install certbot -y

sudo certbot certonly --standalone --agree-tos -n -m $letsencrypt_email --csr ./cert.csr -d $FQDN

# Upload full certificate to keyvault

az keyvault certificate pending merge --vault-name $keyvault_name --name $ssl_cert_name --file ./0001_chain.pem

# To delete keys in Keyvault
# az keyvault certificate delete --vault-name $keyvault_name --name $ssl_cert_name
# az keyvault certificate purge --vault-name $keyvault_name --name $ssl_cert_name