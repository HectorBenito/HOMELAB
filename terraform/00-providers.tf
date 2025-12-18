terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_tls_insecure = true
  pm_minimum_permission_check = false
  pm_api_url = var.pm_api_url
  pm_user = var.pm_username
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}