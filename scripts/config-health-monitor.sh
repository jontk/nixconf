#!/usr/bin/env bash

# Configuration Health Monitoring System
# Monitors NixOS configuration health, drift, and compliance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HEALTH_LOG="/var/log/config-health.log"
BASELINE_DIR="/var/lib/config-baselines"
ALERTS_EMAIL="${ALERTS_EMAIL:-}"
MONITORING_INTERVAL="${MONITORING_INTERVAL:-300}"  # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$HEALTH_LOG" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$HEALTH_LOG" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$HEALTH_LOG" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$HEALTH_LOG" >&2
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Configuration health monitoring system for NixOS

COMMANDS:
    monitor             Start continuous health monitoring
    check               Run one-time health check
    baseline            Create configuration baseline
    compare             Compare current config to baseline
    drift               Check for configuration drift
    compliance          Run compliance checks
    report              Generate health report
    fix                 Attempt to fix detected issues

OPTIONS:
    -i, --interval SEC  Monitoring interval in seconds (default: 300)
    -b, --baseline DIR  Baseline directory (default: /var/lib/config-baselines)
    -e, --email ADDR    Email for alerts
    -v, --verbose       Verbose output
    -h, --help          Show this help

EXAMPLES:
    $0 check                    # Run health check
    $0 monitor                  # Start continuous monitoring
    $0 baseline                 # Create new baseline
    $0 drift                    # Check for drift
    $0 compliance               # Run compliance checks

EOF
}

# Initialize health monitoring
init_health_monitoring() {
    log_info "Initializing configuration health monitoring..."
    
    # Create directories
    mkdir -p "$(dirname "$HEALTH_LOG")"
    mkdir -p "$BASELINE_DIR"
    touch "$HEALTH_LOG"
    
    # Record initialization
    echo "=== Configuration Health Monitoring Initialized: $(date) ===" >> "$HEALTH_LOG"
    
    log_success "Health monitoring initialized"
}

