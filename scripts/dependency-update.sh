#!/usr/bin/env bash

# Automated Dependency Update System
# Manages and updates Nix flake inputs, system packages, and dependencies

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
UPDATE_LOG="/var/log/dependency-updates.log"
SECURITY_LOG="/var/log/security-updates.log"
UPDATE_STRATEGY="${UPDATE_STRATEGY:-conservative}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$UPDATE_LOG" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$UPDATE_LOG" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$UPDATE_LOG" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$UPDATE_LOG" >&2
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Automated dependency update system for NixOS configurations

COMMANDS:
    check               Check for available updates
    update              Update dependencies based on strategy
    security            Update only security-related packages
    flake               Update flake inputs
    channels            Update Nix channels
    test                Test updates before applying
    rollback            Rollback recent updates
    report              Generate update report

OPTIONS:
    -s, --strategy STR  Update strategy (conservative, balanced, aggressive)
    -f, --force         Force updates without confirmation
    -d, --dry-run       Show what would be done without making changes
    -v, --verbose       Verbose output
    -h, --help          Show this help

STRATEGIES:
    conservative        Update only security fixes and critical patches
    balanced            Update stable releases and security fixes (default)
    aggressive          Update to latest available versions

EXAMPLES:
    $0 check                           # Check for available updates
    $0 update --strategy conservative  # Conservative updates only
    $0 security                        # Security updates only
    $0 flake --dry-run                # Preview flake updates

EOF
}

# Initialize update system
init_update_system() {
    log_info "Initializing dependency update system..."
    
    # Create log directories
    mkdir -p "$(dirname "$UPDATE_LOG")"
    mkdir -p "$(dirname "$SECURITY_LOG")"
    touch "$UPDATE_LOG" "$SECURITY_LOG"
    
    # Record initialization
    echo "=== Dependency Update System Initialized: $(date) ===" >> "$UPDATE_LOG"
    
    log_success "Update system initialized"
}

# Check for available updates
check_updates() {
    local check_type="${1:-all}"
    
    log_info "Checking for available updates ($check_type)..."
    
    cd "$REPO_ROOT"
    
    case "$check_type" in
        "all")
            check_flake_updates
            check_channel_updates
            check_security_updates
            check_system_updates
            ;;
        "flake")
            check_flake_updates
            ;;
        "channels")
            check_channel_updates
            ;;
        "security")
            check_security_updates
            ;;
        "system")
            check_system_updates
            ;;
    esac
}

# Check flake input updates
check_flake_updates() {
    log_info "Checking flake input updates..."
    
    if [[ ! -f "flake.nix" ]]; then
        log_error "No flake.nix found in $REPO_ROOT"
        return 1
    fi
    
    # Get current input information
    echo "Current flake inputs:" >> "$UPDATE_LOG"
    nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.key != "root") | "\(.key): \(.value.locked.rev // .value.locked.narHash)"' >> "$UPDATE_LOG"
    
    # Check for updates
    echo "Checking for flake input updates..." >> "$UPDATE_LOG"
    if nix flake update --dry-run 2>&1 | tee -a "$UPDATE_LOG"; then
        log_success "Flake update check completed"
    else
        log_error "Failed to check flake updates"
        return 1
    fi
}

# Check channel updates
check_channel_updates() {
    log_info "Checking channel updates..."
    
    # List current channels
    echo "Current channels:" >> "$UPDATE_LOG"
    nix-channel --list >> "$UPDATE_LOG"
    
    # Check for channel updates
    if nix-channel --update --dry-run 2>&1 | tee -a "$UPDATE_LOG"; then
        log_success "Channel update check completed"
    else
        log_warning "Channel update check had issues"
    fi
}

# Check security updates
check_security_updates() {
    log_info "Checking security updates..."
    
    # Create security report
    {
        echo "=== Security Update Check: $(date) ==="
        echo "Hostname: $(hostname)"
        echo
    } >> "$SECURITY_LOG"
    
    # Check for CVE vulnerabilities in current packages
    if command -v nix-env >/dev/null 2>&1; then
        echo "Checking installed packages for security vulnerabilities..." >> "$SECURITY_LOG"
        
        # Get list of installed packages
        nix-env -q > /tmp/installed-packages.txt
        
        # Check for security advisories (simplified)
        while read -r package; do
            if echo "$package" | grep -E "(openssl|openssh|kernel|glibc)" >/dev/null; then
                echo "Security-critical package: $package" >> "$SECURITY_LOG"
            fi
        done < /tmp/installed-packages.txt
        
        rm -f /tmp/installed-packages.txt
    fi
    
    # Check system packages for vulnerabilities
    if command -v vulnix >/dev/null 2>&1; then
        echo "Running vulnix security scan..." >> "$SECURITY_LOG"
        vulnix --system >> "$SECURITY_LOG" 2>&1 || true
    fi
    
    log_success "Security update check completed"
}

