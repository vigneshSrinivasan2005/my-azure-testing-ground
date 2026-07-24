output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the created Resource Group"
}

output "web_app_name" {
  value       = azurerm_linux_web_app.app.name
  description = "The exact App Service name to supply to Azure Pipelines"
}

output "web_app_default_hostname" {
  value       = azurerm_linux_web_app.app.default_hostname
  description = "The default URL of the deployed App Service"
}