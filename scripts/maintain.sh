#!/usr/bin/env bash
# System maintenance script for Nix configuration
# This script provides a unified interface for common maintenance tasks

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

print_header() {
    echo ""
    print_color $CYAN "=== $1 ==="
    echo ""
}

# Function to show help
show_help() {
    cat << EOF
Nix Configuration Maintenance Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  status          Show comprehensive system status
  update          Update system configuration
  rollback        Rollback system configuration
  cleanup         Cleanup old generations and garbage collect
  health          Perform system health checks
  backup          Create backup of current configuration
  packages        Manage packages
  secrets         Manage secrets
  logs            View system logs
  help            Show this help message

Options:
  --interactive   Interactive mode with menus
  --dry-run       Show what would be done without executing
  --verbose       Enable verbose output
  --force         Force operations without confirmation

Examples:
  $0 status                   # Show system status
  $0 update                   # Update system
  $0 rollback --interactive   # Interactive rollback
  $0 cleanup                  # Cleanup old data
  $0 health                   # Check system health

This script provides a unified interface to:
- Update and rollback scripts
- Package management
- Secret management
- System health monitoring
- Maintenance operations

EOF
}

# Function to parse arguments
parse_args() {
    COMMAND=""
    INTERACTIVE=false
    DRY_RUN=false
    VERBOSE=false
    FORCE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            status|update|rollback|cleanup|health|backup|packages|secrets|logs)
                COMMAND="$1"
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
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

# Function to show interactive menu
show_interactive_menu() {
    while true; do
        print_header "Nix Configuration Maintenance"
        echo "Select an operation:"
        echo ""
        echo "1) Show system status"
        echo "2) Update system configuration"
        echo "3) Rollback system configuration"
        echo "4) Cleanup old generations"
        echo "5) Perform health checks"
        echo "6) Create backup"
        echo "7) Manage packages"
        echo "8) Manage secrets"
        echo "9) View logs"
        echo "0) Exit"
        echo ""
        
        read -p "Enter choice (0-9): " choice
        
        case $choice in
            1) COMMAND="status"; break ;;
            2) COMMAND="update"; break ;;
            3) COMMAND="rollback"; break ;;
            4) COMMAND="cleanup"; break ;;
            5) COMMAND="health"; break ;;
            6) COMMAND="backup"; break ;;
            7) COMMAND="packages"; break ;;
            8) COMMAND="secrets"; break ;;
            9) COMMAND="logs"; break ;;
            0) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid choice. Please try again."; sleep 1 ;;
        esac
    done
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

# Function to show comprehensive status
show_status() {
    print_header "System Status"
    
    # Run the update script's status command
    if [[ -x "$SCRIPT_DIR/update.sh" ]]; then
        "$SCRIPT_DIR/update.sh" status
    else
        print_error "Update script not found or not executable"
    fi
    
    # Additional status information
    echo ""
    print_info "Disk usage:"
    df -h / 2>/dev/null || df -h
    
    echo ""
    print_info "Memory usage:"
    if command -v free >/dev/null 2>&1; then
        free -h
    elif [[ "$(detect_platform)" == "darwin" ]]; then
        vm_stat | head -5
    fi
    
    echo ""
    print_info "Load average:"
    uptime
}

# Function to run update
run_update() {
    print_header "System Update"
    
    local args=()
    [[ "$DRY_RUN" == true ]] && args+=(--dry-run)
    [[ "$FORCE" == true ]] && args+=(--force)
    [[ "$VERBOSE" == true ]] && args+=(--verbose)
    
    if [[ -x "$SCRIPT_DIR/update.sh" ]]; then
        "$SCRIPT_DIR/update.sh" "${args[@]}" update
    else
        print_error "Update script not found or not executable"
        return 1
    fi
}

# Function to run rollback
run_rollback() {
    print_header "System Rollback"
    
    local args=()
    [[ "$DRY_RUN" == true ]] && args+=(--dry-run)
    [[ "$FORCE" == true ]] && args+=(--force)
    [[ "$INTERACTIVE" == true ]] && args+=(--interactive)
    
    if [[ -x "$SCRIPT_DIR/rollback.sh" ]]; then
        "$SCRIPT_DIR/rollback.sh" "${args[@]}"
    else
        print_error "Rollback script not found or not executable"
        return 1
    fi
}

