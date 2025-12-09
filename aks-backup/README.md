# AKS Automatic Cluster Backup Solution

Complete backup and disaster recovery solution for Azure Kubernetes Service (AKS) Automatic clusters using Azure Backup for AKS.

## 📊 Overview

This solution provides enterprise-grade backup capabilities for AKS clusters with:

- **Automated Backups** - Daily, weekly, and monthly schedules
- **Application-Consistent** - Captures complete cluster state
- **Cross-Region DR** - Restore to different Azure regions
- **Namespace Granularity** - Backup and restore specific namespaces
- **Infrastructure as Code** - Terraform for repeatable deployments

## 🏗️ Architecture

The solution uses Azure Backup for AKS with the following components:

- **Azure Backup Vault** - Central backup management and storage
- **AKS Backup Extension** - Agent deployed in cluster
- **Storage Account** - Backup artifacts and metadata
- **Managed Identity** - Secure authentication
- **Backup Policies** - Automated scheduling and retention

For detailed architecture, see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 📁 Project Structure

```
aks-backup/
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Backup vault and extension
│   ├── backup-policies.tf     # Daily/weekly/monthly policies
│   ├── variables.tf           # Configuration variables
│   ├── outputs.tf             # Deployment outputs
│   └── terraform.tfvars.example
├── scripts/                    # Automation Scripts
│   ├── trigger-backup.sh      # On-demand backup
│   ├── restore-cluster.sh     # Restore from backup
│   └── monitor-backups.sh     # Health monitoring
├── manifests/                  # Kubernetes Manifests
│   └── backup-config.yaml     # Backup configuration
└── docs/                       # Documentation
    ├── ARCHITECTURE.md         # Architecture & design
    ├── ENGINEERING_GUIDE.md    # Technical implementation
    ├── DEPLOYMENT.md           # Deployment guide
    ├── RESTORE_PROCEDURES.md   # Restore procedures
    ├── DISASTER_RECOVERY.md    # DR playbook
    └── TROUBLESHOOTING.md      # Troubleshooting guide
```

## 🎯 What Gets Backed Up

### ✅ Included
- Deployments, StatefulSets, DaemonSets
- Services, Ingress
- ConfigMaps, Secrets (encrypted)
- PersistentVolumeClaims and data
- Custom Resource Definitions (CRDs)
- RBAC roles and bindings

### ❌ Excluded
- Running pod state (ephemeral)
- Node configurations
- AKS control plane settings
- Container images (must be in registry)

## 🚀 Quick Start

### Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.5.0
- Existing AKS Automatic cluster
- kubectl configured for your cluster

### 1. Deploy Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AKS cluster details

terraform init
terraform plan
terraform apply
```

### 2. Verify Backup Extension

```bash
kubectl get pods -n azure-backup
```

### 3. Trigger First Backup

```bash
cd ../scripts
./trigger-backup.sh
```

### 4. Monitor Backup Status

```bash
./monitor-backups.sh
```

## 📋 Backup Policies

| Policy | Frequency | Retention | Use Case |
|--------|-----------|-----------|----------|
| **Daily** | 2:00 AM UTC | 7 days | Operational recovery |
| **Weekly** | Sunday 3:00 AM | 4 weeks | Compliance |
| **Monthly** | 1st of month 4:00 AM | 12 months | Long-term archival |
| **Hourly** | Every hour (optional) | 24 hours | Critical workloads |

## 🔄 Recovery Objectives

- **RPO (Recovery Point Objective):** 24 hours (daily backups)
- **RTO (Recovery Time Objective):** 
  - Namespace restore: 15-30 minutes
  - Full cluster restore: 1-2 hours
  - Cross-region DR: 2-4 hours

## 📚 Documentation

### Getting Started
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment
- **[Architecture](docs/ARCHITECTURE.md)** - Solution design and components

### Operations
- **[Restore Procedures](docs/RESTORE_PROCEDURES.md)** - How to restore from backup
- **[Disaster Recovery](docs/DISASTER_RECOVERY.md)** - DR planning and procedures
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Technical
- **[Engineering Guide](docs/ENGINEERING_GUIDE.md)** - Technical implementation details

## 💰 Cost Estimate

**Example:** Medium AKS cluster (500 GB PVs, 3 namespaces)

```
Backup Vault:           $15/month
Daily Backups (7):      $35/month
Monthly Backups (12):   $60/month
Snapshots:              $25/month
Total:                  ~$135/month
```

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed cost breakdown.

## 🔒 Security Features

- **Encryption at Rest** - AES-256 encryption
- **Encryption in Transit** - TLS 1.2+
- **RBAC Integration** - Azure AD-based access control
- **Managed Identity** - No credentials in code
- **Soft Delete** - 14-day retention for deleted backups
- **Private Endpoints** - Network isolation (optional)

## 🛠️ Common Operations

### Trigger On-Demand Backup

```bash
# Backup all configured namespaces
./scripts/trigger-backup.sh

