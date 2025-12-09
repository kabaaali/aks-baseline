#!/bin/bash
#
# trigger-backup.sh - Trigger on-demand backup for AKS cluster
#
# Usage: ./trigger-backup.sh [namespace]
#        If namespace is not provided, backs up all configured namespaces
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration (update these or pass as environment variables)
BACKUP_VAULT_NAME="${BACKUP_VAULT_NAME:-bv-aks-backup}"
BACKUP_RG="${BACKUP_RG:-rg-aks-backup}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-automatic-prod}"
AKS_RG="${AKS_RG:-rg-aks-prod}"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    print_info "Prerequisites check passed ✓"
}

# Function to get AKS credentials
get_aks_credentials() {
    print_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group "$AKS_RG" \
        --name "$AKS_CLUSTER_NAME" \
        --overwrite-existing \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_info "AKS credentials retrieved ✓"
    else
        print_error "Failed to get AKS credentials"
        exit 1
    fi
}

# Function to verify backup extension is running
verify_backup_extension() {
    print_info "Verifying backup extension..."
    
    local pods=$(kubectl get pods -n azure-backup --no-headers 2>/dev/null | wc -l)
    
    if [ "$pods" -eq 0 ]; then
        print_error "Backup extension is not running in azure-backup namespace"
        print_info "Please deploy the backup extension first using Terraform"
        exit 1
    fi
    
    print_info "Backup extension is running ($pods pods) ✓"
}

# Function to list available namespaces
list_namespaces() {
    print_info "Available namespaces:"
    kubectl get namespaces --no-headers | awk '{print "  - " $1}'
}

# Function to trigger backup
trigger_backup() {
    local namespace=$1
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    
    if [ -z "$namespace" ]; then
        print_info "Triggering backup for all configured namespaces..."
        backup_name="full-${backup_name}"
    else
        print_info "Triggering backup for namespace: $namespace"
        backup_name="${namespace}-${backup_name}"
    fi
    
    # Get backup instance ID
    local backup_instance=$(az dataprotection backup-instance list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$backup_instance" ]; then
        print_error "No backup instance found in vault $BACKUP_VAULT_NAME"
        print_info "Please ensure Terraform deployment completed successfully"
        exit 1
    fi
    
    print_info "Using backup instance: $backup_instance"
    
    # Trigger on-demand backup
    print_info "Initiating backup job..."
    
    local job_id=$(az dataprotection backup-instance adhoc-backup \
        --name "$backup_instance" \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --backup-rule-name "BackupNow" \
        --retention-tag-override "Default" \
        --query "jobId" -o tsv 2>&1)
    
    if [ $? -eq 0 ]; then
        print_info "Backup job initiated successfully ✓"
        print_info "Job ID: $job_id"
        print_info ""
        print_info "Monitor backup progress with:"
        print_info "  az dataprotection job show \\"
        print_info "    --resource-group $BACKUP_RG \\"
        print_info "    --vault-name $BACKUP_VAULT_NAME \\"
        print_info "    --ids $job_id"
        print_info ""
        
        # Wait for job to start
        print_info "Waiting for backup job to start..."
        sleep 5
        
        # Check job status
        local status=$(az dataprotection job show \
            --resource-group "$BACKUP_RG" \
            --vault-name "$BACKUP_VAULT_NAME" \
            --ids "$job_id" \
            --query "properties.status" -o tsv 2>/dev/null)
        
        if [ -n "$status" ]; then
            print_info "Current status: $status"
        fi
        
        return 0
    else
        print_error "Failed to trigger backup"
        print_error "$job_id"
        return 1
    fi
}

# Function to show recent backups
show_recent_backups() {
    print_info "Recent backups:"
    
    az dataprotection recovery-point list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --backup-instance-name "$(az dataprotection backup-instance list \
            --resource-group "$BACKUP_RG" \
            --vault-name "$BACKUP_VAULT_NAME" \
            --query "[0].name" -o tsv)" \
        --query "[].{Name:name, Time:properties.recoveryPointTime}" \
        --output table 2>/dev/null || print_warn "No backups found yet"
}

# Main script
main() {
    echo ""
    print_info "=== AKS Backup Trigger Script ==="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Get AKS credentials
    get_aks_credentials
    
    # Verify backup extension
    verify_backup_extension
    
    # Parse arguments
    local namespace=""
    if [ $# -gt 0 ]; then
        namespace=$1
        
        # Verify namespace exists
        if ! kubectl get namespace "$namespace" &> /dev/null; then
            print_error "Namespace '$namespace' does not exist"
            list_namespaces
            exit 1
        fi
    else
        print_warn "No namespace specified, will backup all configured namespaces"
        list_namespaces
        echo ""
        read -p "Continue with full backup? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Backup cancelled"
            exit 0
        fi
    fi
    
    # Trigger backup
    if trigger_backup "$namespace"; then
        echo ""
        print_info "=== Backup Summary ==="
        show_recent_backups
        echo ""
        print_info "Backup triggered successfully! ✓"
    else
        echo ""
        print_error "Backup failed!"
        exit 1
    fi
}

# Run main function
main "$@"
