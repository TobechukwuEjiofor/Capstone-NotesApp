resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "notesapp-db-${random_id.suffix.hex}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  zone                   = "1"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_vm" {
  name             = "allow-vm-only"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = azurerm_public_ip.vm.ip_address
  end_ip_address   = azurerm_public_ip.vm.ip_address
}

resource "azurerm_postgresql_flexible_server_database" "notesapp" {
  name      = "notesdb"
  server_id = azurerm_postgresql_flexible_server.db.id
}
