#Subscription Id for project
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

#Resource goup Id for project
variable "resource_group_name" {
  default = "myTFResourceGroup"
}