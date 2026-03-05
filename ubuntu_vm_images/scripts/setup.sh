#!/bin/bash
set -e

echo "=== Starting provisioning script ==="

# Wait for any background updates to complete
echo "Waiting for background updates..."
sleep 10
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for dpkg lock..."
  sleep 5
done

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Upgrade all packages
echo "Upgrading packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install/ensure required packages
echo "Installing required packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  qemu-guest-agent \
  cloud-init \
  cloud-utils \
  cloud-initramfs-growroot

# Enable and start qemu-guest-agent
echo "Enabling qemu-guest-agent..."
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

# Configure cloud-init
echo "Configuring cloud-init..."
sudo systemctl enable cloud-init
sudo systemctl enable cloud-init-local
sudo systemctl enable cloud-config
sudo systemctl enable cloud-final

# Clean cloud-init
echo "Cleaning cloud-init..."
sudo cloud-init clean --logs --seed

# Remove machine-specific files
echo "Removing machine-specific identifiers..."
sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Clean logs
echo "Cleaning logs..."
sudo find /var/log -type f -delete
sudo find /var/log -type d -exec sh -c 'truncate -s 0 {}/.placeholder 2>/dev/null || true' \;

# Clean temporary files
echo "Cleaning temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clean apt cache
echo "Cleaning apt cache..."
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo apt-get clean -y

# Clear bash history
echo "Clearing bash history..."
cat /dev/null > ~/.bash_history && history -c
sudo sh -c 'cat /dev/null > /root/.bash_history'

# Sync filesystem
echo "Syncing filesystem..."
sync

echo "=== Provisioning complete ==="
