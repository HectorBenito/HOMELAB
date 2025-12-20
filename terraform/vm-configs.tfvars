# location of talos iso file
talos_iso_file = "templates:iso/talos-metal-amd64.iso"

# talos control nodes configuration
talos_control_configuration = [
  {
    pm_node   = "pve1"
    vmid      = 1110
    vm_name   = "talos-control-1"
    cpu_cores = 2
    memory    = 4096
    disk_storage   = "POOL"
    disk_size = "50G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D1"
      }
    ]
  },
  {
    pm_node   = "pve2"
    vmid      = 2110
    vm_name   = "talos-control-2"
    cpu_cores = 2
    memory    = 4096
    disk_storage   = "POOL"
    disk_size = "50G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D2"
      }
    ]
  },
  {
    pm_node   = "pve3"
    vmid      = 3110
    vm_name   = "talos-control-3"
    cpu_cores = 2
    memory    = 4096
    disk_storage   = "POOL"
    disk_size = "50G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D3"
      }
    ]
  }
]


# talos worker nodes configuration
talos_worker_configuration = [
  {
    pm_node   = "pve1"
    vmid      = 1111
    vm_name   = "talos-worker-1"
    cpu_cores = 6
    memory    = 8192
    disk_storage   = "POOL"
    disk_size = "100G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D4"
      }
    ]
  },
  {
    pm_node   = "pve2"
    vmid      = 2111
    vm_name   = "talos-worker-2"
    cpu_cores = 6
    memory    = 8192
    disk_storage   = "POOL"
    disk_size = "100G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D5"
      }
    ]
  },
  {
    pm_node   = "pve3"
    vmid      = 3111
    vm_name   = "talos-worker-3"
    cpu_cores = 12
    memory    = 8192
    disk_storage   = "POOL"
    disk_size = "100G"
    longhorn_disk_size = "250G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D6"
      }
    ]
  }
]