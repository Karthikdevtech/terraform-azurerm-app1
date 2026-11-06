variable "resource_group_name" {
  description = "Name of the Azure resource group created for the VM."
  type        = string
  default     = "rg-app-v2"
}

variable "location" {
  description = "Azure region for the resource group and VM."
  type        = string
  default     = "eastus"
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
  default     = "vm-app-v2"
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_F1als_v7"
}

variable "admin_username" {
  description = "Linux administrator username for SSH access."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key installed on the VM. Never provide a private key."
  type        = string
}

variable "ssh_source_cidr" {
  description = "Source IPv4 CIDR allowed to connect to SSH, such as your-public-ip/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_source_cidr, 0))
    error_message = "ssh_source_cidr must be a valid CIDR range, for example 203.0.113.10/32."
  }
}

variable "os_disk_size_gb" {
  description = "Managed OS disk size in GB."
  type        = number
  default     = 64

  validation {
    condition     = var.os_disk_size_gb >= 30
    error_message = "The Ubuntu OS disk must be at least 30 GB."
  }
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    version    = "2.1.2"
  }
}
