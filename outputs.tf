#Output for resource group name
output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

#Output for subscription Id 
output "subscription_id" {
  value = azurerm_subscription.current.id
}