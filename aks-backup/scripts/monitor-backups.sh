#!/bin/bash
#
# monitor-backups.sh - Monitor backup status and health
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BACKUP_VAULT_NAME="${BACKUP_VAULT_NAME:-bv-aks-backup}"
BACKUP_RG="${BACKUP_RG:-rg-aks-backup}"

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show backup jobs
show_backup_jobs() {
    print_info "Recent Backup Jobs:"
    echo ""
    
    az dataprotection job list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --query "[].{Job:name, Status:properties.status, StartTime:properties.startTime, Duration:properties.duration}" \
        --output table 2>/dev/null || print_warn "No backup jobs found"
}

# Show recovery points
show_recovery_points() {
    print_info "Available Recovery Points:"
    echo ""
    
    local backup_instance=$(az dataprotection backup-instance list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -n "$backup_instance" ]; then
        az dataprotection recovery-point list \
            --resource-group "$BACKUP_RG" \
            --vault-name "$BACKUP_VAULT_NAME" \
            --backup-instance-name "$backup_instance" \
            --query "[].{RecoveryPoint:name, Time:properties.recoveryPointTime}" \
            --output table 2>/dev/null || print_warn "No recovery points found"
    else
        print_warn "No backup instance found"
    fi
}

# Check backup health
check_backup_health() {
    print_info "Backup Health Check:"
    echo ""
    
    # Check backup instance status
    local instance_status=$(az dataprotection backup-instance list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --query "[0].properties.protectionStatus.status" -o tsv 2>/dev/null)
    
    if [ "$instance_status" == "ProtectionConfigured" ]; then
        print_info "✓ Backup instance is healthy"
    else
        print_warn "⚠ Backup instance status: $instance_status"
    fi
    
    # Check for failed jobs in last 24 hours
    local failed_jobs=$(az dataprotection job list \
        --resource-group "$BACKUP_RG" \
        --vault-name "$BACKUP_VAULT_NAME" \
        --query "[?properties.status=='Failed'].name" -o tsv 2>/dev/null | wc -l)
    
    if [ "$failed_jobs" -eq 0 ]; then
        print_info "✓ No failed backup jobs in recent history"
    else
        print_error "✗ $failed_jobs failed backup job(s) detected"
    fi
}

# Main
main() {
    echo ""
    print_info "=== AKS Backup Monitoring ==="
    echo ""
    
    check_backup_health
    echo ""
    show_backup_jobs
    echo ""
    show_recovery_points
    echo ""
}

main "$@"
