terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      # If you want a pinned version:
      # version = "~> 3.0"
    }
  }
}