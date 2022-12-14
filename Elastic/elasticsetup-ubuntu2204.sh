### Run this file inside the VM after it has been provisioned in Azure
### wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Elastic/elasticsetup-ubuntu2204.sh | bash

#####Variables#########

managed_identity_id=$1
time_zone=$2
keyvault_name=$3
admin_username=$4
ssl_cert_name=$5


#################
# General Setup #
#################

# Open the following ports in Azure: 22, 80, 443, 5140

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

az login --identity -u $managed_identity_id

# Write managed identity id to the system profile so it becomes an available variable for future logins for any user

echo "export managed_identity_id=$managed_identity_id
export ssl_cert_name=$ssl_cert_name
export keyvault_name=$keyvault_name" | sudo tee -a /etc/profile

# Edit .bashrc for azureuser so that it logs in to the managed identity any time the user is logged in

echo "az login --identity -u $managed_identity_id" | sudo tee -a /home/$admin_username/.bashrc

# Download SSL cert for HTTPS from Key Vault

az keyvault secret download --name $ssl_cert_name --vault-name $keyvault_name --file ./cert.pfx  --encoding base64

# Split full cert PEM file into separate key and certificate files

sudo openssl pkcs12 -in ./cert.pfx -clcerts -nokeys -out /etc/ssl/certs/ssl.crt -passin pass:

sudo openssl pkcs12 -in ./cert.pfx -noenc -nocerts -out /etc/ssl/private/ssl.key -passin pass:

# Pull secrets from Azure Keyvault

kibana_admin_username=$(az keyvault secret show --name kibana-admin-username --vault-name $keyvault_name --query "value" --output tsv)

kibana_admin_password=$(az keyvault secret show --name kibana-admin-password --vault-name $keyvault_name --query "value" --output tsv)

FQDN=$(az keyvault secret show --name FQDN --vault-name $keyvault_name --query "value" --output tsv)

# Install VIM & Curl & Midnight Commander & Rsync

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install vim curl mc rsync -y

# To change VIM color scheme settings

echo "colorscheme desert" | sudo tee -a /etc/vim/vimrc

#########################################
# Install Nginx for Reverse Proxy/HTTPS #
#########################################

sudo apt-get install nginx apache2-utils -y

# Set password for HTTPS access in Nginx

sudo htpasswd -b -c /etc/nginx/.htpasswd $kibana_admin_username $kibana_admin_password

# Add HTTPS configuration to Nginx default sites

# echo "server {
#     listen 443 ssl;
#     ssl_certificate /etc/ssl/certs/ssl.crt;
#     ssl_certificate_key /etc/ssl/private/ssl.key;
#     server_name elastic.tabulait.com;
#     access_log /var/log/nginx/nginx.vhost.access.log;
#     error_log /var/log/nginx/nginx.vhost.error.log;
#     location / {
#         proxy_pass http://localhost:5601;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_cache_bypass \$http_upgrade;
#     }
# }" | sudo tee -a /etc/nginx/sites-available/default

echo "server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl.crt;
    ssl_certificate_key /etc/ssl/private/ssl.key;
    server_name elastic.tabulait.com;
    access_log /var/log/nginx/nginx.vhost.access.log;
    error_log /var/log/nginx/nginx.vhost.error.log;
    auth_basic \"Restricted Access\";
    auth_basic_user_file /etc/nginx/.htpasswd;
    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}" | sudo tee -a /etc/nginx/sites-available/default

# Redirect HTTP to HTTPS

sudo sed -i '25i return 301 https://$host$request_uri;' /etc/nginx/sites-available/default

sudo systemctl restart nginx

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

sudo sed -i 's!#server.publicBaseUrl: ""!server.publicBaseUrl: "https://'$FQDN'"!g' /etc/kibana/kibana.yml

# Enable and start Kibana

sudo systemctl enable kibana && sudo systemctl start kibana

# To generate new enrollment token to connect with Elasticsearch
# sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana

####################
# Install Logstash #
####################

sudo apt-get install logstash -y

# Create Logstash Beats import on port 5044

echo "input {
  beats {
    port => 5044
  }
}" | sudo tee /etc/logstash/conf.d/02-beats-input.conf

# Create Elasticsearch output, in an index named after the Beat used

echo "output {
  if [@metadata][pipeline] {
	elasticsearch {
  	hosts => [\"localhost:9200\"]
  	manage_template => false
  	index => \"%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}\"
  	pipeline => \"%{[@metadata][pipeline]}\"
	}
  } else {
	elasticsearch {
  	hosts => [\"localhost:9200\"]
  	manage_template => false
  	index => \"%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}\"
	}
  }
}" | sudo tee /etc/logstash/conf.d/30-elasticsearch-output.conf

sudo systemctl start logstash

sudo systemctl enable logstash

####################################
# Install Filebeat on Local Server #
####################################

sudo apt-get install filebeat -y

# Update Filebeat config to use Logstash instead of Elasticsearch

sudo sed -i 's/output.elasticsearch/#output.elasticsearch/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/hosts: \[\"localhost:9200\"\]/#hosts: \[\"localhost:9200\"\]/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/#output.logstash:/output.logstash:/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/#hosts: \[\"localhost:5044\"\]/hosts: \[\"localhost:5044\"\]/g' /etc/filebeat/filebeat.yml

# Enable filebeat System module

# sudo filebeat modules enable system

# sudo filebeat setup --pipelines --modules system -M "system.syslog.var.paths=[/var/log/syslog*]" -M "system.auth.var.paths=[/var/log/auth.log*]"

# sudo filebeat setup --index-management -E output.logstash.enabled=false -E 'output.elasticsearch.hosts=["localhost:9200"]' -E setup.ilm.overwrite=true

# sudo filebeat setup -E output.logstash.enabled=false -E output.elasticsearch.hosts=['localhost:9200'] -E setup.kibana.host=localhost:5601 -E setup.ilm.overwrite=true

# # Start and enable Filebeat

# sudo systemctl start filebeat
# sudo systemctl enable filebeat