# Create configuration baseline
create_baseline() {
    local baseline_name="${1:-$(date +%Y%m%d_%H%M%S)}"
    local baseline_file="$BASELINE_DIR/baseline_${baseline_name}.json"
    
    log_info "Creating configuration baseline: $baseline_name"
    
    cd "$REPO_ROOT"
    
    # Collect comprehensive configuration state
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"baseline_name\": \"$baseline_name\","
        
        # Git state
        echo "  \"git\": {"
        echo "    \"commit\": \"$(git rev-parse HEAD 2>/dev/null || echo 'unknown')\","
        echo "    \"branch\": \"$(git branch --show-current 2>/dev/null || echo 'unknown')\","
        echo "    \"remote\": \"$(git remote get-url origin 2>/dev/null || echo 'unknown')\","
        echo "    \"status\": \"$(git status --porcelain | wc -l)\""
        echo "  },"
        
        # Flake state
        echo "  \"flake\": {"
        if [[ -f "flake.lock" ]]; then
            echo "    \"lock_hash\": \"$(sha256sum flake.lock | cut -d' ' -f1)\","
            echo "    \"inputs\": $(nix flake metadata --json | jq '.locks.nodes | to_entries | map(select(.key != "root")) | map({key: .key, value: .value.locked})' 2>/dev/null || echo '[]'),"
        else
            echo "    \"lock_hash\": null,"
            echo "    \"inputs\": [],"
        fi
        echo "    \"last_update\": \"$(stat -c %Y flake.lock 2>/dev/null || echo 0)\""
        echo "  },"
        
        # System state
        echo "  \"system\": {"
        if command -v nixos-rebuild >/dev/null 2>&1; then
            local current_gen
            current_gen=$(nixos-rebuild list-generations | tail -1 | awk '{print $1}' 2>/dev/null || echo 'unknown')
            echo "    \"type\": \"nixos\","
            echo "    \"generation\": \"$current_gen\","
            echo "    \"version\": \"$(nixos-version 2>/dev/null || echo 'unknown')\","
        elif command -v darwin-rebuild >/dev/null 2>&1; then
            echo "    \"type\": \"darwin\","
            echo "    \"generation\": \"unknown\","
            echo "    \"version\": \"$(sw_vers -productVersion 2>/dev/null || echo 'unknown')\","
        else
            echo "    \"type\": \"unknown\","
            echo "    \"generation\": \"unknown\","
            echo "    \"version\": \"unknown\","
        fi
        echo "    \"kernel\": \"$(uname -r)\","
        echo "    \"uptime\": \"$(uptime | awk '{print $3}' | sed 's/,//')\""
        echo "  },"
        
        # Configuration files
        echo "  \"configuration\": {"
        echo "    \"files\": ["
        find . -name "*.nix" -type f | head -100 | while read -r file; do
            echo "      {"
            echo "        \"path\": \"$file\","
            echo "        \"hash\": \"$(sha256sum "$file" | cut -d' ' -f1)\","
            echo "        \"size\": $(stat -c %s "$file"),"
            echo "        \"modified\": $(stat -c %Y "$file")"
            echo "      },"
        done | sed '$ s/,$//'
        echo "    ],"
        echo "    \"total_files\": $(find . -name "*.nix" -type f | wc -l),"
        echo "    \"config_hash\": \"$(find . -name '*.nix' -exec cat {} \; | sha256sum | cut -d' ' -f1)\""
        echo "  },"
        
        # Services state
        echo "  \"services\": {"
        if command -v systemctl >/dev/null 2>&1; then
            echo "    \"active\": ["
            systemctl list-units --type=service --state=active --no-legend | head -50 | while read -r line; do
                service_name=$(echo "$line" | awk '{print $1}')
                echo "      \"$service_name\","
            done | sed '$ s/,$//'
            echo "    ],"
            echo "    \"failed\": ["
            systemctl list-units --type=service --state=failed --no-legend | while read -r line; do
                service_name=$(echo "$line" | awk '{print $1}')
                echo "      \"$service_name\","
            done | sed '$ s/,$//'
            echo "    ],"
            echo "    \"total_active\": $(systemctl list-units --type=service --state=active --no-legend | wc -l),"
            echo "    \"total_failed\": $(systemctl list-units --type=service --state=failed --no-legend | wc -l)"
        else
            echo "    \"active\": [],"
            echo "    \"failed\": [],"
            echo "    \"total_active\": 0,"
            echo "    \"total_failed\": 0"
        fi
        echo "  },"
        
        # Network state
        echo "  \"network\": {"
        echo "    \"interfaces\": ["
        if command -v ip >/dev/null 2>&1; then
            ip -j link show | jq -c '.[] | {name: .ifname, state: .operstate}' | while read -r interface; do
                echo "      $interface,"
            done | sed '$ s/,$//'
        fi
        echo "    ],"
        echo "    \"routes\": $(ip -j route show 2>/dev/null | jq length || echo 0),"
        echo "    \"connectivity\": $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo true || echo false)"
        echo "  },"
        
        # Package state
        echo "  \"packages\": {"
        if command -v nix-env >/dev/null 2>&1; then
            echo "    \"user_packages\": $(nix-env -q 2>/dev/null | wc -l),"
        else
            echo "    \"user_packages\": 0,"
        fi
        echo "    \"store_size\": $(du -sb /nix/store 2>/dev/null | awk '{print $1}' || echo 0),"
        echo "    \"store_paths\": $(find /nix/store -maxdepth 1 -type d 2>/dev/null | wc -l || echo 0)"
        echo "  }"
        
        echo "}"
    } > "$baseline_file"
    
    # Create symlink to latest baseline
    ln -sf "$baseline_file" "$BASELINE_DIR/latest.json"
    
    # Cleanup old baselines (keep last 10)
    find "$BASELINE_DIR" -name "baseline_*.json" -type f | sort -r | tail -n +11 | xargs rm -f
    
    log_success "Baseline created: $baseline_file"
    echo "$baseline_file"
}

