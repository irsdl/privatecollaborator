#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 yourdomain.com email@address.com"
  exit 1
fi

DOMAIN=$1
EMAIL=$2

# Check if the symlink already exists in /usr/local/bin
if [ -L "/usr/local/bin/BurpSuitePro" ] || [ -f "/usr/local/bin/BurpSuitePro" ]; then
    echo "BurpSuitePro is already installed and accessible from /usr/local/bin."
else
    # Define the expected installation path
    installed_path="/usr/local/BurpSuitePro/BurpSuitePro"

    # Find BurpSuitePro in the system path or check the installed path
    if [ -f "$installed_path" ] || which BurpSuitePro >/dev/null 2>&1; then
        # Get the actual path from which or use the installed path
        actual_path=$(which BurpSuitePro 2>/dev/null || echo "$installed_path")

        # Create a symbolic link in /usr/local/bin
        ln -s "$actual_path" "/usr/local/bin/BurpSuitePro"
        echo "Symbolic link created for BurpSuitePro in /usr/local/bin."
    else
        # If BurpSuitePro is not found, run the installer script
        echo "BurpSuitePro not found. Running installer script..."
        ./burp-installer-script.sh
    fi
fi

if [ ! -f /usr/local/bin/BurpSuitePro ]; then
    echo "Burp Suite Pro was not installed correctly. Please install it manually to /usr/local/bin/BurpSuitePro and run the installer script again"
    exit
fi

# Make sure that permissions are ok for all scripts.
chmod +x *.sh


SRC_PATH="`dirname \"$0\"`"

# Get public IP in case not running on AWS, Azure or Digitalocean.
MYPUBLICIP=$(curl http://checkip.amazonaws.com/ -s)
MYPRIVATEIP=$(hostname -I | cut -d' ' -f 1) # It assumes that first network interface is the Internet one

# Get IPs if running on AWS.
curl http://169.254.169.254/latest -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
  MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)
fi;

# Get IPs if running on Azure.
curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network?api-version=2017-08-01" -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text" -s)
  MYPUBLICIP=$(curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text" -s)
fi;

# Get IPs if running on Digitalocean.
curl http://169.254.169.254/metadata/v1/id -s --output /dev/null -f -m1
if [ 0 -eq $? ]; then
  # Use Floating IP if the VM has it enabled.
  FLOATING=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/active -s)
  if [ "$FLOATING" == "true" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/ip_address -s)
    MYPRIVATEIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/address -s)
  fi
  if [ "$FLOATING" == "false" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address -s)
    MYPRIVATEIP=$MYPUBLICIP
  fi
fi;

# Use snap version of Certbot because APT-version is too old.
snap install --classic certbot
snap refresh certbot
ln -s /snap/bin/certbot /usr/bin/certbot

apt update -y && apt install -y python3 python3-dnslib

# to create a random metrics path
METRICS=`LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | fold -w 10 | head -1`

mkdir -p /usr/local/collaborator/
cp "$SRC_PATH/dnshook.sh" /usr/local/collaborator/
cp "$SRC_PATH/cleanup.sh" /usr/local/collaborator/

# Ask the user if they want the polling service to use different ports
echo "Do you want the polling service to use different ports to restrict its requests in the future? (yes/no[default])"
read answer

# Normalize the answer to lower case to handle variations like Yes, YES, yEs, etc.
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

# Check the user's answer
if [[ "$answer" == "yes" || "$answer" == "y" || "$answer" == "1" ]]; then
    # If the answer is yes, copy the custom polling ports config
    cp "$SRC_PATH/collaborator_custom_pollling_ports.config" /usr/local/collaborator/collaborator.config
    echo "Custom polling ports configuration has been applied. Use $DOMAIN:8443 (HTTPS) and $DOMAIN:8080 (HTTP)"
else
    # Otherwise, copy the no polling ports config
    cp "$SRC_PATH/collaborator_no_polling_ports.config" /usr/local/collaborator/collaborator.config
    echo "No polling ports configuration has been applied."
fi

sed -i "s/INT_IP/$MYPRIVATEIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/EXT_IP/$MYPUBLICIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/BDOMAIN/$DOMAIN/g" /usr/local/collaborator/collaborator.config
sed -i "s/burp-metrics-path/$METRICS/g" /usr/local/collaborator/collaborator.config
cp "$SRC_PATH/burpcollaborator.service" /etc/systemd/system/
cp "$SRC_PATH/startcollab.sh" /usr/local/collaborator/
cp "$SRC_PATH/renewcert.sh" /etc/cron.daily/renewcert

cd /usr/local/collaborator/
chmod +x /usr/local/collaborator/*

grep $MYPRIVATEIP /etc/hosts -q || (echo $MYPRIVATEIP `hostname` >> /etc/hosts)

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

# Wildcard certificate is requested in two steps as it is less error-prone.
# The first step requests the actual wildcard with *.domain.com (all subdomains) certificate.
# The second step expands the certificate with domain.com (without any subdomain).
# This used to be possible in single-step, however currently it can lead to invalid TXT-record error,
# as certbot starts the dnshooks concurrently and not consecutively.
certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" -m $EMAIL --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "*.$DOMAIN" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" -m $EMAIL --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "$DOMAIN, *.$DOMAIN" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01 \
    --expand

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
ln -s $CERT_PATH /usr/local/collaborator/keys

echo 
echo SUCCESS! Burp is now running with the letsencrypt certificate for domain *.$DOMAIN
echo
echo Your metrics path was set to $METRICS. Change addressWhitelist to access it remotely.

# removing the listener to port 53
# Check if the DNSStubListener line exists and is commented out
if grep -q "^#DNSStubListener=" /etc/systemd/resolved.conf; then
    # Uncomment the line and set its value to no
    sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
elif grep -q "^DNSStubListener=" /etc/systemd/resolved.conf; then
    # The line exists, ensure it's set to no
    sudo sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
else
    # The line doesn't exist, append it
    echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf > /dev/null
fi

# Restart systemd-resolved to apply changes
sudo systemctl restart systemd-resolved

sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf >/dev/null
