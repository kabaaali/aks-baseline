# Daily Backup Policy
resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "daily" {
  name                = "policy-aks-daily"
  resource_group_name = azurerm_resource_group.backup.name
  vault_name          = azurerm_data_protection_backup_vault.aks.name
  
  backup_repeating_time_intervals = ["R/2024-01-01T02:00:00+00:00/P1D"]
  
  retention_rule {
    name     = "Daily"
    priority = 25
    
    life_cycle {
      duration        = "P7D"
      data_store_type = "OperationalStore"
    }
    
    criteria {
      absolute_criteria = "FirstOfDay"
    }
  }
  
  retention_rule {
    name     = "Default"
    priority = 90
    
    life_cycle {
      duration        = "P7D"
      data_store_type = "OperationalStore"
    }
  }
  
  default_retention_rule {
    life_cycle {
      duration        = "P7D"
      data_store_type = "OperationalStore"
    }
  }
}

# Weekly Backup Policy
resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "weekly" {
  name                = "policy-aks-weekly"
  resource_group_name = azurerm_resource_group.backup.name
  vault_name          = azurerm_data_protection_backup_vault.aks.name
  
  backup_repeating_time_intervals = ["R/2024-01-07T03:00:00+00:00/P1W"]
  
  retention_rule {
    name     = "Weekly"
    priority = 20
    
    life_cycle {
      duration        = "P4W"
      data_store_type = "OperationalStore"
    }
    
    criteria {
      absolute_criteria = "FirstOfWeek"
      days_of_week      = ["Sunday"]
    }
  }
  
  retention_rule {
    name     = "Default"
    priority = 90
    
    life_cycle {
      duration        = "P4W"
      data_store_type = "OperationalStore"
    }
  }
  
  default_retention_rule {
    life_cycle {
      duration        = "P4W"
      data_store_type = "OperationalStore"
    }
  }
}

# Monthly Backup Policy
resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "monthly" {
  name                = "policy-aks-monthly"
  resource_group_name = azurerm_resource_group.backup.name
  vault_name          = azurerm_data_protection_backup_vault.aks.name
  
  backup_repeating_time_intervals = ["R/2024-01-01T04:00:00+00:00/P1M"]
  
  retention_rule {
    name     = "Monthly"
    priority = 15
    
    life_cycle {
      duration        = "P12M"
      data_store_type = "OperationalStore"
    }
    
    criteria {
      absolute_criteria = "FirstOfMonth"
    }
  }
  
  retention_rule {
    name     = "Default"
    priority = 90
    
    life_cycle {
      duration        = "P12M"
      data_store_type = "OperationalStore"
    }
  }
  
  default_retention_rule {
    life_cycle {
      duration        = "P12M"
      data_store_type = "OperationalStore"
    }
  }
}

# Hourly Backup Policy (for critical workloads)
resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "hourly" {
  count               = var.enable_hourly_backup ? 1 : 0
  name                = "policy-aks-hourly"
  resource_group_name = azurerm_resource_group.backup.name
  vault_name          = azurerm_data_protection_backup_vault.aks.name
  
  backup_repeating_time_intervals = ["R/2024-01-01T00:00:00+00:00/PT1H"]
  
  retention_rule {
    name     = "Hourly"
    priority = 30
    
    life_cycle {
      duration        = "P1D"
      data_store_type = "OperationalStore"
    }
    
    criteria {
      absolute_criteria = "AllBackup"
    }
  }
  
  default_retention_rule {
    life_cycle {
      duration        = "P1D"
      data_store_type = "OperationalStore"
    }
  }
}
