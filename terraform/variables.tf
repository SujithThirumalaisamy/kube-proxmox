# Proxmox API Configuration
variable "pm_api_url" {
  description = "Proxmox API URL (e.g., https://pve.example.com:8006/api2/json)"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# VM Definitions Map
variable "vms" {
  description = "Map of VM definitions. Key is the VM name."
  type = map(object({
    vmid        = number
    ip          = string
    target_node = string
    cores       = number
    memory      = number
    disk_size   = string
    tags        = string
    description = optional(string)
  }))
  default = {}
}

# Environment-level defaults (rarely change)
variable "template" {
  description = "Name of the VM template to clone"
  type        = string
  default     = "ubuntu-2204-cloudinit"
}

variable "storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "10.0.0.1"
}

variable "nameserver" {
  description = "DNS server IP"
  type        = string
  default     = "10.0.253.253"
}

variable "cpu_type" {
  description = "CPU type for VMs"
  type        = string
  default     = "host"
}

variable "bios" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = "ovmf"
}

# Cloud-init settings
variable "username" {
  description = "Cloud-init username"
  type        = string
}

variable "ssh_key" {
  description = "SSH public key for cloud-init"
  type        = string
}
