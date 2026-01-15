output "vm_ips" {
  description = "Map of VM names to their IP addresses"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => split("/", split(",", replace(vm.ipconfig0, "ip=", ""))[0])[0]
  }
}

output "vm_ids" {
  description = "Map of VM names to their VMIDs"
  value = {
    for name, vm in proxmox_vm_qemu.vm : name => vm.vmid
  }
}

output "master_ips" {
  description = "IP addresses of master nodes"
  value = [
    for name, vm in proxmox_vm_qemu.vm : split("/", split(",", replace(vm.ipconfig0, "ip=", ""))[0])[0]
    if can(regex("master", vm.tags))
  ]
}

output "worker_ips" {
  description = "IP addresses of worker nodes"
  value = [
    for name, vm in proxmox_vm_qemu.vm : split("/", split(",", replace(vm.ipconfig0, "ip=", ""))[0])[0]
    if can(regex("worker", vm.tags))
  ]
}
