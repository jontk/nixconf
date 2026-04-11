#!/usr/bin/env bash
# Automated rollback script for Nix configuration
# This script handles rolling back to previous system generations or configuration backups

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$CONFIG_ROOT/backups"
LOG_DIR="$CONFIG_ROOT/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ROLLBACK_TIMEOUT=600  # 10 minutes

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_color "$GREEN" "✓ $1"
}

print_error() {
    print_color "$RED" "✗ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠ $1"
}

print_info() {
    print_color "$BLUE" "ℹ $1"
}

print_step() {
    print_color "$PURPLE" "▶ $1"
}

print_header() {
    echo ""
    print_color "$CYAN" "=== $1 ==="
    echo ""
}

# Function to log messages with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/rollback.log"
}

# Function to detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ -f "/etc/nixos/configuration.nix" ]] || [[ -f "/etc/nixos/flake.nix" ]]; then
        echo "nixos"
    else
        echo "unknown"
    fi
}

# Function to show help
show_help() {
    cat << EOF
Nix Configuration Rollback Script

Usage: $0 [OPTIONS] [COMMAND] [TARGET]

Commands:
  list            List available rollback targets
  generation      Rollback to a specific system generation
  backup          Restore from a configuration backup
  git             Rollback to a specific git commit
  previous        Rollback to the previous generation (default)
  emergency       Emergency rollback (most recent known-good state)
  help            Show this help message

Options:
  --dry-run       Show what would be done without executing
  --force         Force rollback even if target seems risky
  --no-verify     Skip verification after rollback
  --interactive   Interactive selection of rollback target
  --timeout=N     Set timeout for operations (seconds)

Examples:
  $0                          # Rollback to previous generation
  $0 list                     # Show available rollback options
  $0 generation 42            # Rollback to generation 42
  $0 backup config_backup_20231201_120000.tar.gz
  $0 git HEAD~3               # Rollback to 3 commits ago
  $0 --interactive            # Interactive rollback selection
  $0 emergency                # Emergency rollback to last known good

The script supports rolling back:
- System generations (NixOS/nix-darwin)
- Home Manager generations
- Configuration backups (tar.gz files)
- Git commits
- Emergency recovery scenarios

EOF
}

# Function to parse command line arguments
parse_args() {
    COMMAND="previous"
    TARGET=""
    DRY_RUN=false
    FORCE=false
    NO_VERIFY=false
    INTERACTIVE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            list|generation|backup|git|previous|emergency)
                COMMAND="$1"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --no-verify)
                NO_VERIFY=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --timeout=*)
                ROLLBACK_TIMEOUT="${1#*=}"
                shift
                ;;
            --help|-h|help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                TARGET="$1"
                shift
                ;;
        esac
    done
}

# Function to list system generations
list_system_generations() {
    local platform
    platform=$(detect_platform)
    
    print_step "Available system generations:"
    
    case $platform in
        darwin)
            if command -v darwin-rebuild >/dev/null 2>&1; then
                darwin-rebuild --list-generations | tail -10
            else
                print_error "darwin-rebuild not available"
                return 1
            fi
            ;;
        nixos)
            if command -v nixos-rebuild >/dev/null 2>&1; then
                sudo nixos-rebuild list-generations | tail -10
            else
                print_error "nixos-rebuild not available"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported platform for generation listing"
            return 1
            ;;
    esac
}

# Function to list home manager generations
list_home_generations() {
    print_step "Available Home Manager generations:"
    
    if command -v home-manager >/dev/null 2>&1; then
        home-manager generations | head -10
    else
        print_warning "Home Manager not available"
    fi
}

