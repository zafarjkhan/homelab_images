# Ubuntu Noble Packer Template for Proxmox

Automated build of Ubuntu 24.04.4 LTS (Noble Numbat) template for Proxmox using Packer.

## Prerequisites

- Packer 1.8.0+
- Proxmox VE access
- Storage pools: `local` (ISO) and `data` (VM disk)
- VM ID 900 available
- Network bridge `vmbr0`

## Quick Start

1. Copy the example variables file:
```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

2. Edit `variables.pkrvars.hcl` with your Proxmox credentials and settings

3. Build the template:
```bash
packer init .
packer build -var-file=variables.pkrvars.hcl ubuntu.pkr.hcl
```

Build takes 10-18 minutes.

## Testing the Template

1. In Proxmox, clone template ID 900 to a new VM
2. Configure cloud-init (user, SSH key, network)
3. Start the VM and verify:
   - SSH access works
   - qemu-guest-agent shows IP in Proxmox
   - Network configured via cloud-init
   - Packages installed: tmux, htop, vim, curl, wget

## Configuration

Template includes:
- **OS**: Ubuntu 24.04.4 LTS (Noble Numbat)
- **Hardware**: 2 cores, 2GB RAM, 20GB disk
- **Features**: Cloud-init enabled, qemu-guest-agent
- **Packages**: openssh-server, cloud-init, qemu-guest-agent, net-tools, vim, curl, wget, tmux, htop

Customize via `variables.pkrvars.hcl`.

## Security Note

`variables.pkrvars.hcl` contains credentials and is gitignored. Never commit this file.
