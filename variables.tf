variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-apim-afd-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "apim-afd"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.prefix))
    error_message = "Prefix must be 3-20 characters, lowercase alphanumeric and hyphens only."
  }
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "Your Organization"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.apim_publisher_email))
    error_message = "Must be a valid email address."
  }
}

variable "enable_availability_zones" {
  description = "Enable availability zones for Premium v2 (increases reliability)"
  type        = bool
  default     = false # Set to true for production with zone redundancy
}

variable "apim_capacity" {
  description = "Number of capacity units (1-30 for Premium v2)"
  type        = number
  default     = 1
  validation {
    condition     = var.apim_capacity >= 1 && var.apim_capacity <= 30
    error_message = "Premium v2 capacity must be between 1 and 30."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "APIM-FrontDoor-PrivateLink"
    Tier        = "Premium-v2"
  }
}
