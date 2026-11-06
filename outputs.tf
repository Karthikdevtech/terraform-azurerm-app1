output "website_url" {
  description = "HTTP URL of the Nginx website hosted on the VM."
  value       = "http://${azurerm_public_ip.app.ip_address}"
}

output "vm_public_ip" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.app.ip_address
}

output "ssh_command" {
  description = "SSH command for connecting from the allowed source network."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.app.ip_address}"
}

output "resource_group_name" {
  description = "Name of the resource group created by this module."
  value       = azurerm_resource_group.app.name
}
