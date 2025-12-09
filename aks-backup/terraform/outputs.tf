output "backup_vault_id" {
  description = "Resource ID of the Azure Backup Vault"
  value       = azurerm_data_protection_backup_vault.aks.id
}

output "backup_vault_name" {
  description = "Name of the Azure Backup Vault"
  value       = azurerm_data_protection_backup_vault.aks.name
}

output "storage_account_name" {
  description = "Name of the backup storage account"
  value       = azurerm_storage_account.backup.name
}

output "storage_account_id" {
  description = "Resource ID of the backup storage account"
  value       = azurerm_storage_account.backup.id
}

output "backup_extension_status" {
  description = "Status of the AKS backup extension"
  value       = "Extension deployed - check status with: az k8s-extension show --name azure-aks-backup --cluster-name ${var.aks_cluster_name} --resource-group ${var.aks_resource_group_name} --cluster-type managedClusters"
}

output "managed_identity_id" {
  description = "Resource ID of the backup managed identity"
  value       = azurerm_user_assigned_identity.backup.id
}

output "managed_identity_client_id" {
  description = "Client ID of the backup managed identity"
  value       = azurerm_user_assigned_identity.backup.client_id
}

output "daily_policy_id" {
  description = "Resource ID of the daily backup policy"
  value       = azurerm_data_protection_backup_policy_kubernetes_cluster.daily.id
}

output "weekly_policy_id" {
  description = "Resource ID of the weekly backup policy"
  value       = azurerm_data_protection_backup_policy_kubernetes_cluster.weekly.id
}

output "monthly_policy_id" {
  description = "Resource ID of the monthly backup policy"
  value       = azurerm_data_protection_backup_policy_kubernetes_cluster.monthly.id
}

output "backup_instance_id" {
  description = "Resource ID of the backup instance"
  value       = azapi_resource.backup_instance.id
}

output "next_steps" {
  description = "Next steps for completing backup configuration"
  value = <<-EOT
    
    ✅ AKS Backup Infrastructure Deployed!
    
    Next Steps:
    
    1. Verify Backup Extension:
       kubectl get pods -n azure-backup
       
    2. Trigger On-Demand Backup:
       cd ../scripts
       ./trigger-backup.sh
       
    3. View Backup Status:
       az dataprotection backup-instance list \
         --resource-group ${var.backup_resource_group_name} \
         --vault-name ${var.backup_vault_name}
       
    4. Configure Backup for Specific Namespaces:
       kubectl apply -f ../manifests/backup-config.yaml
       
    5. Test Restore Procedure:
       See docs/RESTORE_PROCEDURES.md
    
    Backup Vault: ${azurerm_data_protection_backup_vault.aks.name}
    Storage Account: ${azurerm_storage_account.backup.name}
    
    Backup Policies:
    - Daily: 2:00 AM UTC (7-day retention)
    - Weekly: Sunday 3:00 AM UTC (4-week retention)
    - Monthly: 1st of month 4:00 AM UTC (12-month retention)
    
  EOT
}

output "backup_vault_resource_group" {
  description = "Resource group containing backup vault"
  value       = azurerm_resource_group.backup.name
}

output "backup_container_name" {
  description = "Name of the storage container for backups"
  value       = azurerm_storage_container.backup.name
}
