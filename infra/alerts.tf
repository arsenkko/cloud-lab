resource "azurerm_monitor_action_group" "email" {
  name                = "${var.prefix}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "cloudlab"

  email_receiver {
    name                    = "owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# CPU > 70% від ліміту (0,25 ядра = 250 млн нано-ядер, 70% = 175 млн)
resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "${var.prefix}-cpu-high"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "CPU вище 70% протягом кількох хвилин"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true # надсилає лист і коли проблема зникла

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "UsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 100000000
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}