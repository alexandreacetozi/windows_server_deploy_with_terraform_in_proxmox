provider "proxmox" {
  # https://pve-host:8006/  (with trailing slash)
  endpoint = var.pm_api_url

  # Concatenate token id and value: user@realm!tokenid=secret
  # (Pattern shown in provider examples.)
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"

  insecure = true # set false if you use a valid TLS cert

  # SSH is used only for a few ops; safe to include.
  ssh {
    username = "root"
    agent    = true # use your local ssh-agent key
    # OR: private_key = file("~/.ssh/id_ed25519")
  }
}