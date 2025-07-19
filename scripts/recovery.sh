#!/usr/bin/env bash

# NixOS Configuration Recovery Script
# Provides comprehensive system recovery capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/nixconf-backups}"
RECOVERY_LOG="${RECOVERY_LOG:-/tmp/nixconf-recovery.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$RECOVERY_LOG" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$RECOVERY_LOG" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$RECOVERY_LOG" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$RECOVERY_LOG" >&2
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

NixOS Configuration Recovery System

COMMANDS:
    system-rollback     Rollback to previous system generation
    snapshot-restore    Restore from filesystem snapshot
    config-restore      Restore configuration from backup
    emergency-boot      Boot into emergency recovery mode
    hardware-detect     Detect and recreate hardware configuration
    network-restore     Restore network connectivity
    user-recover        Recover user data and settings
    full-recovery       Complete system recovery process
    status              Show recovery status and options

OPTIONS:
    -g, --generation NUM    Specific generation number for rollback
    -s, --snapshot NAME     Specific snapshot for restore
    -b, --backup NAME       Specific backup for restore
    -f, --force             Force recovery without confirmation
    -d, --dry-run           Show what would be done without executing
    -v, --verbose           Verbose output
    -h, --help              Show this help

EXAMPLES:
    $0 system-rollback                    # Rollback to previous generation
    $0 system-rollback -g 42             # Rollback to generation 42
    $0 snapshot-restore -s root@20240119 # Restore from specific snapshot
    $0 config-restore -b nixconf_backup_20240119_143022
    $0 full-recovery                      # Complete recovery process

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for system recovery operations"
        exit 1
    fi
}

# Initialize recovery environment
init_recovery() {
    log_info "Initializing recovery environment..."
    
    # Create recovery log
    mkdir -p "$(dirname "$RECOVERY_LOG")"
    touch "$RECOVERY_LOG"
    
    # Record recovery start
    echo "=== Recovery Session Started: $(date) ===" >> "$RECOVERY_LOG"
    
    # Check system state
    log_info "Checking system state..."
    
    # Check if NixOS
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
        log_error "Not running on NixOS or nixos-rebuild not available"
        exit 1
    fi
    
    # Check filesystem
    local root_fs=$(findmnt -n -o FSTYPE /)
    log_info "Root filesystem: $root_fs"
    
    # Check available recovery options
    log_info "Available recovery options:"
    
    # Check for system generations
    if ls /nix/var/nix/profiles/system-*-link >/dev/null 2>&1; then
        local gen_count=$(ls /nix/var/nix/profiles/system-*-link | wc -l)
        log_info "  System generations: $gen_count available"
    else
        log_warning "  No system generations found"
    fi
    
    # Check for snapshots
    if command -v snapper >/dev/null 2>&1; then
        log_info "  BTRFS snapshots: snapper available"
    elif command -v zfs >/dev/null 2>&1; then
        log_info "  ZFS snapshots: zfs available"
    else
        log_warning "  No snapshot system detected"
    fi
    
    # Check for backups
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | wc -l)
        log_info "  Configuration backups: $backup_count available"
    else
        log_warning "  No backup directory found"
    fi
}

# System generation rollback
system_rollback() {
    local target_generation="${1:-}"
    
    log_info "Performing system rollback..."
    
    # Show current generation
    local current_gen=$(nixos-rebuild list-generations | tail -1 | awk '{print $1}')
    log_info "Current generation: $current_gen"
    
    # List available generations
    log_info "Available generations:"
    nixos-rebuild list-generations | tail -10
    
    # Determine target generation
    if [[ -z "$target_generation" ]]; then
        # Get previous generation
        target_generation=$(nixos-rebuild list-generations | tail -2 | head -1 | awk '{print $1}')
        log_info "Using previous generation: $target_generation"
    fi
    
    # Confirm rollback
    if [[ "${FORCE:-}" != "true" ]]; then
        echo -n "Rollback to generation $target_generation? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Rollback cancelled"
            return 0
        fi
    fi
    
    # Perform rollback
    log_info "Rolling back to generation $target_generation..."
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "DRY RUN: Would rollback to generation $target_generation"
        return 0
    fi
    
    # Switch to target generation
    if nixos-rebuild switch --rollback; then
        log_success "Successfully rolled back to generation $target_generation"
        log_info "System will reboot in 10 seconds unless cancelled (Ctrl+C)"
        sleep 10
        systemctl reboot
    else
        log_error "Failed to rollback system"
        return 1
    fi
}