# Function to run cleanup
run_cleanup() {
    print_header "System Cleanup"
    
    local platform=$(detect_platform)
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would perform cleanup operations (dry run)"
        return 0
    fi
    
    # Clean up Nix store
    print_info "Cleaning up Nix store..."
    if [[ "$FORCE" == true ]] || read -p "Clean up Nix store (remove unreferenced packages)? (y/N): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        nix-collect-garbage --delete-older-than 30d || true
        print_success "Nix store cleanup completed"
    fi
    
    # Clean up old generations
    print_info "Cleaning up old generations..."
    if [[ "$FORCE" == true ]] || read -p "Clean up old system generations? (y/N): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        case $platform in
            darwin)
                sudo nix-collect-garbage --delete-older-than 30d || true
                ;;
            nixos)
                sudo nix-collect-garbage --delete-older-than 30d || true
                sudo /run/current-system/bin/switch-to-configuration boot || true
                ;;
        esac
        print_success "Generation cleanup completed"
    fi
    
    # Clean up Home Manager generations
    if command -v home-manager >/dev/null 2>&1; then
        print_info "Cleaning up Home Manager generations..."
        if [[ "$FORCE" == true ]] || read -p "Clean up old Home Manager generations? (y/N): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
            echo
            home-manager expire-generations "-30 days" || true
            print_success "Home Manager cleanup completed"
        fi
    fi
    
    # Clean up old backups
    if [[ -d "$CONFIG_ROOT/backups" ]]; then
        print_info "Cleaning up old backups..."
        if [[ "$FORCE" == true ]] || read -p "Clean up backups older than 90 days? (y/N): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
            echo
            find "$CONFIG_ROOT/backups" -name "*.tar.gz" -mtime +90 -delete 2>/dev/null || true
            print_success "Backup cleanup completed"
        fi
    fi
    
    # Clean up logs
    if [[ -d "$CONFIG_ROOT/logs" ]]; then
        print_info "Cleaning up old logs..."
        if [[ "$FORCE" == true ]] || read -p "Clean up logs older than 30 days? (y/N): " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
            echo
            find "$CONFIG_ROOT/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true
            print_success "Log cleanup completed"
        fi
    fi
}

# Function to perform health checks
run_health_checks() {
    print_header "System Health Checks"
    
    local issues=0
    
    # Check Nix installation
    print_info "Checking Nix installation..."
    if command -v nix >/dev/null 2>&1; then
        print_success "Nix is installed and accessible"
    else
        print_error "Nix is not installed or not in PATH"
        ((issues++))
    fi
    
    # Check platform-specific tools
    local platform=$(detect_platform)
    case $platform in
        darwin)
            if command -v darwin-rebuild >/dev/null 2>&1; then
                print_success "nix-darwin is installed"
            else
                print_error "nix-darwin is not installed"
                ((issues++))
            fi
            ;;
        nixos)
            if command -v nixos-rebuild >/dev/null 2>&1; then
                print_success "nixos-rebuild is available"
            else
                print_error "nixos-rebuild is not available"
                ((issues++))
            fi
            ;;
    esac
    
    # Check Home Manager
    if command -v home-manager >/dev/null 2>&1; then
        print_success "Home Manager is installed"
        
        # Test Home Manager functionality
        if home-manager news >/dev/null 2>&1; then
            print_success "Home Manager is functioning correctly"
        else
            print_warning "Home Manager may have configuration issues"
            ((issues++))
        fi
    else
        print_warning "Home Manager is not installed"
    fi
    
    # Check flake configuration
    cd "$CONFIG_ROOT"
    if [[ -f "flake.nix" ]]; then
        print_success "flake.nix found"
        
        # Test flake evaluation
        if nix flake check --no-build 2>/dev/null; then
            print_success "Flake configuration is valid"
        else
            print_error "Flake configuration has errors"
            ((issues++))
        fi
    else
        print_error "flake.nix not found"
        ((issues++))
    fi
    
    # Check git repository status
    if git rev-parse --git-dir >/dev/null 2>&1; then
        print_success "Git repository is valid"
        
        # Check for uncommitted changes
        if git diff --quiet && git diff --cached --quiet; then
            print_success "Working tree is clean"
        else
            print_warning "Uncommitted changes detected"
        fi
        
        # Check remote connectivity
        if git fetch --dry-run 2>/dev/null; then
            print_success "Git remote is accessible"
        else
            print_warning "Cannot connect to git remote"
        fi
    else
        print_error "Not in a git repository"
        ((issues++))
    fi
    
    # Check disk space
    local available_space=$(df "$CONFIG_ROOT" | tail -1 | awk '{print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [[ $available_space -gt $required_space ]]; then
        print_success "Sufficient disk space available"
    else
        print_warning "Low disk space (less than 2GB available)"
        ((issues++))
    fi
    
    # Check systemd services (if applicable)
    if command -v systemctl >/dev/null 2>&1; then
        local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
        if [[ $failed_services -eq 0 ]]; then
            print_success "All systemd services are running"
        else
            print_warning "$failed_services failed systemd services detected"
            ((issues++))
        fi
    fi
    
    # Summary
    echo ""
    if [[ $issues -eq 0 ]]; then
        print_success "All health checks passed! System is healthy."
    else
        print_warning "$issues issue(s) detected. Review the output above."
    fi
}

