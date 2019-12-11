#!/usr/bin/env bash

echo -e "By default your Phoscon Raspian device uses DHCP IPv4 assigned addresses. \nIn the next step you must enter your desired Phoscon Conbee network address settings. \nOr simply press 'ENTER' to accept our defaults."
echo

# Set container IPv4 Address
read -p "Enter IPv4 address: " -e -i 192.168.110.132/24 IP
info "Container IPv4 address is $IP."
echo