# Snapshot restore
snapshot_restore() {
    local snapshot_name="${1:-}"
    
    log_info "Performing snapshot restore..."
    
    # Detect snapshot system
    if command -v snapper >/dev/null 2>&1; then
        restore_btrfs_snapshot "$snapshot_name"
    elif command -v zfs >/dev/null 2>&1; then
        restore_zfs_snapshot "$snapshot_name"
    else
        log_error "No snapshot system available"
        return 1
    fi
}

# BTRFS snapshot restore
restore_btrfs_snapshot() {
    local snapshot_name="${1:-}"
    
    log_info "Restoring BTRFS snapshot..."
    
    # List available snapshots
    log_info "Available snapshots:"
    snapper list
    
    if [[ -z "$snapshot_name" ]]; then
        log_error "Snapshot name required for restore"
        return 1
    fi
    
    # Confirm restore
    if [[ "${FORCE:-}" != "true" ]]; then
        echo -n "Restore from snapshot $snapshot_name? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Snapshot restore cancelled"
            return 0
        fi
    fi
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "DRY RUN: Would restore from snapshot $snapshot_name"
        return 0
    fi
    
    # Perform restore
    log_info "Restoring from snapshot $snapshot_name..."
    if snapper rollback "$snapshot_name"; then
        log_success "Snapshot restore completed"
        log_info "System will reboot in 10 seconds"
        sleep 10
        systemctl reboot
    else
        log_error "Failed to restore snapshot"
        return 1
    fi
}

# ZFS snapshot restore
restore_zfs_snapshot() {
    local snapshot_name="${1:-}"
    
    log_info "Restoring ZFS snapshot..."
    
    # List available snapshots
    log_info "Available snapshots:"
    zfs list -t snapshot
    
    if [[ -z "$snapshot_name" ]]; then
        log_error "Snapshot name required for restore"
        return 1
    fi
    
    # Confirm restore
    if [[ "${FORCE:-}" != "true" ]]; then
        echo -n "Restore from snapshot $snapshot_name? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Snapshot restore cancelled"
            return 0
        fi
    fi
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "DRY RUN: Would restore from snapshot $snapshot_name"
        return 0
    fi
    
    # Perform restore
    log_info "Restoring from snapshot $snapshot_name..."
    if zfs rollback "$snapshot_name"; then
        log_success "ZFS snapshot restore completed"
        log_info "System will reboot in 10 seconds"
        sleep 10
        systemctl reboot
    else
        log_error "Failed to restore ZFS snapshot"
        return 1
    fi
}

# Configuration restore from backup
config_restore() {
    local backup_name="${1:-}"
    
    log_info "Restoring configuration from backup..."
    
    # Use the backup script for restore
    if [[ -f "$SCRIPT_DIR/backup.sh" ]]; then
        if [[ -n "$backup_name" ]]; then
            "$SCRIPT_DIR/backup.sh" restore "$backup_name"
        else
            log_error "Backup name required for restore"
            return 1
        fi
    else
        log_error "Backup script not found"
        return 1
    fi
}

# Emergency boot recovery
emergency_boot() {
    log_info "Configuring emergency boot recovery..."
    
    # Create emergency boot entry
    cat > /boot/emergency-recovery.sh << 'EOF'
#!/usr/bin/env bash
# Emergency recovery boot script

echo "Emergency Recovery Mode"
echo "======================"
echo ""
echo "Available options:"
echo "1. Boot to previous generation"
echo "2. Boot with minimal configuration"
echo "3. Boot into rescue shell"
echo ""
echo "Select option (1-3): "
read -r option

case "$option" in
    1)
        echo "Booting to previous generation..."
        # Boot to previous generation
        ;;
    2)
        echo "Booting with minimal configuration..."
        # Boot with minimal config
        ;;
    3)
        echo "Starting rescue shell..."
        /bin/bash
        ;;
    *)
        echo "Invalid option, starting rescue shell..."
        /bin/bash
        ;;
