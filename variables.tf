variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

variable "target_node" {
  type    = string
  default = "pve"
}

variable "vm_id" {
  type    = number
  default = 120
}

variable "vm_name" {
  type    = string
  default = "win2025"
}

variable "storage" {
  type    = string
  default = "local-lvm"
}

variable "iso_storage" {
  type    = string
  default = "local"
}

variable "windows_iso" {
  type    = string
  default = "Windows_Server_2025.iso"
}

variable "virtio_iso" {
  type    = string
  default = "virtio-win.iso"
}