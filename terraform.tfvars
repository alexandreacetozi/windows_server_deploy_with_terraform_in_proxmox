pm_api_url          = "https://192.168.1.110:8006/api2/json"
pm_api_token_id     = "root@pam!terraform_token"
pm_api_token_secret = "44dc13a4-45de-4411-9d1e-c3ef3b1a045f"
storage             = "local-lvm"
iso_storage         = "local"
windows_iso         = "SERVER_EVAL_x64FRE_en-us.iso"
virtio_iso          = "virtio-win-0.1.285.iso"

vms = {
  "a" = { vm_id = 14001, node_name = "pve", name = "win2025-01", cores = 4, memory_mb = 8192 }
  "b" = { vm_id = 14002, node_name = "pve", name = "win2025-02", cores = 4, memory_mb = 4096 }
  #  "c" = { vm_id = 14003, node_name = "pve", name = "win2025-03", cores = 4, memory_mb = 4096 }
}