variable "vms" {
  description = "Per-VM config map"
  type = map(object({
    vm_id     = number
    node_name = string
    name      = string
    cores     = number
    memory_mb = number
  }))
}

variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
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
  default = "SERVER_EVAL_x64FRE_en-us.iso"
}

variable "virtio_iso" {
  type    = string
  default = "virtio-win-0.1.285.iso"
}