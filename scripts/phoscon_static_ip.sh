#!/usr/bin/env bash

echo -e "By default your Phoscon Raspian device uses DHCP IPv4 assigned addresses. \nIn the next step you will set your device to use a static IPv4 address. \nYou must enter your desired Phoscon Conbee network address settings. \nOr simply press 'ENTER' to accept our defaults."
echo

# Query user to proceed [Y/n]
read -r -p "Are You Sure? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 echo "Yes"
 ;;
    [nN][oO]|[nN])
 echo "No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac

# Set container IPv4 Address
read -p "Enter a Static IPv4 address: " -e -i 192.168.120.133 STATICIP
info "Phoscon IPv4 address is $STATICIP."
echo

# Set Gateway IPv4 Address
read -p "Enter your network Gateway IPv4 address: " -e -i 192.168.120.5 GW
info "Phoscon Gateway IPv4 address is $GW."
echo

# Set DNS
read -p "Enter your network DNS server address: " -e -i 192.168.120.5 DNSIP
info "Phoscon DNS server address is $DNSIP."
echo

# Edit the DHCP conf file
cat << EOF > /etc/dhcpcd.conf
interface eth0
static ip_address=$STATICIP/24
static routers=$GW
static domain_name_servers=$DNSIP
EOF
