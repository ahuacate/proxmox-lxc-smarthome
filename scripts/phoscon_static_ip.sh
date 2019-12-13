#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR:LXC] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}

echo -e "By default your Phoscon Raspian device uses DHCP IPv4 assigned addresses. \nIn the next step you will set your device to use a static IPv4 address. \nYou must enter your desired Phoscon Conbee network address settings. \nOr simply press 'ENTER' to accept our defaults."
echo

#Bash Shell script to check the usage of -n option
read -n 1 -p "Do you want to continue(Y/N): " choice
case $choice in
Y | y) 
      echo
      echo "Okay. Lets continue...";;
      echo
N | n)
      echo
      echo "Goodbye"
      exit;;
esac

# Set container IPv4 Address
read -p "Enter a Static IPv4 address: " -e -i 192.168.110.139 STATICIP
echo "Phoscon IPv4 address is $STATICIP."
echo

# Set Gateway IPv4 Address
read -p "Enter your network Gateway IPv4 address: " -e -i 192.168.110.5 GW
echo "Phoscon Gateway IPv4 address is $GW."
echo

# Set DNS
read -p "Enter your network DNS server address: " -e -i 192.168.110.5 DNSIP
echo "Phoscon DNS server address is $DNSIP."
echo

# Edit the DHCP conf file
cat << EOF >> /etc/dhcpcd.conf

interface eth0
static ip_address=$STATICIP/24
static routers=$GW
static domain_name_servers=$DNSIP
EOF

# Get network details and show completion message
echo "You have successfully changed your Phoscon network settings."
msg "
Phoscon is reachable by going to the following URLs.
      http://${STATICIP}
      http://${HOSTNAME}.local"
echo

# Reboot 
echo "Your Phoscon device is rebooting in 5 seconds...."
countdown 5
reboot
