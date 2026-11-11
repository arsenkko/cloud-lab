variable "image_tag" {
  type    = string
  default = "v3" # НОВЕ: було v2
}

# НОВЕ: час життя кешу в секундах, 0 = кеш вимкнено
variable "cache_ttl" {
  type    = string
  default = "0"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.prefix}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.prefix}-app-id"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_container_app" "api" {
  name                         = "${var.prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  secret {
    name  = "database-url"
    value = "postgresql://appadmin:${random_password.db.result}@${azurerm_postgresql_flexible_server.db.fqdn}:5432/appdb?sslmode=require"
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 4

    container {
      name   = "api"
      image  = "${azurerm_container_registry.acr.login_server}/cloud-lab-api:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      # НОВЕ: перемикач кешу
      env {
        name  = "CACHE_TTL_SECONDS"
        value = var.cache_ttl
      }
    }

    custom_scale_rule {
      name             = "cpu-scale"
      custom_rule_type = "cpu"
      metadata = {
        type  = "Utilization"
        value = "60"
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_postgresql_flexible_server_database.app,
  ]
}

output "app_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}