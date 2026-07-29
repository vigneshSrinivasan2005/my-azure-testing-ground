variable "project_name" {
  type        = string
  default     = "hr-helpdesk"
  description = "Name of the project"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev, testing, prod)"
}

variable "location" {
  type        = string
  default     = "East US"
  description = "Azure region for resources"
}

variable "python_version" {
  type        = string
  default     = "3.12"
  description = "Python version for the Linux Web App stack"
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "Virtual Network IP address space"
}

variable "app_subnet_prefix" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "Subnet prefix for App Service VNet integration"
}

variable "db_subnet_prefix" {
  type        = list(string)
  default     = ["10.0.2.0/24"]
  description = "Subnet prefix for Azure SQL Database endpoints"
}

variable "sql_admin_username" {
  type        = string
  default     = "hradmin"
  description = "Administrator username for Azure SQL Server"
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  default     = "P@ssw0rd123456!"
  description = "Administrator password for Azure SQL Server"
}

variable "ai_model_name" {
  type        = string
  default     = "mistral-small-2503"
  description = "Azure AI Foundry / OpenAI model deployment name"
}

variable "log_analytics_retention_days" {
  type        = number
  default     = 30
  description = "Retention in days for Log Analytics workspace"
}