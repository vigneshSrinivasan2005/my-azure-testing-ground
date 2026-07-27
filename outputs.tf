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

output "sql_server_fqdn" {
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  description = "Fully Qualified Domain Name of Azure SQL Server"
}

output "hot_database_name" {
  value       = azurerm_mssql_database.sql_db_hot.name
  description = "Hot Database name for active tickets"
}

output "archive_database_name" {
  value       = azurerm_mssql_database.sql_db_archive.name
  description = "Archive Database name for resolved ticket audit logs"
}

output "storage_account_name" {
  value       = azurerm_storage_account.sa.name
  description = "Azure Storage Account name for attachments & audit logs"
}

output "ai_foundry_endpoint" {
  value       = azurerm_cognitive_account.ai_foundry.endpoint
  description = "Azure AI Foundry Cognitive Services Endpoint"
}

output "app_insights_key" {
  value       = azurerm_application_insights.app_insights.instrumentation_key
  sensitive   = true
  description = "Instrumentation key for Application Insights monitoring"
}