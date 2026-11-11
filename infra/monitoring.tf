locals {
  app_id = azurerm_container_app.api.id

  charts = [
    {
      title   = "1. Екземпляри (фактична кількість)"
      x       = 0
      y       = 0
      metrics = [{ name = "Replicas", agg = 3, label = "Replicas (max)" }]
      filters = []
    },
    {
      title   = "2. CPU, % від ліміту"
      x       = 6
      y       = 0
      metrics = [{ name = "CpuPercentage", agg = 4, label = "CPU % (avg)" }]
      filters = []
    },
    {
      title   = "3. Запити за хвилину"
      x       = 0
      y       = 4
      metrics = [{ name = "Requests", agg = 1, label = "Requests (sum)" }]
      filters = []
    },
    {
      title = "4. Затримка, мс (середня і максимум)"
      x     = 6
      y     = 4
      metrics = [
        { name = "ResponseTime", agg = 4, label = "Avg" },
        { name = "ResponseTime", agg = 3, label = "Max" },
      ]
      filters = []
    },
    {
            title   = "2. CPU (нано-ядра, 250 млн = 100%)"
      x       = 6
      y       = 0
      metrics = [{ name = "UsageNanoCores", agg = 4, label = "CPU nanocores (avg)" }]
      filters = [{ key = "statusCodeCategory", operator = 0, values = ["5xx"] }]
    },
  ]

  dashboard_parts = {
    for i, c in local.charts : tostring(i) => {
      position = { x = c.x, y = c.y, colSpan = 6, rowSpan = 4 }
      metadata = {
        type = "Extension/HubsExtension/PartType/MonitorChartPart"
        inputs = [{
          name = "options"
          value = {
            chart = {
              metrics = [for m in c.metrics : {
                resourceMetadata    = { id = local.app_id }
                name                = m.name
                aggregationType     = m.agg
                namespace           = "microsoft.app/containerapps"
                metricVisualization = { displayName = m.label }
              }]
              title            = c.title
              titleKind        = 2
              visualization    = { chartType = 2 }
              filterCollection = { filters = c.filters }
            }
          }
        }]
        settings = { content = {} }
      }
    }
  }
}

resource "azurerm_portal_dashboard" "main" {
  name                = "${var.prefix}-dashboard"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = local.dashboard_parts
      }
    }
    metadata = {
      model = {}
    }
  })
}