# Compare current configuration to baseline
compare_to_baseline() {
    local baseline_file="${1:-$BASELINE_DIR/latest.json}"
    local report_file
    report_file="/tmp/config-comparison-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Comparing current configuration to baseline..."
    
    if [[ ! -f "$baseline_file" ]]; then
        log_error "Baseline file not found: $baseline_file"
        log_info "Run '$0 baseline' to create a baseline first"
        return 1
    fi
    
    # Create current state snapshot
    local current_state
    current_state=$(mktemp)
    # shellcheck disable=SC2064 # expand $current_state now, not at trap time
    trap "rm -f '$current_state'" RETURN

    create_baseline "current" > /dev/null
    mv "$BASELINE_DIR/baseline_current.json" "$current_state"
    
    # Generate comparison report
    {
        echo "Configuration Comparison Report"
        echo "==============================="
        echo "Generated: $(date)"
        echo "Baseline: $baseline_file"
        echo "Current State: $current_state"
        echo
        
        # Git comparison
        echo "Git Changes:"
        baseline_commit=$(jq -r '.git.commit' "$baseline_file")
        current_commit=$(jq -r '.git.commit' "$current_state")
        
        if [[ "$baseline_commit" != "$current_commit" ]]; then
            echo "  ✗ Commit changed: $baseline_commit → $current_commit"
        else
            echo "  ✓ Commit unchanged: $current_commit"
        fi
        
        baseline_status=$(jq -r '.git.status' "$baseline_file")
        current_status=$(jq -r '.git.status' "$current_state")
        
        if [[ "$baseline_status" != "$current_status" ]]; then
            echo "  ✗ Git status changed: $baseline_status → $current_status uncommitted files"
        else
            echo "  ✓ Git status unchanged"
        fi
        echo
        
        # Flake comparison
        echo "Flake Changes:"
        baseline_hash=$(jq -r '.flake.lock_hash // "null"' "$baseline_file")
        current_hash=$(jq -r '.flake.lock_hash // "null"' "$current_state")
        
        if [[ "$baseline_hash" != "$current_hash" ]]; then
            echo "  ✗ Flake lock changed"
            echo "    Baseline: $baseline_hash"
            echo "    Current:  $current_hash"
        else
            echo "  ✓ Flake lock unchanged"
        fi
        echo
        
        # System comparison
        echo "System Changes:"
        baseline_gen=$(jq -r '.system.generation' "$baseline_file")
        current_gen=$(jq -r '.system.generation' "$current_state")
        
        if [[ "$baseline_gen" != "$current_gen" ]]; then
            echo "  ✗ Generation changed: $baseline_gen → $current_gen"
        else
            echo "  ✓ Generation unchanged: $current_gen"
        fi
        
        baseline_kernel=$(jq -r '.system.kernel' "$baseline_file")
        current_kernel=$(jq -r '.system.kernel' "$current_state")
        
        if [[ "$baseline_kernel" != "$current_kernel" ]]; then
            echo "  ✗ Kernel changed: $baseline_kernel → $current_kernel"
        else
            echo "  ✓ Kernel unchanged: $current_kernel"
        fi
        echo
        
        # Configuration files comparison
        echo "Configuration Changes:"
        baseline_config_hash=$(jq -r '.configuration.config_hash' "$baseline_file")
        current_config_hash=$(jq -r '.configuration.config_hash' "$current_state")
        
        if [[ "$baseline_config_hash" != "$current_config_hash" ]]; then
            echo "  ✗ Configuration files changed"
            echo "    Baseline hash: $baseline_config_hash"
            echo "    Current hash:  $current_config_hash"
        else
            echo "  ✓ Configuration files unchanged"
        fi
        
        baseline_files=$(jq -r '.configuration.total_files' "$baseline_file")
        current_files=$(jq -r '.configuration.total_files' "$current_state")
        
        if [[ "$baseline_files" != "$current_files" ]]; then
            echo "  ✗ File count changed: $baseline_files → $current_files"
        else
            echo "  ✓ File count unchanged: $current_files"
        fi
        echo
        
        # Services comparison
        echo "Services Changes:"
        baseline_failed=$(jq -r '.services.total_failed' "$baseline_file")
        current_failed=$(jq -r '.services.total_failed' "$current_state")
        
        if [[ "$baseline_failed" != "$current_failed" ]]; then
            echo "  ✗ Failed services changed: $baseline_failed → $current_failed"
            if [[ "$current_failed" -gt 0 ]]; then
                echo "    Current failed services:"
                jq -r '.services.failed[]' "$current_state" | head -5 | sed 's/^/      /'
            fi
        else
            echo "  ✓ Failed services unchanged: $current_failed"
        fi
        echo
        
        # Network comparison
        echo "Network Changes:"
        baseline_connectivity=$(jq -r '.network.connectivity' "$baseline_file")
        current_connectivity=$(jq -r '.network.connectivity' "$current_state")
        
        if [[ "$baseline_connectivity" != "$current_connectivity" ]]; then
            echo "  ✗ Connectivity changed: $baseline_connectivity → $current_connectivity"
        else
            echo "  ✓ Connectivity unchanged: $current_connectivity"
        fi
        echo
        
        # Package comparison
        echo "Package Changes:"
        baseline_user_packages=$(jq -r '.packages.user_packages' "$baseline_file")
        current_user_packages=$(jq -r '.packages.user_packages' "$current_state")
        
        if [[ "$baseline_user_packages" != "$current_user_packages" ]]; then
            echo "  ✗ User packages changed: $baseline_user_packages → $current_user_packages"
        else
            echo "  ✓ User packages unchanged: $current_user_packages"
        fi
        
        baseline_store_paths=$(jq -r '.packages.store_paths' "$baseline_file")
        current_store_paths=$(jq -r '.packages.store_paths' "$current_state")
        
        if [[ "$baseline_store_paths" != "$current_store_paths" ]]; then
            echo "  ✗ Store paths changed: $baseline_store_paths → $current_store_paths"
        else
            echo "  ✓ Store paths unchanged: $current_store_paths"
        fi
        
    } > "$report_file"
    
    # Display report
    cat "$report_file"
    
    # Check if significant changes detected
    if grep -q "✗" "$report_file"; then
        log_warning "Configuration changes detected"
        echo "$report_file" >> "$HEALTH_LOG"
        return 1
    else
        log_success "No significant configuration changes"
        return 0
    fi
}