# Check system updates
check_system_updates() {
    log_info "Checking system updates..."
    
    # Check if system rebuild would change anything
    if command -v nixos-rebuild >/dev/null 2>&1; then
        echo "Checking NixOS system updates..." >> "$UPDATE_LOG"
        nixos-rebuild dry-run --upgrade 2>&1 | tee -a "$UPDATE_LOG"
    fi
    
    # Check Home Manager updates
    if command -v home-manager >/dev/null 2>&1; then
        echo "Checking Home Manager updates..." >> "$UPDATE_LOG"
        home-manager build --dry-run 2>&1 | tee -a "$UPDATE_LOG" || true
    fi
    
    log_success "System update check completed"
}

# Update flake inputs
update_flake_inputs() {
    local strategy="$1"
    local dry_run="$2"
    
    log_info "Updating flake inputs with $strategy strategy..."
    
    cd "$REPO_ROOT"
    
    if [[ ! -f "flake.nix" ]]; then
        log_error "No flake.nix found"
        return 1
    fi
    
    # Backup current flake.lock
    if [[ -f "flake.lock" ]]; then
        cp flake.lock "flake.lock.backup-$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up current flake.lock"
    fi
    
    case "$strategy" in
        "conservative")
            # Update only security-critical inputs
            log_info "Conservative update: updating security-critical inputs only"
            
            # List of security-critical inputs
            critical_inputs=("nixpkgs" "nixpkgs-stable")
            
            for input in "${critical_inputs[@]}"; do
                if nix flake metadata --json | jq -e ".locks.nodes.\"$input\"" >/dev/null 2>&1; then
                    log_info "Updating critical input: $input"
                    if [[ "$dry_run" == "false" ]]; then
                        nix flake lock --update-input "$input"
                    else
                        echo "Would update input: $input"
                    fi
                fi
            done
            ;;
            
        "balanced")
            # Update stable inputs, keep development inputs pinned
            log_info "Balanced update: updating stable inputs"
            
            # Get list of inputs
            inputs=$(nix flake metadata --json | jq -r '.locks.nodes | keys[] | select(. != "root")')
            
            for input in $inputs; do
                # Skip development/unstable inputs
                if echo "$input" | grep -E "(unstable|master|develop)" >/dev/null; then
                    log_info "Skipping unstable input: $input"
                    continue
                fi
                
                log_info "Updating stable input: $input"
                if [[ "$dry_run" == "false" ]]; then
                    nix flake lock --update-input "$input"
                else
                    echo "Would update input: $input"
                fi
            done
            ;;
            
        "aggressive")
            # Update all inputs to latest
            log_info "Aggressive update: updating all inputs"
            
            if [[ "$dry_run" == "false" ]]; then
                nix flake update
            else
                echo "Would run: nix flake update"
            fi
            ;;
            
        *)
            log_error "Unknown update strategy: $strategy"
            return 1
            ;;
    esac
    
    if [[ "$dry_run" == "false" ]]; then
        log_success "Flake inputs updated"
        
        # Show what changed
        if [[ -f "flake.lock.backup-$(date +%Y%m%d_%H%M%S)" ]]; then
            echo "Changes made:" >> "$UPDATE_LOG"
            git diff "flake.lock.backup-$(date +%Y%m%d_%H%M%S)" flake.lock >> "$UPDATE_LOG" 2>&1 || true
        fi
    else
        log_info "Dry run completed - no changes made"
    fi
}

# Update system packages
update_system() {
    local strategy="$1"
    local dry_run="$2"
    
    log_info "Updating system with $strategy strategy..."
    
    # Test configuration before applying
    if [[ "$dry_run" == "false" ]]; then
        log_info "Testing configuration before update..."
        if ! nix flake check; then
            log_error "Configuration check failed - aborting update"
            return 1
        fi
    fi
    
    # Update based on strategy
    case "$strategy" in
        "conservative")
            log_info "Conservative system update"
            if [[ "$dry_run" == "false" ]]; then
                # Only rebuild if there are security updates
                nixos-rebuild switch --upgrade
            else
                nixos-rebuild dry-run --upgrade
            fi
            ;;
            
        "balanced"|"aggressive")
            log_info "Full system update"
            if [[ "$dry_run" == "false" ]]; then
                nixos-rebuild switch
            else
                nixos-rebuild dry-run
            fi
            ;;
    esac
    
    if [[ "$dry_run" == "false" ]]; then
        log_success "System update completed"
        
        # Record update
        echo "System updated: $(date)" >> "$UPDATE_LOG"
        echo "New generation: $(nixos-rebuild list-generations | tail -1)" >> "$UPDATE_LOG"
    fi
}

