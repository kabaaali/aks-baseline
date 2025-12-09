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
  features {}
}

provider "azapi" {}

# Data source for existing AKS cluster
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

# Resource Group for Observability Resources
resource "azurerm_resource_group" "observability" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Azure Monitor Workspace (Managed Prometheus)
resource "azurerm_monitor_workspace" "prometheus" {
  name                = var.prometheus_workspace_name
  resource_group_name = azurerm_resource_group.observability.name
  location            = azurerm_resource_group.observability.location
  tags                = var.tags
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "grafana" {
  name                              = var.grafana_name
  resource_group_name               = azurerm_resource_group.observability.name
  location                          = azurerm_resource_group.observability.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true
  zone_redundancy_enabled           = var.grafana_zone_redundancy
  
  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  tags = var.tags
}

# Role assignment for Grafana to read Prometheus data
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "aks" {
  name                = "${var.aks_cluster_name}-dce"
  resource_group_name = azurerm_resource_group.observability.name
  location            = azurerm_resource_group.observability.location
  kind                = "Linux"
  tags                = var.tags
}

# Data Collection Rule for AKS Prometheus metrics
resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  name                        = "${var.aks_cluster_name}-prometheus-dcr"
  resource_group_name         = azurerm_resource_group.observability.name
  location                    = azurerm_resource_group.observability.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks.id
  kind                        = "Linux"
  tags                        = var.tags

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  description = "Data collection rule for AKS Prometheus metrics"
}

# Associate DCR with AKS cluster
resource "azurerm_monitor_data_collection_rule_association" "aks_prometheus" {
  name                    = "${var.aks_cluster_name}-dcra"
  target_resource_id      = data.azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus.id
  description             = "Association between AKS cluster and Prometheus DCR"
}

# Enable Container Insights on AKS (required for Prometheus integration)
resource "azapi_update_resource" "aks_monitoring" {
  type        = "Microsoft.ContainerService/managedClusters@2023-10-01"
  resource_id = data.azurerm_kubernetes_cluster.aks.id

  body = jsonencode({
    properties = {
      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricLabelsAllowlist = ""
            metricAnnotationsAllowList = ""
          }
        }
      }
    }
  })
}

# Prometheus Alert Rules (deployed as ConfigMap via kubectl)
# Note: These will be applied separately using kubectl after Terraform deployment
resource "null_resource" "deploy_alert_rules" {
  depends_on = [
    azurerm_monitor_data_collection_rule_association.aks_prometheus
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Alert rules should be deployed using kubectl apply -f ../prometheus/alert-rules.yaml"
      echo "Recording rules should be deployed using kubectl apply -f ../prometheus/recording-rules.yaml"
    EOT
  }
}