# Function to list configuration backups
list_backups() {
    print_step "Available configuration backups:"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        # shellcheck disable=SC2012 # ls sort by mtime is portable across BSD/GNU
        ls -1t "$BACKUP_DIR"/config_backup_*.tar.gz 2>/dev/null | head -10 | while read -r backup; do
            local filename
            local size
            local date
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date=$(echo "$filename" | sed 's/config_backup_\([0-9]\{8\}_[0-9]\{6\}\)\.tar\.gz/\1/' | sed 's/_/ /' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
            echo "  $filename ($size, $date)"
        done
    else
        print_warning "No backup directory found at $BACKUP_DIR"
    fi
}

# Function to list git commits
list_git_commits() {
    print_step "Recent git commits (last 10):"
    
    cd "$CONFIG_ROOT"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git log --oneline -10
    else
        print_error "Not in a git repository"
        return 1
    fi
}

# Function to list all available rollback targets
list_all_targets() {
    print_header "Available Rollback Targets"
    
    list_system_generations
    echo ""
    list_home_generations
    echo ""
    list_backups
    echo ""
    list_git_commits
}

# Function to interactive selection
interactive_selection() {
    print_header "Interactive Rollback Selection"
    
    echo "Select rollback type:"
    echo "1) System generation"
    echo "2) Home Manager generation"
    echo "3) Configuration backup"
    echo "4) Git commit"
    echo "5) Cancel"
    
    read -r -p "Enter choice (1-5): " choice
    
    case $choice in
        1)
            COMMAND="generation"
            list_system_generations
            read -r -p "Enter generation number: " TARGET
            ;;
        2)
            COMMAND="home-generation"
            list_home_generations
            read -r -p "Enter generation ID: " TARGET
            ;;
        3)
            COMMAND="backup"
            list_backups
            read -r -p "Enter backup filename: " TARGET
            ;;
        4)
            COMMAND="git"
            list_git_commits
            read -r -p "Enter commit hash or reference: " TARGET
            ;;
        5)
            print_info "Rollback cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Function to confirm risky operations
confirm_operation() {
    local operation="$1"
    local target="$2"
    
    if [[ "$FORCE" == true ]]; then
        print_warning "Forcing operation without confirmation (--force specified)"
        return 0
    fi
    
    print_warning "You are about to $operation to: $target"
    print_warning "This will change your system configuration."
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

# Function to create emergency backup before rollback
create_emergency_backup() {
    print_step "Creating emergency backup before rollback"

    local timestamp
    local backup_file
    timestamp=$(date '+%Y%m%d_%H%M%S')
    backup_file="$BACKUP_DIR/emergency_backup_${timestamp}.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    # Create backup of current state
    tar -czf "$backup_file" \
        --exclude='.git' \
        --exclude='logs' \
        --exclude='backups' \
        --exclude='result*' \
        -C "$CONFIG_ROOT" . \
        2>/dev/null || {
        print_error "Failed to create emergency backup"
        return 1
    }
    
    print_success "Emergency backup created: $backup_file"
    log_message "INFO" "Emergency backup created: $backup_file"
}

# Function to rollback to previous generation
rollback_previous_generation() {
    local platform
    platform=$(detect_platform)
    
    print_step "Rolling back to previous system generation"
    
    case $platform in
        darwin)
            confirm_operation "rollback darwin system" "previous generation"
            
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would run: darwin-rebuild --rollback"
                return 0
            fi
            
            create_emergency_backup
            
            if timeout "$ROLLBACK_TIMEOUT" darwin-rebuild --rollback; then
                print_success "Successfully rolled back to previous Darwin generation"
                log_message "INFO" "Darwin rollback to previous generation completed"
            else
                print_error "Failed to rollback Darwin generation"
                return 1
            fi
            ;;
        nixos)
            confirm_operation "rollback NixOS system" "previous generation"
            
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would run: sudo nixos-rebuild --rollback"
                return 0
            fi
            
            create_emergency_backup
            
            if timeout "$ROLLBACK_TIMEOUT" sudo nixos-rebuild --rollback; then
                print_success "Successfully rolled back to previous NixOS generation"
                log_message "INFO" "NixOS rollback to previous generation completed"
            else
                print_error "Failed to rollback NixOS generation"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported platform for generation rollback"
            return 1
            ;;
    esac
}