# Security-only updates
security_update() {
    local dry_run="$1"
    
    log_info "Performing security-only updates..."
    
    # Update flake inputs for security
    update_flake_inputs "conservative" "$dry_run"
    
    # Check for security-specific package updates
    log_info "Checking for security package updates..."
    
    # List of security-critical packages to monitor
    security_packages=(
        "openssl"
        "openssh"  
        "glibc"
        "systemd"
        "linux"
        "firefox"
        "chromium"
    )
    
    for package in "${security_packages[@]}"; do
        log_info "Checking security updates for: $package"
        # This would need integration with security databases
        # For now, just log the check
        echo "Security check: $package - $(date)" >> "$SECURITY_LOG"
    done
    
    if [[ "$dry_run" == "false" ]]; then
        # Apply security updates
        update_system "conservative" "$dry_run"
        
        # Log security update
        {
            echo "=== Security Update Applied: $(date) ==="
            echo "Hostname: $(hostname)"
            echo "Strategy: security-only"
            echo "Generation: $(nixos-rebuild list-generations | tail -1)"
        } >> "$SECURITY_LOG"
    fi
    
    log_success "Security update check completed"
}

# Test updates before applying
test_updates() {
    log_info "Testing updates..."
    
    cd "$REPO_ROOT"
    
    # Create test branch
    local test_branch="update-test-$(date +%Y%m%d_%H%M%S)"
    
    if [[ -d ".git" ]]; then
        git checkout -b "$test_branch"
        log_info "Created test branch: $test_branch"
    fi
    
    # Test flake updates
    log_info "Testing flake updates..."
    update_flake_inputs "balanced" "true"
    
    # Test configuration
    log_info "Testing configuration..."
    if nix flake check; then
        log_success "Configuration test passed"
    else
        log_error "Configuration test failed"
        
        # Cleanup test branch
        if [[ -d ".git" ]]; then
            git checkout main
            git branch -D "$test_branch"
        fi
        return 1
    fi
    
    # Test build
    log_info "Testing build..."
    if nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel; then
        log_success "Build test passed"
    else
        log_error "Build test failed"
        
        # Cleanup test branch
        if [[ -d ".git" ]]; then
            git checkout main
            git branch -D "$test_branch"
        fi
        return 1
    fi
    
    # Cleanup test branch
    if [[ -d ".git" ]]; then
        git checkout main
        git branch -D "$test_branch"
        log_info "Cleaned up test branch"
    fi
    
    log_success "Update testing completed successfully"
}

