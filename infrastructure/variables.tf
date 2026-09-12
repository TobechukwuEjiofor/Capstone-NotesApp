variable "location" {
  default = "eastus"
}

variable "allowed_ssh_ip" {
  description = "Your group's public IP, in CIDR form e.g. 102.88.111.212/32"
  type        = string
}

variable "ssh_public_key_path" {
  default = "~/.ssh/notesapp_vm.pub"
}

variable "db_admin_user" {
  default = "notesappadmin"
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  type = string
}

variable "vm_size" { default = "Standard_D2s_v3" }