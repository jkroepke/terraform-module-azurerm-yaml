output "azurerm_network_security_group" {
  description = "Output of all NSGs declared in this module as map"
  value       = azurerm_network_security_group.this
}

output "azurerm_private_dns_zones" {
  description = "Output of all private DNS zones declared in this module as map"
  value       = azurerm_private_dns_zone.this
}

output "azurerm_resource_groups" {
  description = "Output of all resource groups declared in this module as map"
  value       = azurerm_resource_group.this
}

output "azurerm_route_table" {
  description = "Output of all route tables declared in this module as map"
  value       = azurerm_route_table.this
}

output "azurerm_storage_account" {
  description = "Output of all storage accounts declared in this module as map"
  value       = azurerm_storage_account.this
}

output "azurerm_virtual_network" {
  description = "Output of all virtual networks declared in this module as map"
  value       = azurerm_virtual_network.this
}

output "azurerm_subnet" {
  description = "Output of all virtual network subnets declared in this module as map"
  value       = azurerm_subnet.this
}

output "azurerm_windows_virtual_machine" {
  description = "Output of all azure virtual machines declared in this module as map"
  value       = azurerm_windows_virtual_machine.this
}
