output "tenant_id" { value = data.azurerm_subscription.current.tenant_id }
output "subscription_id" { value = data.azurerm_subscription.current.subscription_id }
output "resource_group" { value = azurerm_resource_group.lab.name }
output "lab_user_upn" { value = azuread_user.lab_user.user_principal_name }
output "vm_public_ip" { value = azurerm_public_ip.vm.ip_address }
output "storage_account" { value = azurerm_storage_account.lab.name }

output "public_blob_url" {
  value = "http://${azurerm_storage_account.lab.name}.blob.core.windows.net/${azurerm_storage_container.public.name}/${azurerm_storage_blob.fake_pii.name}"
}

output "lab_password" {
  value     = random_password.lab.result
  sensitive = true
}
