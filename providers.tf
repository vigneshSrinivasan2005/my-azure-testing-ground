terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote State Backend Configuration
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstate9751" # From step 1
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate" # Path/file name inside container
  }
}

provider "azurerm" {
  features {}

  # Skip automatic registration for older azurerm 3.x releases
  skip_provider_registration = true
}