esac
EOF
    
    chmod +x /boot/emergency-recovery.sh
    log_success "Emergency boot recovery configured"
}

# Hardware detection and configuration
hardware_detect() {
    log_info "Detecting hardware and recreating configuration..."
    
    # Generate new hardware configuration
    if nixos-generate-config --root / --show-hardware-config > /tmp/hardware-config-new.nix; then
        log_success "New hardware configuration generated"
        
        # Compare with existing
        if [[ -f /etc/nixos/hardware-configuration.nix ]]; then
            log_info "Comparing with existing configuration..."
            diff /etc/nixos/hardware-configuration.nix /tmp/hardware-config-new.nix || true
        fi
        
        # Offer to replace
        if [[ "${FORCE:-}" != "true" ]]; then
            echo -n "Replace existing hardware configuration? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                cp /tmp/hardware-config-new.nix /etc/nixos/hardware-configuration.nix
                log_success "Hardware configuration updated"
            fi
        fi
    else
        log_error "Failed to generate hardware configuration"
        return 1
    fi
}

# Network restoration
network_restore() {
    log_info "Restoring network connectivity..."
    
    # Check network interfaces
    log_info "Available network interfaces:"
    ip link show
    
    # Try to bring up interfaces
    for interface in $(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | cut -d: -f2 | tr -d ' '); do
        log_info "Trying to bring up interface: $interface"
        ip link set "$interface" up
        
        # Try DHCP
        if command -v dhcpcd >/dev/null 2>&1; then
            dhcpcd "$interface" &
        elif command -v dhclient >/dev/null 2>&1; then
            dhclient "$interface" &
        fi
    done
    
    # Wait for network
    sleep 5
    
    # Test connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity restored"
    else
        log_warning "Network connectivity not restored automatically"
        log_info "Manual network configuration may be required"
    fi
}

