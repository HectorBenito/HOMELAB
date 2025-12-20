variable "pm_username" {
  type        = string
  description = "Proxmox username"
}


variable "pm_api_url" {
  type        = string
  description = "Proxmox url"
}


variable "pm_api_token_id" {
  type        = string
  description = "Proxmox user api key id"
  sensitive   = true
}


variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox user api key secret"
  sensitive   = true
}


variable "talos_iso_file" {
  description = "Iso file location for talos os"
  type        = string
}

variable talos_control_configuration {
  description = "Configuration object for talos control plane"
  type = list(object(
    {
      pm_node   = string
      vmid      = number
      vm_name   = string
      cpu_cores = number
      memory    = number
      disk_size = string
      networks = list(object(
        {
          id      = number
          macaddr = string
        }
      ))
    }
  ))
}


variable talos_worker_configuration {
  description = "Configuration object for talos worker nodes"
  type = list(object(
    {
      pm_node   = string
      vmid      = number
      vm_name   = string
      cpu_cores = number
      memory    = number
      disk_size = string
      networks = list(object(
        {
          id      = number
          macaddr = string
        }
      ))
    }
  ))
}