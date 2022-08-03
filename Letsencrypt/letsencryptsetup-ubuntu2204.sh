### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/elasticsetup-ubuntu2204.sh | bash

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

#######################
# Generate Cert & Key #
#######################

az keyvault certificate create --name $ssl_cert_name
{
    "policy": {
        "x509_props": {
          "subject": "CN=trstringer.com"
        },
        "issuer": {
          "name": "Unknown"
        }
    }
}