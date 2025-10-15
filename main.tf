resource "proxmox_virtual_environment_vm" "win2025" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.target_node
  started   = true

  # Firmware / boot
  bios       = "ovmf"
  boot_order = ["ide0", "sata0"] # boot installer, then disk

  # Create an EFI vars disk with Microsoft keys (Secure Boot ready)
  efi_disk {
    datastore_id      = var.storage
    pre_enrolled_keys = true
  }

  cpu {
    sockets = 1
    cores   = 4
  }

  memory {
    dedicated = 8192
  }

  # Attach Windows ISO as CD-ROM (installer)
  cdrom {
    interface = "ide0"
    # file_id format: "<storage>:iso/<file>"
    file_id = "${var.iso_storage}:iso/${var.windows_iso}"
  }

  # System disk on SATA (no driver needed)
  disk {
    interface    = "sata0"
    datastore_id = var.storage
    size         = 80
  }

  # NIC E1000 (works without drivers)
  network_device {
    model  = "e1000"
    bridge = "vmbr0"
  }
}