# Function to rollback to specific generation
rollback_to_generation() {
    local generation_id="$1"
    local platform
    platform=$(detect_platform)
    
    if [[ -z "$generation_id" ]]; then
        print_error "Generation ID not specified"
        return 1
    fi
    
    print_step "Rolling back to generation $generation_id"
    confirm_operation "rollback system" "generation $generation_id"
    
    case $platform in
        darwin)
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would run: darwin-rebuild switch --switch-generation $generation_id"
                return 0
            fi
            
            create_emergency_backup
            
            if timeout "$ROLLBACK_TIMEOUT" darwin-rebuild switch --switch-generation "$generation_id"; then
                print_success "Successfully rolled back to Darwin generation $generation_id"
                log_message "INFO" "Darwin rollback to generation $generation_id completed"
            else
                print_error "Failed to rollback to Darwin generation $generation_id"
                return 1
            fi
            ;;
        nixos)
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would run: sudo nixos-rebuild switch --switch-generation $generation_id"
                return 0
            fi
            
            create_emergency_backup
            
            if timeout "$ROLLBACK_TIMEOUT" sudo nixos-rebuild switch --switch-generation "$generation_id"; then
                print_success "Successfully rolled back to NixOS generation $generation_id"
                log_message "INFO" "NixOS rollback to generation $generation_id completed"
            else
                print_error "Failed to rollback to NixOS generation $generation_id"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported platform for generation rollback"
            return 1
            ;;
    esac
}

