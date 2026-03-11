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

# Configure SSH for password authentication
echo "Configuring SSH for password authentication..."
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
# Also set in sshd_config.d to ensure cloud-init doesn't override
sudo tee /etc/ssh/sshd_config.d/50-cloud-init.conf > /dev/null <<'EOF'
PasswordAuthentication yes
EOF
sudo systemctl restart sshd

# ============================================
# NETWORK CONFIGURATION
# ============================================

echo "Configuring network services..."

# CRITICAL: Mask (not just disable) wait-online services to prevent boot hangs
# 'disable' only removes auto-start symlinks but dependencies can still trigger it
# 'mask' completely prevents the service from being started by anything
echo "Masking systemd-networkd-wait-online services..."
sudo systemctl mask systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online@.service || true

# Enable systemd-networkd (netplan backend)
echo "Enabling systemd-networkd..."
sudo systemctl enable systemd-networkd
sudo systemctl enable systemd-resolved || true

# ============================================
# CLOUD-INIT CONFIGURATION
# ============================================

echo "Configuring cloud-init..."
sudo systemctl enable cloud-init
sudo systemctl enable cloud-init-local
sudo systemctl enable cloud-config
sudo systemctl enable cloud-final

# Clean cloud-init state FIRST (before creating configs that need to persist)
echo "Cleaning cloud-init state..."
sudo cloud-init clean --logs --seed

# Configure cloud-init datasource for Proxmox
echo "Configuring cloud-init datasource for Proxmox..."
sudo tee /etc/cloud/cloud.cfg.d/99-pve.cfg > /dev/null <<'EOF'
datasource_list: [ NoCloud, ConfigDrive ]
datasource:
  NoCloud:
    fs_label: cidata
EOF

# Ensure cloud-init does NOT lock the ubuntu user password
echo "Configuring cloud-init to allow password login..."
sudo sed -i 's/lock_passwd:\s*True/lock_passwd: False/' /etc/cloud/cloud.cfg

# Explicitly unlock the ubuntu user password
echo "Unlocking ubuntu user password..."
sudo passwd -u ubuntu || true

# Remove any configs that block cloud-init networking
echo "Removing cloud-init network blockers..."
sudo rm -f /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg

# Ensure netplan directory exists with correct permissions
sudo mkdir -p /etc/netplan
sudo chmod 755 /etc/netplan

# Create fallback netplan config (uses 01- prefix so cloud-init's 50- can override)
echo "Creating fallback netplan configuration..."
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      dhcp4: true
      dhcp6: false
      dhcp-identifier: mac
EOF
sudo chmod 600 /etc/netplan/01-netcfg.yaml

# Apply netplan configuration to ensure it's valid
echo "Applying netplan configuration..."
sudo netplan generate || true
sudo netplan apply || true

echo "Network configuration complete."

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