# User data recovery
user_recover() {
    local username="${1:-jontk}"
    
    log_info "Recovering user data for: $username"
    
    # Check if user exists
    if ! id "$username" >/dev/null 2>&1; then
        log_error "User $username does not exist"
        return 1
    fi
    
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    log_info "User home directory: $user_home"
    
    # Check for backed up user data
    if [[ -d "$BACKUP_DIR" ]]; then
        # Look for user data in backups
        local latest_backup=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | sort | tail -1)
        if [[ -n "$latest_backup" ]]; then
            log_info "Found backup with potential user data: $(basename "$latest_backup")"
            
            # Extract user data (if available)
            local temp_dir=$(mktemp -d)
            tar -xzf "$latest_backup" -C "$temp_dir"
            
            if [[ -d "$temp_dir"/*/system-files/.ssh ]]; then
                log_info "Restoring SSH keys..."
                cp -r "$temp_dir"/*/system-files/.ssh "$user_home/"
                chown -R "$username:$(id -gn "$username")" "$user_home/.ssh"
                chmod 700 "$user_home/.ssh"
                chmod 600 "$user_home/.ssh"/*
            fi
            
            if [[ -d "$temp_dir"/*/system-files/.gnupg ]]; then
                log_info "Restoring GPG keys..."
                cp -r "$temp_dir"/*/system-files/.gnupg "$user_home/"
                chown -R "$username:$(id -gn "$username")" "$user_home/.gnupg"
                chmod 700 "$user_home/.gnupg"
            fi
            
            rm -rf "$temp_dir"
        fi
    fi
    
    log_success "User recovery completed"
}

# Full recovery process
full_recovery() {
    log_info "Starting full recovery process..."
    
    # Initialize recovery
    init_recovery
    
    # Step 1: Try system rollback first
    log_info "Step 1: Attempting system rollback..."
    if system_rollback; then
        log_success "System rollback successful, recovery complete"
        return 0
    fi
    
    # Step 2: Try snapshot restore
    log_info "Step 2: Attempting snapshot restore..."
    if snapshot_restore; then
        log_success "Snapshot restore successful, recovery complete"
        return 0
    fi
    
    # Step 3: Network restoration
    log_info "Step 3: Restoring network connectivity..."
    network_restore
    
    # Step 4: Hardware detection
    log_info "Step 4: Detecting hardware..."
    hardware_detect
    
    # Step 5: Configuration restore
    log_info "Step 5: Restoring configuration from backup..."
    local latest_backup=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | sort | tail -1)
    if [[ -n "$latest_backup" ]]; then
        config_restore "$(basename "$latest_backup" .tar.gz)"
    fi
    
    # Step 6: User recovery
    log_info "Step 6: Recovering user data..."
    user_recover
    
    log_success "Full recovery process completed"
}

# Show recovery status
show_status() {
    log_info "Recovery System Status"
    echo "===================="
    
    # System information
    echo "System Information:"
    echo "  Hostname: $(hostname)"
    echo "  Kernel: $(uname -r)"
    echo "  NixOS: $(nixos-version 2>/dev/null || echo "Unknown")"
    echo ""
    
    # Current generation
    if command -v nixos-rebuild >/dev/null 2>&1; then
        echo "System Generations:"
        nixos-rebuild list-generations | tail -3
        echo ""
    fi
    
    # Filesystem information
    echo "Filesystem Information:"
    df -h / | tail -1
    echo "  Type: $(findmnt -n -o FSTYPE /)"
    echo ""
    
    # Available recovery options
    echo "Recovery Options Available:"
    
    # System generations
    if ls /nix/var/nix/profiles/system-*-link >/dev/null 2>&1; then
        local gen_count=$(ls /nix/var/nix/profiles/system-*-link | wc -l)
        echo "  ✓ System generations: $gen_count available"
    else
        echo "  ✗ No system generations found"
    fi
    
    # Snapshots
    if command -v snapper >/dev/null 2>&1; then
        local snap_count=$(snapper list | wc -l)
        echo "  ✓ BTRFS snapshots: $((snap_count - 2)) available"
    elif command -v zfs >/dev/null 2>&1; then
        local zfs_count=$(zfs list -t snapshot 2>/dev/null | wc -l)
        echo "  ✓ ZFS snapshots: $((zfs_count - 1)) available"
    else
        echo "  ✗ No snapshot system available"
    fi
    
    # Backups
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | wc -l)
        echo "  ✓ Configuration backups: $backup_count available"
        if [[ $backup_count -gt 0 ]]; then
            local latest=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | sort | tail -1)
            echo "    Latest: $(basename "$latest")"
        fi
    else
        echo "  ✗ No backup directory found"
    fi
    
    # Network
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "  ✓ Network connectivity available"
    else
        echo "  ✗ No network connectivity"
    fi
}

# Main function
main() {
    local command=""
    local target=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--generation)
                target="$2"
                shift 2
                ;;
            -s|--snapshot)
                target="$2"
                shift 2
                ;;
            -b|--backup)
                target="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            system-rollback|snapshot-restore|config-restore|emergency-boot|hardware-detect|network-restore|user-recover|full-recovery|status)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate command
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        show_usage
        exit 1
    fi
    
    # Check if we need root for system operations
    case "$command" in
        system-rollback|snapshot-restore|emergency-boot|hardware-detect|network-restore|full-recovery)
            check_root
            ;;
    esac
    
    # Execute command
    case "$command" in
        system-rollback)
            system_rollback "$target"
            ;;
        snapshot-restore)
            snapshot_restore "$target"
            ;;
        config-restore)
            config_restore "$target"
            ;;
        emergency-boot)
            emergency_boot
            ;;
        hardware-detect)
            hardware_detect
            ;;
        network-restore)
            network_restore
            ;;
        user-recover)
            user_recover "$target"
            ;;
        full-recovery)
            full_recovery
            ;;
        status)
            show_status
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"