# Function to restore from backup
restore_from_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        print_error "Backup file not specified"
        return 1
    fi
    
    # Handle relative and absolute paths
    if [[ "$backup_file" != /* ]]; then
        backup_file="$BACKUP_DIR/$backup_file"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_step "Restoring from backup: $(basename "$backup_file")"
    confirm_operation "restore from backup" "$(basename "$backup_file")"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would extract: $backup_file to $CONFIG_ROOT"
        return 0
    fi
    
    create_emergency_backup
    
    # Extract backup
    cd "$CONFIG_ROOT"
    if tar -xzf "$backup_file"; then
        print_success "Successfully restored from backup"
        log_message "INFO" "Restored from backup: $backup_file"
        
        # Rebuild system with restored configuration
        print_step "Rebuilding system with restored configuration"
        local platform
        platform=$(detect_platform)
        
        case $platform in
            darwin)
                if timeout "$ROLLBACK_TIMEOUT" darwin-rebuild switch --flake .; then
                    print_success "System rebuilt with restored configuration"
                else
                    print_error "Failed to rebuild system after restore"
                    return 1
                fi
                ;;
            nixos)
                if timeout "$ROLLBACK_TIMEOUT" sudo nixos-rebuild switch --flake .; then
                    print_success "System rebuilt with restored configuration"
                else
                    print_error "Failed to rebuild system after restore"
                    return 1
                fi
                ;;
        esac
    else
        print_error "Failed to extract backup"
        return 1
    fi
}

# Function to rollback git commit
rollback_git_commit() {
    local commit_ref="$1"
    
    if [[ -z "$commit_ref" ]]; then
        print_error "Git commit reference not specified"
        return 1
    fi
    
    cd "$CONFIG_ROOT"
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    
    # Verify commit exists
    if ! git rev-parse --verify "$commit_ref" >/dev/null 2>&1; then
        print_error "Invalid git commit reference: $commit_ref"
        return 1
    fi
    
    local commit_hash
    local commit_message
    commit_hash=$(git rev-parse --short "$commit_ref")
    commit_message=$(git log -1 --format='%s' "$commit_ref")
    
    print_step "Rolling back to git commit: $commit_hash ($commit_message)"
    confirm_operation "rollback to git commit" "$commit_hash"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would run: git checkout $commit_ref"
        return 0
    fi
    
    create_emergency_backup
    
    # Checkout the commit
    if git checkout "$commit_ref"; then
        print_success "Successfully checked out commit $commit_hash"
        log_message "INFO" "Git rollback to commit $commit_hash completed"
        
        # Rebuild system with rolled back configuration
        print_step "Rebuilding system with rolled back configuration"
        local platform
        platform=$(detect_platform)
        
        case $platform in
            darwin)
                if timeout "$ROLLBACK_TIMEOUT" darwin-rebuild switch --flake .; then
                    print_success "System rebuilt with rolled back configuration"
                else
                    print_error "Failed to rebuild system after git rollback"
                    return 1
                fi
                ;;
            nixos)
                if timeout "$ROLLBACK_TIMEOUT" sudo nixos-rebuild switch --flake .; then
                    print_success "System rebuilt with rolled back configuration"
                else
                    print_error "Failed to rebuild system after git rollback"
                    return 1
                fi
                ;;
        esac
    else
        print_error "Failed to checkout commit $commit_ref"
        return 1
    fi
}

# Function for emergency rollback
emergency_rollback() {
    print_header "Emergency Rollback"
    print_warning "Initiating emergency rollback to last known good state"
    
    # Try multiple recovery methods in order of preference
    local platform
    platform=$(detect_platform)
    
    # 1. Try previous generation rollback
    print_step "Attempting previous generation rollback"
    if rollback_previous_generation; then
        print_success "Emergency rollback via previous generation successful"
        return 0
    fi
    
    # 2. Try most recent backup
    print_step "Attempting restore from most recent backup"
    local latest_backup
    # shellcheck disable=SC2012 # ls sort by mtime is portable across BSD/GNU
    latest_backup=$(ls -1t "$BACKUP_DIR"/config_backup_*.tar.gz 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        FORCE=true  # Force emergency operations
        if restore_from_backup "$latest_backup"; then
            print_success "Emergency rollback via backup successful"
            return 0
        fi
    fi
    
    # 3. Try git rollback to last known good commit
    print_step "Attempting git rollback to HEAD~1"
    cd "$CONFIG_ROOT"
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        FORCE=true  # Force emergency operations
        if rollback_git_commit "HEAD~1"; then
            print_success "Emergency rollback via git successful"
            return 0
        fi
    fi
    
    print_error "All emergency rollback methods failed"
    print_info "Manual intervention may be required"
    return 1
}

# Function to verify system after rollback
verify_system() {
    if [[ "$NO_VERIFY" == true ]]; then
        print_info "Skipping system verification (--no-verify specified)"
        return 0
    fi
    
    print_step "Verifying system after rollback"
    
    # Basic system checks
    if command -v systemctl >/dev/null 2>&1; then
        local failed_services
        failed_services=$(systemctl --failed --no-legend | wc -l)
        if [[ $failed_services -gt 0 ]]; then
            print_warning "$failed_services failed systemd services detected"
        else
            print_success "All systemd services are running normally"
        fi
    fi
    
    # Check if home-manager is working
    if command -v home-manager >/dev/null 2>&1; then
        if home-manager news >/dev/null 2>&1; then
            print_success "Home Manager is functioning correctly"
        else
            print_warning "Home Manager may have issues"
        fi
    fi
    
    print_success "System verification completed"
    log_message "INFO" "System verification completed after rollback"
}

# Main execution function
main() {
    print_header "Nix Configuration Rollback Script"
    
    mkdir -p "$LOG_DIR"
    log_message "INFO" "Rollback script started with command: $COMMAND"
    
    # Handle interactive mode
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_selection
    fi
    
    case $COMMAND in
        list)
            list_all_targets
            ;;
        previous)
            rollback_previous_generation
            verify_system
            ;;
        generation)
            rollback_to_generation "$TARGET"
            verify_system
            ;;
        backup)
            restore_from_backup "$TARGET"
            verify_system
            ;;
        git)
            rollback_git_commit "$TARGET"
            verify_system
            ;;
        emergency)
            emergency_rollback
            verify_system
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
    
    if [[ "$COMMAND" != "list" ]]; then
        print_header "Rollback Complete"
        if [[ "$DRY_RUN" == true ]]; then
            print_info "This was a dry run. No changes were made."
        else
            print_success "Rollback operation completed successfully!"
            log_message "INFO" "Rollback script completed successfully"
        fi
    fi
}

# Parse arguments and run main function
parse_args "$@"
main
