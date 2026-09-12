output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "db_fqdn" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value     = azurerm_container_registry.acr.admin_username
  sensitive = true
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}
