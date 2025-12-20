resource "proxmox_vm_qemu" "talos_stateless_worker" {

  for_each = { for index, config in var.talos_worker_configuration : config.vmid => config }

  target_node = each.value.pm_node
  vmid        = each.value.vmid
  name        = each.value.vm_name
  description = "Talos worker node ${each.value.vmid}"


  # options
  agent    = 1
  vm_state = "running"
  onboot   = true

  # cpu & memory configuration
  memory = each.value.memory
  cpu {
    cores   = each.value.cpu_cores
    sockets = 1
    type    = "host"
  }

  # network configuration
  ipconfig0 = "ip=dhcp"
  skip_ipv6 = true


  dynamic "network" {
    for_each = each.value.networks
    content {
      id      = network.value.id
      model   = "virtio"
      bridge  = "vmbr0"
      macaddr = network.value.macaddr
    }
  }

  # disk configuration
  scsihw = "virtio-scsi-single"
  boot   = "order=scsi0;ide2"
  disks {
    scsi {
      scsi0 {
        disk {
          storage = "POOL"
          size    = each.value.disk_size
        }
      }
    }
    ide {
      ide2 {
        cdrom {
          iso = var.talos_iso_file
        }
      }
    }
  }


  # lifecycle
  lifecycle {
    ignore_changes = [
      disk,
      vm_state
    ]
  }

  tags = "kubernetes,worker"
}