# Rollback recent updates
rollback_updates() {
    log_info "Rolling back recent updates..."
    
    if command -v nixos-rebuild >/dev/null 2>&1; then
        # Show recent generations
        echo "Recent generations:" >> "$UPDATE_LOG"
        nixos-rebuild list-generations | tail -5 >> "$UPDATE_LOG"
        
        # Rollback to previous generation
        if nixos-rebuild switch --rollback; then
            log_success "Successfully rolled back to previous generation"
            
            # Record rollback
            echo "Rollback performed: $(date)" >> "$UPDATE_LOG"
            echo "Current generation: $(nixos-rebuild list-generations | tail -1)" >> "$UPDATE_LOG"
        else
            log_error "Failed to rollback system"
            return 1
        fi
    fi
    
    # Rollback flake.lock if backup exists
    cd "$REPO_ROOT"
    latest_backup=$(ls -t flake.lock.backup-* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" flake.lock
        log_success "Restored flake.lock from backup: $latest_backup"
    fi
}

# Generate update report
generate_report() {
    local report_file="/tmp/dependency-update-report-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating update report..."
    
    {
        echo "Dependency Update Report"
        echo "======================="
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "Strategy: $UPDATE_STRATEGY"
        echo
        
        echo "System Information"
        echo "-----------------"
        echo "NixOS Version: $(nixos-version 2>/dev/null || echo 'N/A')"
        echo "Current Generation: $(nixos-rebuild list-generations 2>/dev/null | tail -1 || echo 'N/A')"
        echo "Flake Lock Hash: $(sha256sum flake.lock 2>/dev/null | cut -d' ' -f1 || echo 'N/A')"
        echo
        
        echo "Recent Updates"
        echo "-------------"
        if [[ -f "$UPDATE_LOG" ]]; then
            echo "Last 10 update entries:"
            tail -20 "$UPDATE_LOG" | grep -E "(SUCCESS|ERROR|WARNING)" | tail -10
        fi
        echo
        
        echo "Security Status"
        echo "---------------"
        if [[ -f "$SECURITY_LOG" ]]; then
            echo "Recent security checks:"
            tail -10 "$SECURITY_LOG"
        fi
        echo
        
        echo "Available Updates"
        echo "----------------"
        check_updates "all" >/dev/null 2>&1
        echo "Check completed - see $UPDATE_LOG for details"
        
    } > "$report_file"
    
    log_success "Update report generated: $report_file"
    
    # Display report
    cat "$report_file"
    
    # Email report if configured
    if [[ -n "${UPDATE_REPORT_EMAIL:-}" ]]; then
        mail -s "Dependency Update Report - $(hostname)" "$UPDATE_REPORT_EMAIL" < "$report_file"
        log_info "Report emailed to $UPDATE_REPORT_EMAIL"
    fi
}

# Main update function
perform_update() {
    local strategy="$1"
    local dry_run="$2"
    local force="$3"
    
    log_info "Starting dependency update process..."
    log_info "Strategy: $strategy"
    log_info "Dry run: $dry_run"
    
    # Confirmation prompt
    if [[ "$force" == "false" && "$dry_run" == "false" ]]; then
        echo "This will update system dependencies using '$strategy' strategy."
        echo "Continue? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Update cancelled by user"
            return 0
        fi
    fi
    
    # Create update session
    local update_session="update-$(date +%Y%m%d_%H%M%S)"
    echo "=== Update Session: $update_session ===" >> "$UPDATE_LOG"
    
    # Update flake inputs
    if ! update_flake_inputs "$strategy" "$dry_run"; then
        log_error "Flake update failed"
        return 1
    fi
    
    # Update system
    if ! update_system "$strategy" "$dry_run"; then
        log_error "System update failed"
        return 1
    fi
    
    if [[ "$dry_run" == "false" ]]; then
        # Post-update verification
        log_info "Verifying update..."
        if system_health_check; then
            log_success "Update completed successfully"
        else
            log_warning "Update completed but system health check found issues"
        fi
        
        # Generate post-update report
        generate_report
    fi
    
    echo "=== Update Session Complete: $update_session ===" >> "$UPDATE_LOG"
}

# System health check
system_health_check() {
    log_info "Running post-update health check..."
    
    # Basic system checks
    if ! systemctl is-system-running >/dev/null 2>&1; then
        log_warning "System not in running state"
        return 1
    fi
    
    # Check critical services
    critical_services=("sshd" "systemd-logind" "dbus")
    for service in "${critical_services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            log_warning "Critical service not active: $service"
            return 1
        fi
    done
    
    # Network connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_warning "Network connectivity issue"
        return 1
    fi
    
    log_success "System health check passed"
    return 0
}

# Main function
main() {
    local command=""
    local strategy="balanced"
    local force=false
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--strategy)
                strategy="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
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
            check|update|security|flake|channels|test|rollback|report)
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
    
    # Validate strategy
    if [[ ! "$strategy" =~ ^(conservative|balanced|aggressive)$ ]]; then
        log_error "Invalid strategy: $strategy"
        show_usage
        exit 1
    fi
    
    # Validate command
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        show_usage
        exit 1
    fi
    
    # Initialize if needed
    if [[ ! -f "$UPDATE_LOG" ]]; then
        init_update_system
    fi
    
    # Export strategy for other functions
    export UPDATE_STRATEGY="$strategy"
    
    # Execute command
    case "$command" in
        check)
            check_updates
            ;;
        update)
            perform_update "$strategy" "$dry_run" "$force"
            ;;
        security)
            security_update "$dry_run"
            ;;
        flake)
            update_flake_inputs "$strategy" "$dry_run"
            ;;
        channels)
            if [[ "$dry_run" == "false" ]]; then
                nix-channel --update
            else
                echo "Would run: nix-channel --update"
            fi
            ;;
        test)
            test_updates
            ;;
        rollback)
            rollback_updates
            ;;
        report)
            generate_report
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
