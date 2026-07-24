variable "project_name" {
  type        = string
  default     = "pavbot"
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