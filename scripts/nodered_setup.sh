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

# Install prerequisites
msg "Installing Node-Red prerequisites..."
apt-get install -y npm >/dev/null

# Install Node-Red
msg "Installing Node-Red..."
npm install -g --unsafe-perm node-red >/dev/null

# Create Node-Red Service
msg "Creating nodered service..."
cat << EOF > /etc/systemd/system/node-red.service
[Unit]
Description=node-red graphical event wiring tool
Wants=network.target
Documentation=http://nodered.org

[Service]
Type=simple
User=typhoon
Group=privatelab
WorkingDirectory=/home/typhoon/nodered

Nice=5
#Environment="NODE_OPTIONS=--max_old_space_size=256"
# uncomment the next line for a more verbose log output
#Environment="NODE_RED_OPTIONS=-v"
ExecStart=/usr/bin/env node-red $NODE_OPTIONS $NODE_RED_OPTIONS

KillSignal=SIGINT
Restart=on-failure
SyslogIdentifier=node-red

[Install]
WantedBy=multi-user.target
EOF

# Start Node-Red Service
msg "Starting Node-Red service..."
systemctl daemon-reload
systemctl enable node-red.service
systemctl start node-red.service
systemctl status node-red.service

# Cleanup container
msg "Cleanup..."
rm -rf /nodered_setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