# Check for configuration drift
check_drift() {
    log_info "Checking for configuration drift..."
    
    cd "$REPO_ROOT"
    local drift_issues=0
    
    # Git repository drift
    if [[ -d ".git" ]]; then
        log_info "Checking git repository drift..."
        
        # Uncommitted changes
        uncommitted=$(git status --porcelain | wc -l)
        if [[ $uncommitted -gt 0 ]]; then
            log_warning "Found $uncommitted uncommitted changes"
            git status --short | head -10 | while read -r line; do
                log_warning "  $line"
            done
            ((drift_issues++))
        fi
        
        # Unpushed commits
        if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            unpushed=$(git rev-list --count '@{u}'..HEAD 2>/dev/null || echo 0)
            if [[ $unpushed -gt 0 ]]; then
                log_warning "Found $unpushed unpushed commits"
                ((drift_issues++))
            fi
        fi
        
        # Untracked important files
        important_untracked=$(git ls-files --others --exclude-standard | grep -Ec '\.(nix|yaml|conf)$' || true)
        if [[ $important_untracked -gt 0 ]]; then
            log_warning "Found $important_untracked untracked configuration files"
            ((drift_issues++))
        fi
    fi
    
    # System configuration drift
    log_info "Checking system configuration drift..."
    
    # Manual package installations
    if command -v nix-env >/dev/null 2>&1; then
        manual_packages=$(nix-env -q 2>/dev/null | wc -l)
        if [[ $manual_packages -gt 0 ]]; then
            log_warning "Found $manual_packages manually installed packages"
            nix-env -q | head -5 | while read -r pkg; do
                log_warning "  Manual package: $pkg"
            done
            ((drift_issues++))
        fi
    fi
    
    # Failed services
    failed_services=$(systemctl --failed --no-legend | wc -l)
    if [[ $failed_services -gt 0 ]]; then
        log_warning "Found $failed_services failed services"
        systemctl --failed --no-legend | while read -r line; do
            service_name=$(echo "$line" | awk '{print $1}')
            log_warning "  Failed service: $service_name"
        done
        ((drift_issues++))
    fi
    
    # Configuration file modifications
    if command -v nixos-rebuild >/dev/null 2>&1; then
        # Check if system matches configuration
        if ! nixos-rebuild dry-run >/dev/null 2>&1; then
            log_warning "System configuration differs from declared configuration"
            ((drift_issues++))
        fi
    fi
    
    # Summary
    if [[ $drift_issues -eq 0 ]]; then
        log_success "No configuration drift detected"
        return 0
    else
        log_warning "Configuration drift detected: $drift_issues issues found"
        return 1
    fi
}

