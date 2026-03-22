#!/bin/bash

# Automated deployment script for UDP ZIVPN Panel

# Update package lists
sudo apt-get update

# Install necessary dependencies
sudo apt-get install -y openvpn iptables

# Define variables
CONFIG_URL="http://your-config-url.com/config.ovpn"
CONFIG_DEST="/etc/openvpn/client.ovpn"

# Download the OpenVPN configuration file
wget -O "$CONFIG_DEST" "$CONFIG_URL"

# Start OpenVPN service
sudo systemctl start openvpn@client

# Enable OpenVPN to start on boot
sudo systemctl enable openvpn@client

echo "UDP ZIVPN Panel installation complete!"