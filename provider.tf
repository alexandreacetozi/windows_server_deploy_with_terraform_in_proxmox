provider "proxmox" {
  pm_api_url          = var.pm_api_url      # e.g. https://pve1.example.com:8006/api2/json
  pm_api_token_id     = var.pm_api_token_id # e.g. root@pam!terraform
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true # set false if you trust your certs
}