# Function to create backup
create_backup() {
    print_header "Create Backup"
    
    if [[ -x "$SCRIPT_DIR/update.sh" ]]; then
        # Use the update script's backup functionality
        "$SCRIPT_DIR/update.sh" --no-check inputs  # This creates a backup
        print_success "Backup created successfully"
    else
        print_error "Update script not found or not executable"
        return 1
    fi
}

# Function to manage packages
manage_packages() {
    print_header "Package Management"
    
    if [[ -x "$SCRIPT_DIR/manage-packages.sh" ]]; then
        if [[ "$INTERACTIVE" == true ]]; then
            "$SCRIPT_DIR/manage-packages.sh" show-config
            echo ""
            echo "Package management options:"
            echo "1) List categories"
            echo "2) Search packages"
            echo "3) Show current config"
            echo "4) Enable category"
            echo "5) Add package"
            echo ""
            read -p "Enter choice (1-5): " choice
            
            case $choice in
                1) "$SCRIPT_DIR/manage-packages.sh" list-categories ;;
                2) 
                    read -p "Enter search term: " term
                    "$SCRIPT_DIR/manage-packages.sh" search "$term"
                    ;;
                3) "$SCRIPT_DIR/manage-packages.sh" show-config ;;
                4)
                    read -p "Enter category name: " category
                    "$SCRIPT_DIR/manage-packages.sh" enable-category "$category"
                    ;;
                5)
                    read -p "Enter package name: " package
                    "$SCRIPT_DIR/manage-packages.sh" add-package "$package"
                    ;;
                *) print_error "Invalid choice" ;;
            esac
        else
            "$SCRIPT_DIR/manage-packages.sh" show-config
        fi
    else
        print_error "Package management script not found"
        return 1
    fi
}

# Function to manage secrets
manage_secrets() {
    print_header "Secret Management"
    
    if command -v secret-status >/dev/null 2>&1; then
        if [[ "$INTERACTIVE" == true ]]; then
            echo "Secret management options:"
            echo "1) Check status"
            echo "2) Initialize secrets"
            echo "3) Edit secrets"
            echo "4) Load secrets"
            echo ""
            read -p "Enter choice (1-4): " choice
            
            case $choice in
                1) secret-status ;;
                2) init-secrets ;;
                3) edit-secrets ;;
                4)
                    read -p "Enter command to run with secrets: " cmd
                    secrets $cmd
                    ;;
                *) print_error "Invalid choice" ;;
            esac
        else
            secret-status
        fi
    else
        print_error "Secret management not available (run home-manager switch)"
        return 1
    fi
}

# Function to view logs
view_logs() {
    print_header "System Logs"
    
    local log_dir="$CONFIG_ROOT/logs"
    
    if [[ -d "$log_dir" ]]; then
        echo "Available log files:"
        ls -la "$log_dir"/*.log 2>/dev/null || echo "No log files found"
        
        if [[ "$INTERACTIVE" == true ]]; then
            echo ""
            read -p "Enter log file name to view (or press Enter to skip): " logfile
            if [[ -n "$logfile" && -f "$log_dir/$logfile" ]]; then
                less "$log_dir/$logfile"
            fi
        fi
    else
        print_warning "No log directory found at $log_dir"
    fi
    
    # Show recent systemd logs if available
    if command -v journalctl >/dev/null 2>&1; then
        echo ""
        print_info "Recent system logs (last 50 lines):"
        journalctl --no-pager -n 50 2>/dev/null || true
    fi
}

# Main execution function
main() {
    # Show interactive menu if no command specified
    if [[ -z "$COMMAND" ]]; then
        if [[ "$INTERACTIVE" == true ]] || [[ $# -eq 0 ]]; then
            show_interactive_menu
        else
            show_help
            exit 1
        fi
    fi
    
    case $COMMAND in
        status)
            show_status
            ;;
        update)
            run_update
            ;;
        rollback)
            run_rollback
            ;;
        cleanup)
            run_cleanup
            ;;
        health)
            run_health_checks
            ;;
        backup)
            create_backup
            ;;
        packages)
            manage_packages
            ;;
        secrets)
            manage_secrets
            ;;
        logs)
            view_logs
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Parse arguments and run main function
parse_args "$@"
main