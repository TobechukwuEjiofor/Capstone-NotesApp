resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.app.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                        = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_monitor_action_group" "alerts" {
  name                = "notesapp-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "notesapp"

  email_receiver {
    name          = "team"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "high-cpu-usage"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.app.id]
  description         = "Alert when CPU usage is high"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}
