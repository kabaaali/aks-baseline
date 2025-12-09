output "grafana_endpoint" {
  description = "URL to access the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.endpoint
}

output "grafana_id" {
  description = "Resource ID of the Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.id
}

output "prometheus_workspace_id" {
  description = "Resource ID of the Azure Monitor Workspace (Prometheus)"
  value       = azurerm_monitor_workspace.prometheus.id
}

output "prometheus_query_endpoint" {
  description = "Query endpoint for Prometheus workspace"
  value       = azurerm_monitor_workspace.prometheus.query_endpoint
}

output "data_collection_endpoint_id" {
  description = "Resource ID of the data collection endpoint"
  value       = azurerm_monitor_data_collection_endpoint.aks.id
}

output "data_collection_rule_id" {
  description = "Resource ID of the data collection rule"
  value       = azurerm_monitor_data_collection_rule.aks_prometheus.id
}

output "next_steps" {
  description = "Instructions for completing the setup"
  value = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    Next steps:
    1. Access Grafana: ${azurerm_dashboard_grafana.grafana.endpoint}
    2. Import dashboards from ../dashboards/ directory
    3. Deploy alert rules: kubectl apply -f ../prometheus/alert-rules.yaml
    4. Deploy recording rules: kubectl apply -f ../prometheus/recording-rules.yaml
    5. Configure alert notifications in Grafana
    
    Prometheus Query Endpoint: ${azurerm_monitor_workspace.prometheus.query_endpoint}
  EOT
}
