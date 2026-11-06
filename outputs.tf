output "static_website_url" {
  description = "Public URL of the deployed static website."
  value       = azurerm_storage_account.static_site.primary_web_endpoint
}

output "resource_group_name" {
  description = "Name of the resource group created by this module."
  value       = azurerm_resource_group.static_site.name
}

output "storage_account_name" {
  description = "Name of the storage account hosting the website."
  value       = azurerm_storage_account.static_site.name
}