# Run compliance checks
compliance_check() {
    log_info "Running compliance checks..."
    
    local compliance_issues=0
    
    # Security compliance
    echo "Security Compliance:" >> "$HEALTH_LOG"
    
    # Check for secrets in configuration
    if grep -r "password\|secret\|key" --include="*.nix" "$REPO_ROOT" | grep -v "sops.secrets" | grep -v "# " | head -5 >/dev/null; then
        log_warning "Potential hardcoded secrets found in configuration"
        ((compliance_issues++))
    fi
    
    # Check file permissions
    suspicious_perms=$(find "$REPO_ROOT" -name "*.nix" -not -perm 644 | head -5)
    if [[ -n "$suspicious_perms" ]]; then
        log_warning "Configuration files with unusual permissions found"
        echo "$suspicious_perms" | while read -r file; do
            log_warning "  $(ls -la "$file")"
        done
        ((compliance_issues++))
    fi
    
    # Documentation compliance
    echo "Documentation Compliance:" >> "$HEALTH_LOG"
    
    # Check for README
    if [[ ! -f "$REPO_ROOT/README.md" ]]; then
        log_warning "Missing README.md"
        ((compliance_issues++))
    fi
    
    # Check for CLAUDE.md
    if [[ ! -f "$REPO_ROOT/CLAUDE.md" ]]; then
        log_warning "Missing CLAUDE.md"
        ((compliance_issues++))
    fi
    
    # Module documentation
    modules_without_docs=$(find "$REPO_ROOT/modules" -name "default.nix" | while read -r module; do
        if ! grep -q "description.*=" "$module"; then
            echo "$module"
        fi
    done | wc -l)
    
    if [[ $modules_without_docs -gt 0 ]]; then
        log_warning "$modules_without_docs modules missing descriptions"
        ((compliance_issues++))
    fi
    
    # Configuration structure compliance
    echo "Structure Compliance:" >> "$HEALTH_LOG"
    
    # Check for proper module structure
    if [[ -d "$REPO_ROOT/modules" ]]; then
        improper_modules=$(find "$REPO_ROOT/modules" -name "default.nix" | while read -r module; do
            if ! grep -q "options\\..*=" "$module" || ! grep -q "config.*=" "$module"; then
                echo "$module"
            fi
        done | wc -l)
        
        if [[ $improper_modules -gt 0 ]]; then
            log_warning "$improper_modules modules with improper structure"
            ((compliance_issues++))
        fi
    fi
    
    # Git compliance
    echo "Git Compliance:" >> "$HEALTH_LOG"
    
    if [[ -d "$REPO_ROOT/.git" ]]; then
        # Check for proper gitignore
        if [[ ! -f "$REPO_ROOT/.gitignore" ]]; then
            log_warning "Missing .gitignore file"
            ((compliance_issues++))
        fi
        
        # Check for large files
        large_files=$(find "$REPO_ROOT" -size +1M -not -path "*/.git/*" | head -5)
        if [[ -n "$large_files" ]]; then
            log_warning "Large files found in repository"
            echo "$large_files" | while read -r file; do
                log_warning "  $(ls -lh "$file")"
            done
            ((compliance_issues++))
        fi
    fi
    
    # Summary
    if [[ $compliance_issues -eq 0 ]]; then
        log_success "All compliance checks passed"
        return 0
    else
        log_warning "Compliance issues found: $compliance_issues"
        return 1
    fi
}

