# output for the subscription.
output "subscription_id" {
  description = "Azure Subscription ID"
  value       = var.subscription_id
}

# output for te resource gruop.
  output "resource_group_id" {
    description = "Resource Group Name"
    value       = azurerm_resource_group.rg.id
  }
