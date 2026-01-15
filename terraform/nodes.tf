resource "proxmox_vm_qemu" "vm" {
  for_each = var.vms

  # General settings
  name        = each.key
  description = coalesce(each.value.description, "Proxmox VM - ${each.key}")
  vmid        = each.value.vmid
  target_node = each.value.target_node
  tags        = each.value.tags

  # Template settings
  clone      = var.template
  full_clone = true

  # Boot Process
  start_at_node_boot = true
  automatic_reboot   = true

  # Hardware Settings
  qemu_os = "other"
  bios    = var.bios
  agent   = 1
  vga {
    type = "std"
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = var.cpu_type
  }

  memory  = each.value.memory
  balloon = 0

  # Network Settings
  network {
    id     = 0
    bridge = var.bridge
    model  = "virtio"
  }

  # Disk Settings
  scsihw = "virtio-scsi-single"

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.storage
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage   = var.storage
          size      = each.value.disk_size
          iothread  = true
          replicate = false
        }
      }
    }
  }

  # Cloud Init Settings
  ipconfig0  = "ip=${each.value.ip},gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.username
  sshkeys    = var.ssh_key
}