# Run comprehensive health check
health_check() {
    log_info "Running comprehensive configuration health check..."
    
    local health_score=0
    local total_checks=4
    
    # Configuration syntax check
    log_info "1. Configuration syntax check..."
    if nix flake check >/dev/null 2>&1; then
        log_success "Configuration syntax valid"
        ((health_score++))
    else
        log_error "Configuration syntax errors detected"
    fi
    
    # Drift detection
    log_info "2. Configuration drift check..."
    if check_drift >/dev/null 2>&1; then
        log_success "No configuration drift"
        ((health_score++))
    else
        log_warning "Configuration drift detected"
    fi
    
    # Compliance check
    log_info "3. Compliance check..."
    if compliance_check >/dev/null 2>&1; then
        log_success "Compliance checks passed"
        ((health_score++))
    else
        log_warning "Compliance issues found"
    fi
    
    # System health
    log_info "4. System health check..."
    if system_health_basic; then
        log_success "System health good"
        ((health_score++))
    else
        log_warning "System health issues detected"
    fi
    
    # Calculate health percentage
    local health_percentage=$((health_score * 100 / total_checks))
    
    log_info "Configuration Health Score: $health_score/$total_checks ($health_percentage%)"
    
    if [[ $health_percentage -ge 90 ]]; then
        log_success "Configuration health: EXCELLENT"
    elif [[ $health_percentage -ge 75 ]]; then
        log_success "Configuration health: GOOD"
    elif [[ $health_percentage -ge 50 ]]; then
        log_warning "Configuration health: FAIR"
    else
        log_error "Configuration health: POOR"
    fi
    
    return $((total_checks - health_score))
}

