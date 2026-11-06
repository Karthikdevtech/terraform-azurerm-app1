variable "resource_group_name" {
  description = "Name of the Azure resource group created for the static website."
  type        = string
  default     = "rg-static-site-v1"
}

variable "location" {
  description = "Azure region for the resource group and storage account."
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique Azure storage account name (3-24 lowercase letters and numbers)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "The storage account name must contain 3-24 lowercase letters or numbers."
  }
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    version    = "1.0.0"
  }
}
