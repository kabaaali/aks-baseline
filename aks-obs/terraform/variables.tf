variable "resource_group_name" {
  description = "Name of the resource group for observability resources"
  type        = string
  default     = "rg-aks-observability"
}

variable "location" {
  description = "Azure region for observability resources"
  type        = string
  default     = "australiaeast"
}

variable "aks_cluster_name" {
  description = "Name of the existing AKS cluster to monitor"
  type        = string
}

variable "aks_resource_group_name" {
  description = "Resource group name of the existing AKS cluster"
  type        = string
}

variable "prometheus_workspace_name" {
  description = "Name of the Azure Monitor Workspace (Managed Prometheus)"
  type        = string
  default     = "amw-aks-prometheus"
}

variable "grafana_name" {
  description = "Name of the Azure Managed Grafana instance"
  type        = string
  default     = "grafana-aks-observability"
}

variable "grafana_zone_redundancy" {
  description = "Enable zone redundancy for Grafana (requires Premium SKU in supported regions)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "AKS-Observability"
  }
}

variable "enable_alert_rules" {
  description = "Enable deployment of Prometheus alert rules"
  type        = bool
  default     = true
}

variable "alert_notification_email" {
  description = "Email address for alert notifications (optional)"
  type        = string
  default     = ""
}
