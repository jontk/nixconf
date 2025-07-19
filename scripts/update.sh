#!/usr/bin/env bash
# Automated update script for Nix configuration
# This script handles flake updates, system rebuilds, and safety checks

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
MAX_BACKUPS=10
UPDATE_TIMEOUT=1800  # 30 minutes
CHECK_TIMEOUT=300    # 5 minutes

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_color $GREEN "✓ $1"
}

print_error() {
    print_color $RED "✗ $1"
}

print_warning() {
    print_color $YELLOW "⚠ $1"
}

print_info() {
    print_color $BLUE "ℹ $1"
}

print_step() {
    print_color $PURPLE "▶ $1"
}

print_header() {
    echo ""
    print_color $CYAN "=== $1 ==="
    echo ""
}

# Function to log messages with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/update.log"
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
Nix Configuration Update Script

Usage: $0 [OPTIONS] [COMMAND]

Commands:
  update          Perform full system update (default)
  check           Check for updates without applying
  quick           Quick update without full rebuild
  inputs          Update only flake inputs
  rebuild         Rebuild without updating inputs
  status          Show system status and available updates
  help            Show this help message

Options:
  --dry-run       Show what would be done without executing
  --no-backup     Skip creating backup before update
  --no-check      Skip pre-update checks
  --force         Force update even if checks fail
  --verbose       Enable verbose output
  --timeout=N     Set timeout for operations (seconds)
  --inputs=LIST   Update only specific inputs (comma-separated)

Examples:
  $0                          # Full update with all safety checks
  $0 check                    # Check for updates
  $0 --dry-run update         # Preview what would be updated
  $0 --inputs=nixpkgs,home-manager  # Update specific inputs only
  $0 quick                    # Quick update for minor changes

The script will:
1. Create a backup of current configuration
2. Check system health and prerequisites
3. Update flake inputs or use existing
4. Rebuild the system configuration
5. Verify the new configuration works
6. Clean up old generations (optional)

EOF
}

# Function to parse command line arguments
parse_args() {
    COMMAND="update"
    DRY_RUN=false
    NO_BACKUP=false
    NO_CHECK=false
    FORCE=false
    VERBOSE=false
    SPECIFIC_INPUTS=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            update|check|quick|inputs|rebuild|status)
                COMMAND="$1"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --no-check)
                NO_CHECK=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --timeout=*)
                UPDATE_TIMEOUT="${1#*=}"
                shift
                ;;
            --inputs=*)
                SPECIFIC_INPUTS="${1#*=}"
                shift
                ;;
            --help|-h|help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Function to setup directories
setup_directories() {
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    
    # Clean old log files (keep last 30 days)
    find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
}

# Function to create backup
create_backup() {
    if [[ "$NO_BACKUP" == true ]]; then
        print_info "Skipping backup (--no-backup specified)"
        return 0
    fi
    
    print_step "Creating backup of current configuration"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/config_backup_${timestamp}.tar.gz"
    
    # Create backup of important files
    tar -czf "$backup_file" \
        --exclude='.git' \
        --exclude='logs' \
        --exclude='backups' \
        --exclude='result*' \
        -C "$CONFIG_ROOT" . \
        2>/dev/null || {
        print_error "Failed to create backup"
        return 1
    }
    
    print_success "Backup created: $backup_file"
    log_message "INFO" "Backup created: $backup_file"
    
    # Clean old backups
    cleanup_old_backups
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_count=$(ls -1 "$BACKUP_DIR"/config_backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        print_info "Cleaning up old backups (keeping $MAX_BACKUPS most recent)"
        ls -1t "$BACKUP_DIR"/config_backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
    fi
}

# Function to check prerequisites
check_prerequisites() {
    if [[ "$NO_CHECK" == true ]]; then
        print_info "Skipping prerequisite checks (--no-check specified)"
        return 0
    fi
    
    print_step "Checking prerequisites and system health"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        if [[ "$FORCE" != true ]]; then
            print_error "Uncommitted changes detected. Commit or stash changes first."
            print_info "Use --force to override this check"
            return 1
        else
            print_warning "Proceeding with uncommitted changes (--force specified)"
        fi
    fi
    
    # Check disk space (need at least 2GB for Nix operations)
    local available_space=$(df "$CONFIG_ROOT" | tail -1 | awk '{print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        print_error "Insufficient disk space. Need at least 2GB free."
        return 1
    fi
    
    # Check if flake.nix exists
    if [[ ! -f "$CONFIG_ROOT/flake.nix" ]]; then
        print_error "flake.nix not found in $CONFIG_ROOT"
        return 1
    fi
    
    # Platform-specific checks
    local platform=$(detect_platform)
    case $platform in
        darwin)
            if ! command -v darwin-rebuild >/dev/null 2>&1; then
                print_error "darwin-rebuild not found. Install nix-darwin first."
                return 1
            fi
            ;;
        nixos)
            if ! command -v nixos-rebuild >/dev/null 2>&1; then
                print_error "nixos-rebuild not found. This doesn't appear to be NixOS."
                return 1
            fi
            ;;
        *)
            print_error "Unsupported platform: $platform"
            return 1
            ;;
    esac
    
    print_success "All prerequisite checks passed"
    log_message "INFO" "Prerequisite checks completed successfully"
}

