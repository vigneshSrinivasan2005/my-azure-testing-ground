locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  storage_name   = lower(replace("st${var.project_name}${var.environment}", "-", ""))
  clean_sql_name = lower(replace("sql-${var.project_name}-${var.environment}", "_", "-"))
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Vignesh Srinivasan (DevOps)"
  }
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# 2. Networking (3-Tier Virtual Network Architecture)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

# App Service Subnet (Delgated for Web App VNet Integration)
resource "azurerm_subnet" "app_subnet" {
  name                 = "snet-app-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.app_subnet_prefix

  delegation {
    name = "webapp-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Database Subnet (For isolated Azure SQL database access)
resource "azurerm_subnet" "db_subnet" {
  name                 = "snet-db-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.db_subnet_prefix
  service_endpoints    = ["Microsoft.Sql"]
}

# 3. Log Analytics & Application Insights (Monitoring & Observability)
resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}

resource "azurerm_application_insights" "app_insights" {
  name                = "appinsights-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log_workspace.id
  application_type    = "web"
  tags                = local.common_tags
}

# 4. Blob Storage Account (Hot Attachment Storage & Cold Audit Logs)
resource "azurerm_storage_account" "sa" {
  name                     = substr(local.storage_name, 0, 24)
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_storage_container" "tickets_blob" {
  name                  = "tickets-attachments"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "audit_blob" {
  name                  = "audit-logs-archive"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# 5. Azure SQL Server & Dual Databases (Hot HelpDesk & Archive)
resource "azurerm_mssql_server" "sql_server" {
  name                         = local.clean_sql_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.common_tags
}

# Hot Database (Live tickets & active employee interactions)
resource "azurerm_mssql_database" "sql_db_hot" {
  name         = "sqldb-hot-helpdesk"
  server_id    = azurerm_mssql_server.sql_server.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "BasePrice"
  max_size_gb  = 5
  sku_name     = "Basic"
  tags         = local.common_tags
}

# Archive Database (Audit trail & historical closed ticket archives)
resource "azurerm_mssql_database" "sql_db_archive" {
  name         = "sqldb-archive-helpdesk"
  server_id    = azurerm_mssql_server.sql_server.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "BasePrice"
  max_size_gb  = 5
  sku_name     = "Basic"
  tags         = local.common_tags
}

# SQL Server Firewall Rule allowing access from Azure Web App & internal services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 6. Azure Cognitive Services / AI Foundry Account
resource "azurerm_cognitive_account" "ai_foundry" {
  name                = "ai-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "CognitiveServices"
  sku_name            = "S0"
  tags                = local.common_tags
}

# 7. App Service Plan (Linux)
resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.environment == "prod" ? "B1" : "F1"
  tags                = local.common_tags
}

# 8. Linux Web App for Intelligent HR HelpDesk Platform
resource "azurerm_linux_web_app" "app" {
  name                = "app-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = var.environment == "prod" ? true : false

    application_stack {
      python_version = var.python_version
    }

    app_command_line = "gunicorn --bind=0.0.0.0:5000 --timeout 600 app:app"
  }

  app_settings = {
    "FLASK_ENV"                             = var.environment == "prod" ? "production" : "development"
    "WEBSITES_PORT"                         = "5000"
    "AZURE_SQL_HOST"                        = azurerm_mssql_server.sql_server.fully_qualified_domain_name
    "AZURE_SQL_HOT_DB"                      = azurerm_mssql_database.sql_db_hot.name
    "AZURE_SQL_ARCHIVE_DB"                  = azurerm_mssql_database.sql_db_archive.name
    "AZURE_STORAGE_ACCOUNT"                 = azurerm_storage_account.sa.name
    "AZURE_AI_ENDPOINT"                     = azurerm_cognitive_account.ai_foundry.endpoint
    "AZURE_AI_MODEL"                        = var.ai_model_name
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.app_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
  }

  tags = local.common_tags
}

# VNet Integration for App Service
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.app.id
  subnet_id      = azurerm_subnet.app_subnet.id
}