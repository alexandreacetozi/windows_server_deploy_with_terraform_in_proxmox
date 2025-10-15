resource "proxmox_vm_qemu" "win2025" {
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node

  # UEFI (OVMF). Secure Boot/TPM can be added depending on provider support.
  bios    = "ovmf"
  # Create an EFI disk on your storage. The exact syntax varies by provider version:
  # Most Telmate builds accept this shorthand:
  efidisk0 = "${var.storage}:1,pre-enrolled-keys=1"

  # CPU & RAM
  sockets  = 1
  cores    = 4
  memory   = 8192

  # VirtIO SCSI controller
  scsihw   = "virtio-scsi-single"

  # Boot order: cdrom (Windows ISO), then scsi0
  boot     = "order=ide2;scsi0"
  onboot   = true

  # Attach Windows Server 2025 ISO
  ide2     = "${var.iso_storage}:iso/${var.windows_iso},media=cdrom"

  # Attach VirtIO drivers ISO on a second CD-ROM (IDE0 works well)
  ide0     = "${var.iso_storage}:iso/${var.virtio_iso},media=cdrom"

  # System disk on SCSI (virtio)
  disk {
    slot      = 0
    type      = "scsi"
    size      = "80G"
    storage   = var.storage
    iothread  = 1
    ssd       = 1
    discard   = "on"       # TRIM
    cache     = "writeback" # performance (safer default is "none")
  }

  # Paravirtualized network (VirtIO)
  network {
    model  = "virtio"
    bridge = "vmbr0"
    # tag = 10  # optionally set a VLAN
  }

  # Recommended display; qemu-guest-agent can be enabled after drivers installed
  # agent = 1
  # vga   = "qxl"
}