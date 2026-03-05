packer {
  required_plugins {
    proxmox = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variables
variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
  default     = "https://192.168.1.103:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username"
  default     = "root@pam"
}

variable "proxmox_password" {
  type        = string
  sensitive   = true
  description = "Proxmox password"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = "pve01"
}

variable "vm_id" {
  type        = number
  description = "VM ID for template"
  default     = 900
}

variable "template_name" {
  type        = string
  description = "Template name in Proxmox"
  default     = "ubuntu-noble-2404-packer-template"
}

variable "iso_storage_pool" {
  type        = string
  description = "Storage pool for ISO files"
  default     = "local"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disk"
  default     = "data"
}

variable "cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "memory" {
  type        = number
  description = "Memory in MB"
  default     = 2048
}

variable "disk_size" {
  type        = string
  description = "Disk size"
  default     = "20G"
}

variable "network_bridge" {
  type        = string
  description = "Network bridge"
  default     = "vmbr0"
}

variable "ssh_username" {
  type        = string
  description = "SSH username"
  default     = "ubuntu"
}

variable "ssh_password" {
  type        = string
  description = "SSH password"
  default     = "ubuntu"
  sensitive   = true
}

# Source
source "proxmox-iso" "ubuntu" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM Settings
  vm_id                = var.vm_id
  vm_name              = "packer-ubuntu-noble"
  template_name        = var.template_name
  template_description = "Ubuntu 24.04.4 LTS (Noble) - Built with Packer on ${timestamp()}"

  # ISO Configuration
  iso_url          = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
  iso_checksum     = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  # Hardware Configuration
  cores  = var.cores
  memory = var.memory

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "raw"
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  # Cloud-Init
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  # QEMU Agent
  qemu_agent = true

  # Boot Configuration
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  # HTTP Server for autoinstall
  http_directory = "http"
  http_port_min  = 8802
  http_port_max  = 8802

  # SSH Configuration
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20

  # Template Conversion
  task_timeout = "20m"
}

# Build
build {
  sources = ["source.proxmox-iso.ubuntu"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed.'"
    ]
  }

  # Run setup script
  provisioner "shell" {
    script = "scripts/setup.sh"
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "sudo sync"
    ]
  }
}