# Basic system health check
system_health_basic() {
    # Check system running state
    if ! systemctl is-system-running | grep -q "running\|degraded"; then
        return 1
    fi
    
    # Check critical services
    local critical_services=("sshd" "systemd-logind")
    for service in "${critical_services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            return 1
        fi
    done
    
    # Check basic connectivity
    if ! ping -c 1 127.0.0.1 >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Attempt to fix detected issues
fix_issues() {
    log_info "Attempting to fix detected configuration issues..."
    
    local fixes_applied=0
    
    # Fix git repository issues
    if [[ -d "$REPO_ROOT/.git" ]]; then
        cd "$REPO_ROOT"
        
        # Add untracked configuration files
        untracked_configs=$(git ls-files --others --exclude-standard | grep -E '\.(nix|yaml|conf)$')
        if [[ -n "$untracked_configs" ]]; then
            echo "$untracked_configs" | while read -r file; do
                log_info "Adding untracked configuration file: $file"
                git add "$file"
                ((fixes_applied++))
            done
        fi
        
        # Commit changes if any
        if [[ $(git status --porcelain | wc -l) -gt 0 ]]; then
            log_info "Committing outstanding changes..."
            git commit -m "Automated fix: commit outstanding configuration changes

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
            ((fixes_applied++))
        fi
    fi
    
    # Fix failed services
    failed_services=$(systemctl --failed --no-legend | awk '{print $1}')
    if [[ -n "$failed_services" ]]; then
        echo "$failed_services" | while read -r service; do
            log_info "Attempting to restart failed service: $service"
            if systemctl restart "$service"; then
                log_success "Successfully restarted $service"
                ((fixes_applied++))
            else
                log_warning "Failed to restart $service"
            fi
        done
    fi
    
    # Clean up manual packages
    if command -v nix-env >/dev/null 2>&1; then
        manual_packages=$(nix-env -q 2>/dev/null | wc -l)
        if [[ $manual_packages -gt 0 ]]; then
            log_info "Found $manual_packages manually installed packages"
            log_info "Consider adding these to your configuration and removing manually"
            # Don't auto-remove as this could be destructive
        fi
    fi
    
    # Fix permissions
    find "$REPO_ROOT" -name "*.nix" -not -perm 644 -exec chmod 644 {} \; 2>/dev/null
    ((fixes_applied++))
    
    if [[ $fixes_applied -gt 0 ]]; then
        log_success "Applied $fixes_applied fixes"
    else
        log_info "No automatic fixes available"
    fi
}

# Generate health report
generate_health_report() {
    local report_file
    report_file="/tmp/config-health-report-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating configuration health report..."
    
    {
        echo "Configuration Health Report"
        echo "=========================="
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "Repository: $REPO_ROOT"
        echo
        
        echo "Health Check Results"
        echo "-------------------"
        health_check 2>&1
        echo
        
        echo "Drift Analysis"
        echo "-------------"
        check_drift 2>&1
        echo
        
        echo "Compliance Status"
        echo "----------------"
        compliance_check 2>&1
        echo
        
        echo "Recent Health Log"
        echo "----------------"
        tail -20 "$HEALTH_LOG"
        
    } > "$report_file"
    
    log_success "Health report generated: $report_file"
    
    # Display report
    cat "$report_file"


    # Email report if configured
    if [[ -n "$ALERTS_EMAIL" ]]; then
        mail -s "Configuration Health Report - $(hostname)" "$ALERTS_EMAIL" < "$report_file"
        log_info "Report emailed to $ALERTS_EMAIL"
    fi
}

# Start continuous monitoring
start_monitoring() {
    log_info "Starting continuous configuration health monitoring..."
    log_info "Monitoring interval: $MONITORING_INTERVAL seconds"
    
    # Create initial baseline if none exists
    if [[ ! -f "$BASELINE_DIR/latest.json" ]]; then
        log_info "Creating initial baseline..."
        create_baseline "initial" >/dev/null
    fi
    
    # Monitoring loop
    while true; do
        echo "=== Monitoring Cycle: $(date) ===" >> "$HEALTH_LOG"
        
        # Run health check
        if ! health_check >/dev/null 2>&1; then
            log_warning "Health check issues detected"
            
            # Send alert
            if [[ -n "$ALERTS_EMAIL" ]]; then
                echo "Configuration health issues detected on $(hostname) at $(date)" | \
                    mail -s "Configuration Health Alert - $(hostname)" "$ALERTS_EMAIL"
            fi
        fi
        
        # Check for drift
        if ! check_drift >/dev/null 2>&1; then
            log_warning "Configuration drift detected"
        fi
        
        # Sleep until next check
        sleep "$MONITORING_INTERVAL"
    done
}

# Main function
main() {
    local command=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interval)
                MONITORING_INTERVAL="$2"
                shift 2
                ;;
            -b|--baseline)
                BASELINE_DIR="$2"
                shift 2
                ;;
            -e|--email)
                ALERTS_EMAIL="$2"
                shift 2
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            monitor|check|baseline|compare|drift|compliance|report|fix)
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
    
    # Initialize if needed
    if [[ ! -f "$HEALTH_LOG" ]]; then
        init_health_monitoring
    fi
    
    # Execute command
    case "$command" in
        monitor)
            start_monitoring
            ;;
        check)
            health_check
            ;;
        baseline)
            create_baseline
            ;;
        compare)
            compare_to_baseline "$2"
            ;;
        drift)
            check_drift
            ;;
        compliance)
            compliance_check
            ;;
        report)
            generate_health_report
            ;;
        fix)
            fix_issues
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
