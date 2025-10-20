resource "proxmox_virtual_environment_vm" "win2025" {
  for_each = var.vms

  name      = each.value.name
  vm_id     = each.value.vm_id
  node_name = each.value.node_name
  started   = true

  bios       = "ovmf"
  boot_order = ["ide0", "sata0"]

  # --- Keep OS hint ---
  operating_system {
    type = "win11"
  }

  # --- Keep QEMU Guest Agent ---
  agent {
    enabled = true
    type    = "virtio" # provider default is fine; keep if you used it
    timeout = "15m"
  }

  efi_disk {
    datastore_id      = var.storage
    pre_enrolled_keys = true
  }

  cpu {
    sockets = 1
    cores   = each.value.cores
  }

  memory {
    dedicated = each.value.memory_mb
  }

  cdrom {
    interface = "ide0"
    file_id   = "${var.iso_storage}:iso/${var.windows_iso}"
  }

  disk {
    interface    = "sata0"
    datastore_id = var.storage
    size         = 80
  }

  network_device {
    model  = "e1000"
    bridge = "vmbr0"
  }
}