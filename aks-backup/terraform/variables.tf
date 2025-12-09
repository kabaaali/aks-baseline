variable "backup_resource_group_name" {
  description = "Name of the resource group for backup resources"
  type        = string
  default     = "rg-aks-backup"
}

variable "location" {
  description = "Azure region for backup resources"
  type        = string
  default     = "australiaeast"
}

variable "aks_cluster_name" {
  description = "Name of the existing AKS cluster to backup"
  type        = string
}

variable "aks_resource_group_name" {
  description = "Resource group name of the existing AKS cluster"
  type        = string
}

variable "backup_vault_name" {
  description = "Name of the Azure Backup Vault"
  type        = string
  default     = "bv-aks-backup"
}

variable "backup_storage_account_name" {
  description = "Name of the storage account for backup data (must be globally unique)"
  type        = string
  default     = "staksbackup"
}

variable "vault_redundancy" {
  description = "Backup vault redundancy (GeoRedundant or LocallyRedundant)"
  type        = string
  default     = "GeoRedundant"
  
  validation {
    condition     = contains(["GeoRedundant", "LocallyRedundant"], var.vault_redundancy)
    error_message = "Vault redundancy must be either GeoRedundant or LocallyRedundant."
  }
}

variable "storage_redundancy" {
  description = "Storage account replication type (GRS, LRS, ZRS, GZRS)"
  type        = string
  default     = "GRS"
  
  validation {
    condition     = contains(["GRS", "LRS", "ZRS", "GZRS"], var.storage_redundancy)
    error_message = "Storage redundancy must be GRS, LRS, ZRS, or GZRS."
  }
}

variable "enable_hourly_backup" {
  description = "Enable hourly backup policy for critical workloads"
  type        = bool
  default     = false
}

variable "backup_namespaces" {
  description = "List of namespaces to include in backup (empty = all namespaces)"
  type        = list(string)
  default     = []
}

variable "exclude_namespaces" {
  description = "List of namespaces to exclude from backup"
  type        = list(string)
  default = [
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "azure-backup"
  ]
}

variable "enable_soft_delete" {
  description = "Enable soft delete for backup vault (14-day retention)"
  type        = bool
  default     = true
}

variable "enable_cross_region_restore" {
  description = "Enable cross-region restore capability"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all backup resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "AKS-Backup"
  }
}

variable "backup_retention_days" {
  description = "Default backup retention in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 9999
    error_message = "Backup retention must be between 1 and 9999 days."
  }
}

variable "enable_diagnostic_logs" {
  description = "Enable diagnostic logs for backup vault"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic logs (optional)"
  type        = string
  default     = ""
}