# Function to check for updates
check_for_updates() {
    print_step "Checking for available updates"
    
    cd "$CONFIG_ROOT"
    
    # Fetch latest changes from remote
    git fetch origin >/dev/null 2>&1 || {
        print_warning "Failed to fetch from remote repository"
    }
    
    # Check if there are updates
    local behind_count=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
    
    if [[ $behind_count -gt 0 ]]; then
        print_info "Configuration is $behind_count commits behind remote"
    else
        print_info "Configuration is up to date with remote"
    fi
    
    # Check flake inputs for updates
    if command -v nix >/dev/null 2>&1; then
        print_info "Checking flake inputs for updates..."
        
        # This will show outdated inputs
        timeout "$CHECK_TIMEOUT" nix flake metadata --refresh 2>/dev/null || {
            print_warning "Failed to check flake metadata"
        }
    fi
}

# Function to update flake inputs
update_inputs() {
    print_step "Updating flake inputs"
    
    cd "$CONFIG_ROOT"
    
    local update_cmd="nix flake update"
    
    # Update specific inputs if specified
    if [[ -n "$SPECIFIC_INPUTS" ]]; then
        print_info "Updating specific inputs: $SPECIFIC_INPUTS"
        IFS=',' read -ra INPUTS <<< "$SPECIFIC_INPUTS"
        for input in "${INPUTS[@]}"; do
            update_cmd="nix flake lock --update-input $input"
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would run: $update_cmd"
            else
                print_info "Updating input: $input"
                timeout "$UPDATE_TIMEOUT" $update_cmd || {
                    print_error "Failed to update input: $input"
                    return 1
                }
            fi
        done
    else
        print_info "Updating all flake inputs"
        if [[ "$DRY_RUN" == true ]]; then
            print_info "Would run: $update_cmd"
        else
            timeout "$UPDATE_TIMEOUT" $update_cmd || {
                print_error "Failed to update flake inputs"
                return 1
            }
        fi
    fi
    
    if [[ "$DRY_RUN" != true ]]; then
        # Show what changed
        if git diff --quiet flake.lock; then
            print_info "No input updates available"
        else
            print_success "Flake inputs updated"
            git add flake.lock
            git commit -m "chore: update flake inputs

$(git diff HEAD~1 --stat flake.lock)"
            log_message "INFO" "Flake inputs updated and committed"
        fi
    fi
}

# Function to rebuild system
rebuild_system() {
    print_step "Rebuilding system configuration"
    
    cd "$CONFIG_ROOT"
    local platform=$(detect_platform)
    local rebuild_cmd=""
    
    case $platform in
        darwin)
            rebuild_cmd="darwin-rebuild switch --flake ."
            ;;
        nixos)
            rebuild_cmd="sudo nixos-rebuild switch --flake ."
            ;;
        *)
            print_error "Unsupported platform for rebuild: $platform"
            return 1
            ;;
    esac
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would run: $rebuild_cmd"
        return 0
    fi
    
    print_info "Running: $rebuild_cmd"
    log_message "INFO" "Starting system rebuild: $rebuild_cmd"
    
    # Run rebuild with timeout
    if timeout "$UPDATE_TIMEOUT" $rebuild_cmd; then
        print_success "System rebuild completed successfully"
        log_message "INFO" "System rebuild completed successfully"
    else
        print_error "System rebuild failed or timed out"
        log_message "ERROR" "System rebuild failed"
        return 1
    fi
}

