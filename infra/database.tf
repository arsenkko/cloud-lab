variable "db_location" {
  type    = string
  default = "swedencentral"
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                          = "${var.prefix}-pgs-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.db_location
  version                       = "16"
  administrator_login           = "appadmin"
  administrator_password        = random_password.db.result
  sku_name                      = "GP_Standard_D2ds_v4"
  storage_mb                    = 32768
  backup_retention_days         = 7
  public_network_access_enabled = true
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}