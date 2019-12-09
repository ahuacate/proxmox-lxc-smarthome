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

# Create Node-Red home folder
mkdir -p /home/typhoon/nodered
chown 1607:65607 -R /home/typhoon/nodered

# Install Node-Red
msg "Installing Node-Red..."
apt-get update  >/dev/null
apt-get install -y curl  >/dev/null
echo
echo -e "You will now be prompted with (y/N) inputs. \nAnswer 'Y' to all prompts."
echo
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) - typhoon

# Start Node-Red Service
msg "Starting Node-Red service..."
systemctl daemon-reload
systemctl enable nodered.service
systemctl start nodered.service

# Cleanup container
msg "Cleanup..."
rm -rf /nodered_setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
