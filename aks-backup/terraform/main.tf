terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azapi" {}

# Data source for existing AKS cluster
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

data "azurerm_client_config" "current" {}

# Resource Group for Backup Resources
resource "azurerm_resource_group" "backup" {
  name     = var.backup_resource_group_name
  location = var.location
  tags     = var.tags
}

# Storage Account for Backup Data
resource "azurerm_storage_account" "backup" {
  name                     = var.backup_storage_account_name
  resource_group_name      = azurerm_resource_group.backup.name
  location                 = azurerm_resource_group.backup.location
  account_tier             = "Standard"
  account_replication_type = var.storage_redundancy
  account_kind             = "StorageV2"
  access_tier              = "Cool"
  
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = var.tags
}

# Storage Container for Backup Artifacts
resource "azurerm_storage_container" "backup" {
  name                  = "aks-backups"
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"
}

# Azure Backup Vault
resource "azurerm_data_protection_backup_vault" "aks" {
  name                = var.backup_vault_name
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location
  datastore_type      = "VaultStore"
  redundancy          = var.vault_redundancy
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Managed Identity for Backup Operations
resource "azurerm_user_assigned_identity" "backup" {
  name                = "id-aks-backup"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location
  tags                = var.tags
}

# Role Assignment: Backup Vault Contributor on AKS Cluster
resource "azurerm_role_assignment" "backup_vault_aks" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
}

# Role Assignment: Backup Identity Contributor on AKS Cluster
resource "azurerm_role_assignment" "backup_identity_aks" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.backup.principal_id
}

# Role Assignment: Storage Blob Data Contributor
resource "azurerm_role_assignment" "backup_storage" {
  scope                = azurerm_storage_account.backup.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
}

# Role Assignment: Snapshot Contributor on AKS Resource Group
resource "azurerm_role_assignment" "backup_snapshot" {
  scope                = data.azurerm_kubernetes_cluster.aks.node_resource_group_id
  role_definition_name = "Disk Snapshot Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
}

# AKS Backup Extension
resource "azapi_resource" "backup_extension" {
  type      = "Microsoft.KubernetesConfiguration/extensions@2023-05-01"
  name      = "azure-aks-backup"
  parent_id = data.azurerm_kubernetes_cluster.aks.id
  
  body = jsonencode({
    properties = {
      extensionType           = "microsoft.dataprotection.kubernetes"
      autoUpgradeMinorVersion = true
      releaseTrain            = "stable"
      configurationSettings = {
        "configuration.backupStorageLocation.bucket"                = azurerm_storage_container.backup.name
        "configuration.backupStorageLocation.config.resourceGroup"  = azurerm_resource_group.backup.name
        "configuration.backupStorageLocation.config.storageAccount" = azurerm_storage_account.backup.name
        "configuration.backupStorageLocation.config.subscriptionId" = data.azurerm_client_config.current.subscription_id
        "credentials.tenantId"                                      = data.azurerm_client_config.current.tenant_id
      }
    }
  })
  
  depends_on = [
    azurerm_role_assignment.backup_vault_aks,
    azurerm_role_assignment.backup_identity_aks,
    azurerm_role_assignment.backup_storage,
    azurerm_role_assignment.backup_snapshot
  ]
}

# Backup Instance for AKS Cluster
resource "azapi_resource" "backup_instance" {
  type      = "Microsoft.DataProtection/backupVaults/backupInstances@2023-05-01"
  name      = "backup-${var.aks_cluster_name}"
  parent_id = azurerm_data_protection_backup_vault.aks.id
  
  body = jsonencode({
    properties = {
      dataSourceInfo = {
        datasourceType   = "Microsoft.ContainerService/managedClusters"
        objectType       = "Datasource"
        resourceID       = data.azurerm_kubernetes_cluster.aks.id
        resourceLocation = data.azurerm_kubernetes_cluster.aks.location
        resourceName     = data.azurerm_kubernetes_cluster.aks.name
        resourceType     = "Microsoft.ContainerService/managedClusters"
        resourceUri      = data.azurerm_kubernetes_cluster.aks.id
      }
      dataSourceSetInfo = {
        datasourceType   = "Microsoft.ContainerService/managedClusters"
        objectType       = "DatasourceSet"
        resourceID       = data.azurerm_kubernetes_cluster.aks.id
        resourceLocation = data.azurerm_kubernetes_cluster.aks.location
        resourceName     = data.azurerm_kubernetes_cluster.aks.name
        resourceType     = "Microsoft.ContainerService/managedClusters"
        resourceUri      = data.azurerm_kubernetes_cluster.aks.id
      }
      friendlyName = "AKS Cluster Backup - ${var.aks_cluster_name}"
      objectType   = "BackupInstance"
      policyInfo = {
        policyId = azurerm_data_protection_backup_policy_kubernetes_cluster.daily.id
      }
    }
  })
  
  depends_on = [
    azapi_resource.backup_extension
  ]
}

# Enable Trusted Access for Backup
resource "azurerm_kubernetes_cluster_trusted_access_role_binding" "backup" {
  kubernetes_cluster_id = data.azurerm_kubernetes_cluster.aks.id
  name                  = "backup-trusted-access"
  roles                 = ["Microsoft.DataProtection/backupVaults/backup-operator"]
  source_resource_id    = azurerm_data_protection_backup_vault.aks.id
}
