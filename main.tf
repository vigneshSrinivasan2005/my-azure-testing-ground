# Local values: scoped constants to avoid repetitive resource naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# 2. App Service Plan (Linux)
resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1" # Free Tier (change to B1/P1v2 for production)

  tags = local.common_tags
}

# 3. Linux Web App for Flask App / AI Agent
resource "azurerm_linux_web_app" "app" {
  name                = "app-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = false # Set to true for paid SKUs (B1+)

    application_stack {
      python_version = var.python_version
    }

    # Gunicorn startup command for Flask
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
  }

  app_settings = {
    "FLASK_ENV"     = var.environment == "prod" ? "production" : "development"
    "WEBSITES_PORT" = "5000"
  }

  tags = local.common_tags

  # Implicit Dependency: azurerm_linux_web_app automatically waits for azurerm_service_plan
}