# Function to verify system health after update
verify_system() {
    print_step "Verifying system health after update"
    
    # Basic system checks
    if command -v systemctl >/dev/null 2>&1; then
        # Check for failed services (NixOS)
        local failed_services=$(systemctl --failed --no-legend | wc -l)
        if [[ $failed_services -gt 0 ]]; then
            print_warning "$failed_services failed systemd services detected"
            systemctl --failed --no-legend
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
    
    # Platform-specific verification
    local platform=$(detect_platform)
    case $platform in
        darwin)
            # Check if essential macOS services are running
            if launchctl list | grep -q "com.apple."; then
                print_success "macOS system services are running"
            fi
            ;;
        nixos)
            # Check if X11/Wayland is running (if applicable)
            if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
                print_success "Display server is running"
            fi
            ;;
    esac
    
    log_message "INFO" "System verification completed"
}

# Function to cleanup old generations
cleanup_generations() {
    print_step "Cleaning up old system generations"
    
    local platform=$(detect_platform)
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would clean up old generations"
        return 0
    fi
    
    case $platform in
        darwin)
            # Clean up darwin generations (keep last 5)
            if command -v darwin-rebuild >/dev/null 2>&1; then
                sudo nix-collect-garbage --delete-older-than 30d || true
                print_success "Cleaned up old Darwin generations"
            fi
            ;;
        nixos)
            # Clean up NixOS generations (keep last 5)
            if command -v nixos-rebuild >/dev/null 2>&1; then
                sudo nix-collect-garbage --delete-older-than 30d || true
                # Also clean boot entries
                sudo /run/current-system/bin/switch-to-configuration boot || true
                print_success "Cleaned up old NixOS generations"
            fi
            ;;
    esac
    
    # Clean up user profile generations
    nix-collect-garbage --delete-older-than 30d || true
    
    log_message "INFO" "Generation cleanup completed"
}

# Function to show system status
show_status() {
    print_header "System Status"
    
    local platform=$(detect_platform)
    print_info "Platform: $platform"
    
    # Git status
    cd "$CONFIG_ROOT"
    print_info "Git branch: $(git branch --show-current)"
    print_info "Last commit: $(git log -1 --format='%h %s (%cr)')"
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_warning "Uncommitted changes present"
    else
        print_success "Working tree is clean"
    fi
    
    # Show current generations
    case $platform in
        darwin)
            if command -v darwin-rebuild >/dev/null 2>&1; then
                print_info "Current Darwin generation:"
                darwin-rebuild --list-generations | tail -1 || true
            fi
            ;;
        nixos)
            if command -v nixos-rebuild >/dev/null 2>&1; then
                print_info "Current NixOS generation:"
                sudo nixos-rebuild list-generations | tail -1 || true
            fi
            ;;
    esac
    
    # Show home-manager generation
    if command -v home-manager >/dev/null 2>&1; then
        print_info "Current Home Manager generation:"
        home-manager generations | head -1 || true
    fi
    
    # Show disk usage
    print_info "Nix store size: $(du -sh /nix/store 2>/dev/null || echo 'Unknown')"
    
    # Show recent update log
    if [[ -f "$LOG_DIR/update.log" ]]; then
        print_info "Last update: $(tail -1 "$LOG_DIR/update.log" | cut -d' ' -f1-2)"
    fi
}

# Main execution function
main() {
    print_header "Nix Configuration Update Script"
    
    # Setup
    setup_directories
    log_message "INFO" "Update script started with command: $COMMAND"
    
    case $COMMAND in
        check)
            check_for_updates
            ;;
        status)
            show_status
            ;;
        inputs)
            check_prerequisites
            create_backup
            update_inputs
            ;;
        rebuild)
            check_prerequisites
            create_backup
            rebuild_system
            verify_system
            ;;
        quick)
            print_info "Performing quick update (minimal checks)"
            NO_CHECK=true
            NO_BACKUP=true
            check_prerequisites
            rebuild_system
            ;;
        update)
            check_prerequisites
            create_backup
            check_for_updates
            update_inputs
            rebuild_system
            verify_system
            cleanup_generations
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
    
    if [[ "$COMMAND" != "check" && "$COMMAND" != "status" ]]; then
        print_header "Update Complete"
        print_success "All operations completed successfully!"
        log_message "INFO" "Update script completed successfully"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_info "This was a dry run. No changes were made."
        fi
    fi
}

# Parse arguments and run main function
parse_args "$@"
main