# Backup specific namespace
./scripts/trigger-backup.sh production
```

### List Available Backups

```bash
./scripts/monitor-backups.sh
```

### Restore Namespace

```bash
./scripts/restore-cluster.sh <recovery-point-id> <namespace>
```

### Check Backup Health

```bash
./scripts/monitor-backups.sh
```

## 🎓 Best Practices

1. **Test Restores Regularly**
   - Monthly restore tests
   - Quarterly DR drills
   - Document actual RTO/RPO

2. **Namespace Organization**
   - Group related apps in same namespace
   - Use labels for backup filtering
   - Separate prod/staging/dev

3. **Cost Optimization**
   - Exclude non-critical namespaces
   - Use appropriate retention periods
   - Monitor storage consumption

4. **Security**
   - Use managed identities
   - Enable private endpoints
   - Regular access reviews

## 🔧 Customization

### Adjust Backup Schedule

Edit `terraform/backup-policies.tf`:

```hcl
backup_repeating_time_intervals = ["R/2024-01-01T03:00:00+00:00/P1D"]
```

### Change Retention Period

```hcl
life_cycle {
  duration        = "P14D"  # 14 days instead of 7
  data_store_type = "OperationalStore"
}
```

### Filter Namespaces

Edit `terraform.tfvars`:

```hcl
backup_namespaces = ["production", "staging"]
exclude_namespaces = ["dev", "test"]
```

## 📊 Monitoring

### Azure Monitor Integration

```bash
# Enable diagnostic logs
az monitor diagnostic-settings create \
  --name backup-diagnostics \
  --resource <backup-vault-id> \
  --workspace <log-analytics-workspace-id> \
  --logs '[{"category": "AzureBackupReport", "enabled": true}]'
```

### Metrics to Track

- Backup success rate
- Backup duration
- Storage consumption
- Failed backup count
- Recovery point count

## 🆘 Troubleshooting

### Backup Extension Not Running

```bash
kubectl get pods -n azure-backup
kubectl logs -n azure-backup -l app=backup-controller
```

### Backup Fails

```bash
# Check backup job status
az dataprotection job list \
  --resource-group rg-aks-backup \
  --vault-name bv-aks-backup
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions.

## 🤝 Contributing

To extend this solution:

1. Add custom backup hooks in `manifests/backup-config.yaml`
2. Create additional policies in `terraform/backup-policies.tf`
3. Extend scripts for specific use cases
4. Update documentation with your changes

## 📝 License

This project is provided as-is for use with Azure AKS clusters.

## 🔗 References

- [Azure Backup for AKS Documentation](https://learn.microsoft.com/azure/backup/azure-kubernetes-service-backup-overview)
- [AKS Automatic Documentation](https://learn.microsoft.com/azure/aks/intro-aks-automatic)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**For detailed deployment instructions, see [DEPLOYMENT.md](docs/DEPLOYMENT.md)**
