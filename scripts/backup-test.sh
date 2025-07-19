#!/usr/bin/env bash

# Backup Verification and Testing Script
# Provides comprehensive backup testing and validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/nixconf-backups}"
TEST_LOG="${TEST_LOG:-/tmp/nixconf-backup-test.log}"
TEST_WORKSPACE="/tmp/nixconf-backup-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$TEST_LOG" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$TEST_LOG" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$TEST_LOG" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$TEST_LOG" >&2
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Backup Verification and Testing System

COMMANDS:
    verify              Verify backup integrity and checksums
    test-restore        Test backup restoration process
    test-complete       Run complete backup test cycle
    validate-config     Validate configuration files in backups
    performance-test    Test backup/restore performance
    schedule-tests      Schedule automated backup testing
    report              Generate backup test report

OPTIONS:
    -b, --backup NAME   Test specific backup (default: latest)
    -w, --workspace DIR Test workspace directory (default: /tmp/nixconf-backup-test)
    -k, --keep          Keep test workspace after completion
    -v, --verbose       Verbose output
    -h, --help          Show this help

EXAMPLES:
    $0 verify                           # Verify all backups
    $0 test-restore                     # Test restore from latest backup
    $0 test-complete -b nixconf_backup_20240119_143022
    $0 performance-test                 # Test backup performance
    $0 report                          # Generate test report

EOF
}

# Initialize test environment
init_test_env() {
    log_info "Initializing test environment..."
    
    # Create test workspace
    rm -rf "$TEST_WORKSPACE"
    mkdir -p "$TEST_WORKSPACE"
    
    # Create test log
    mkdir -p "$(dirname "$TEST_LOG")"
    touch "$TEST_LOG"
    
    # Record test start
    echo "=== Backup Test Session Started: $(date) ===" >> "$TEST_LOG"
    
    log_success "Test environment initialized"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ "${KEEP_WORKSPACE:-}" != "true" ]]; then
        log_info "Cleaning up test environment..."
        rm -rf "$TEST_WORKSPACE"
        log_success "Test environment cleaned up"
    else
        log_info "Test workspace preserved at: $TEST_WORKSPACE"
    fi
}

# Verify backup integrity
verify_backups() {
    local backup_name="${1:-}"
    local verified=0
    local failed=0
    
    log_info "Verifying backup integrity..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    if [[ -n "$backup_name" ]]; then
        # Verify specific backup
        verify_single_backup "$backup_name"
        return $?
    fi
    
    # Verify all backups
    for backup in "$BACKUP_DIR"/nixconf_backup_*.tar.gz; do
        if [[ -f "$backup" ]]; then
            local basename=$(basename "$backup" .tar.gz)
            if verify_single_backup "$basename"; then
                ((verified++))
            else
                ((failed++))
            fi
        fi
    done
    
    log_info "Verification complete: $verified verified, $failed failed"
    return $failed
}

# Verify single backup
verify_single_backup() {
    local backup_name="$1"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    local checksum_file="$BACKUP_DIR/${backup_name}.tar.gz.sha256"
    
    log_info "Verifying backup: $backup_name"
    
    # Check if files exist
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    if [[ ! -f "$checksum_file" ]]; then
        log_error "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Verify checksum
    log_info "Checking SHA256 checksum..."
    if (cd "$BACKUP_DIR" && sha256sum -c "${backup_name}.tar.gz.sha256" >/dev/null 2>&1); then
        log_success "Checksum verification passed"
    else
        log_error "Checksum verification failed"
        return 1
    fi
    
    # Test archive integrity
    log_info "Testing archive integrity..."
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_success "Archive integrity check passed"
    else
        log_error "Archive integrity check failed"
        return 1
    fi
    
    # Verify archive contents
    log_info "Verifying archive contents..."
    local temp_dir="$TEST_WORKSPACE/verify_${backup_name}"
    mkdir -p "$temp_dir"
    
    if tar -xzf "$backup_file" -C "$temp_dir" >/dev/null 2>&1; then
        # Check for required files
        local extracted_dir="$temp_dir/$backup_name"
        
        # Check metadata
        if [[ -f "$extracted_dir/metadata.json" ]]; then
            log_success "Metadata file present"
            
            # Validate JSON
            if command -v jq >/dev/null 2>&1; then
                if jq empty "$extracted_dir/metadata.json" 2>/dev/null; then
                    log_success "Metadata JSON is valid"
                else
                    log_warning "Metadata JSON is invalid"
                fi
            fi
        else
            log_warning "Metadata file missing"
        fi
        
        # Check configuration files
        if [[ -d "$extracted_dir/nixconf" ]]; then
            log_success "Configuration directory present"
            
            # Check for key files
            if [[ -f "$extracted_dir/nixconf/flake.nix" ]]; then
                log_success "Core configuration files present"
            else
                log_warning "Core configuration files missing"
            fi
        else
            log_error "Configuration directory missing"
            return 1
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
        
        log_success "Backup verification completed: $backup_name"
        return 0
    else
        log_error "Failed to extract backup archive"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test backup restoration
test_restore() {
    local backup_name="${1:-}"
    
    log_info "Testing backup restoration..."
    
    # Find backup to test
    if [[ -z "$backup_name" ]]; then
        backup_name=$(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" | sort | tail -1)
        if [[ -z "$backup_name" ]]; then
            log_error "No backups found for testing"
            return 1
        fi
        backup_name=$(basename "$backup_name" .tar.gz)
    fi
    
    log_info "Testing restore of backup: $backup_name"
    
    # Create test restore environment
    local restore_dir="$TEST_WORKSPACE/restore_test"
    mkdir -p "$restore_dir"
    
    # Extract backup
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    log_info "Extracting backup for restore test..."
    if tar -xzf "$backup_file" -C "$restore_dir"; then
        log_success "Backup extraction successful"
    else
        log_error "Backup extraction failed"
        return 1
    fi
    
    # Verify extracted content
    local extracted_backup="$restore_dir/$backup_name"
    
    # Test configuration validity
    log_info "Testing configuration validity..."
    if [[ -d "$extracted_backup/nixconf" ]]; then
        # Check flake syntax
        if command -v nix >/dev/null 2>&1; then
            if (cd "$extracted_backup/nixconf" && nix flake check --no-build 2>/dev/null); then
                log_success "Configuration syntax is valid"
            else
                log_warning "Configuration has syntax issues"
            fi
        fi
        
        # Check for common issues
        if grep -r "TODO\|FIXME\|XXX" "$extracted_backup/nixconf" >/dev/null 2>&1; then
            log_warning "Configuration contains TODO/FIXME markers"
        fi
        
        # Check file permissions
        if find "$extracted_backup/nixconf" -name "*.nix" -not -perm 644 | grep -q .; then
            log_warning "Some .nix files have unusual permissions"
        fi
        
        log_success "Restore test completed successfully"
        return 0
    else
        log_error "Extracted backup missing configuration directory"
        return 1
    fi
}

# Complete backup test cycle
test_complete() {
    local backup_name="${1:-}"
    local start_time=$(date +%s)
    
    log_info "Starting complete backup test cycle..."
    
    # Initialize test environment
    init_test_env
    
    # Test 1: Backup integrity verification
    log_info "Test 1: Backup integrity verification"
    if verify_backups "$backup_name"; then
        log_success "Integrity verification passed"
    else
        log_error "Integrity verification failed"
        cleanup_test_env
        return 1
    fi
    
    # Test 2: Restore functionality
    log_info "Test 2: Restore functionality test"
    if test_restore "$backup_name"; then
        log_success "Restore test passed"
    else
        log_error "Restore test failed"
        cleanup_test_env
        return 1
    fi
    
    # Test 3: Configuration validation
    log_info "Test 3: Configuration validation"
    if validate_config "$backup_name"; then
        log_success "Configuration validation passed"
    else
        log_warning "Configuration validation had issues"
    fi
    
    # Test 4: Performance check
    log_info "Test 4: Performance check"
    if performance_test "$backup_name"; then
        log_success "Performance test passed"
    else
        log_warning "Performance test had issues"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Complete test cycle finished in ${duration}s"
    
    # Generate test report
    generate_test_report "$backup_name" "$duration"
    
    # Cleanup
    cleanup_test_env
    
    return 0
}

# Validate configuration files
validate_config() {
    local backup_name="${1:-}"
    
    log_info "Validating configuration files..."
    
    # Extract backup if needed
    if [[ -n "$backup_name" ]]; then
        local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
        local extract_dir="$TEST_WORKSPACE/validate_${backup_name}"
        
        mkdir -p "$extract_dir"
        tar -xzf "$backup_file" -C "$extract_dir"
        
        local config_dir="$extract_dir/$backup_name/nixconf"
    else
        local config_dir="$REPO_ROOT"
    fi
    
    if [[ ! -d "$config_dir" ]]; then
        log_error "Configuration directory not found"
        return 1
    fi
    
    local issues=0
    
    # Check Nix syntax
    log_info "Checking Nix file syntax..."
    while IFS= read -r -d '' file; do
        if ! nix-instantiate --parse "$file" >/dev/null 2>&1; then
            log_error "Syntax error in: $file"
            ((issues++))
        fi
    done < <(find "$config_dir" -name "*.nix" -print0)
    
    # Check for common issues
    log_info "Checking for common configuration issues..."
    
    # Check for hardcoded paths
    if grep -r "/home/[^/]*/" "$config_dir" >/dev/null 2>&1; then
        log_warning "Found hardcoded home paths"
        ((issues++))
    fi
    
    # Check for missing imports
    while IFS= read -r -d '' file; do
        if grep -q "import.*\.nix" "$file"; then
            # Extract import paths and check if they exist
            grep -o "import [^;]*" "$file" | while read -r imp; do
                local import_path=$(echo "$imp" | sed 's/import //' | tr -d '"')
                if [[ "$import_path" =~ ^\. ]]; then
                    local full_path="$(dirname "$file")/$import_path"
                    if [[ ! -f "$full_path" ]]; then
                        log_warning "Missing import in $file: $import_path"
                        ((issues++))
                    fi
                fi
            done
        fi
    done < <(find "$config_dir" -name "*.nix" -print0)
    
    # Check flake.lock consistency
    if [[ -f "$config_dir/flake.nix" && -f "$config_dir/flake.lock" ]]; then
        log_info "Checking flake.lock consistency..."
        if (cd "$config_dir" && nix flake check --no-build 2>/dev/null); then
            log_success "Flake configuration is valid"
        else
            log_warning "Flake configuration has issues"
            ((issues++))
        fi
    fi
    
    log_info "Configuration validation completed with $issues issues"
    return $issues
}

# Performance testing
performance_test() {
    local backup_name="${1:-}"
    
    log_info "Running performance tests..."
    
    local perf_dir="$TEST_WORKSPACE/performance"
    mkdir -p "$perf_dir"
    
    # Test backup creation performance
    log_info "Testing backup creation performance..."
    local start_time=$(date +%s.%N)
    
    # Create a test backup
    if [[ -f "$SCRIPT_DIR/backup.sh" ]]; then
        BACKUP_DIR="$perf_dir" "$SCRIPT_DIR/backup.sh" backup >/dev/null 2>&1
        local end_time=$(date +%s.%N)
        local backup_duration=$(echo "$end_time - $start_time" | bc -l)
        
        log_info "Backup creation took: ${backup_duration}s"
        
        # Check backup size
        local backup_file=$(find "$perf_dir" -name "nixconf_backup_*.tar.gz" | head -1)
        if [[ -f "$backup_file" ]]; then
            local backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
            local backup_size_mb=$((backup_size / 1024 / 1024))
            log_info "Backup size: ${backup_size_mb}MB"
        fi
    else
        log_warning "Backup script not found, skipping creation test"
    fi
    
    # Test restore performance if we have a backup
    if [[ -n "$backup_name" ]]; then
        log_info "Testing restore performance..."
        local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
        
        if [[ -f "$backup_file" ]]; then
            local restore_dir="$perf_dir/restore_test"
            mkdir -p "$restore_dir"
            
            local start_time=$(date +%s.%N)
            tar -xzf "$backup_file" -C "$restore_dir" >/dev/null 2>&1
            local end_time=$(date +%s.%N)
            local restore_duration=$(echo "$end_time - $start_time" | bc -l)
            
            log_info "Restore extraction took: ${restore_duration}s"
        fi
    fi
    
    # Test verification performance
    log_info "Testing verification performance..."
    local start_time=$(date +%s.%N)
    verify_single_backup "$backup_name" >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local verify_duration=$(echo "$end_time - $start_time" | bc -l)
    
    log_info "Verification took: ${verify_duration}s"
    
    log_success "Performance testing completed"
    return 0
}

# Schedule automated tests
schedule_tests() {
    log_info "Scheduling automated backup tests..."
    
    # Create systemd timer for backup testing
    cat > /etc/systemd/system/nixconf-backup-test.timer << 'EOF'
[Unit]
Description=NixOS Configuration Backup Test Timer
Requires=nixconf-backup-test.service

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
    
    # Create systemd service for backup testing
    cat > /etc/systemd/system/nixconf-backup-test.service << EOF
[Unit]
Description=NixOS Configuration Backup Test
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=$SCRIPT_DIR/backup-test.sh test-complete
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start timer
    systemctl daemon-reload
    systemctl enable nixconf-backup-test.timer
    systemctl start nixconf-backup-test.timer
    
    log_success "Automated backup testing scheduled (weekly)"
}

# Generate test report
generate_test_report() {
    local backup_name="${1:-}"
    local duration="${2:-}"
    
    local report_file="$TEST_WORKSPACE/backup-test-report.txt"
    
    log_info "Generating test report..."
    
    cat > "$report_file" << EOF
NixOS Configuration Backup Test Report
=====================================

Test Date: $(date)
Test Duration: ${duration:-N/A}s
Backup Tested: ${backup_name:-All backups}

Test Results:
EOF
    
    # Add test results
    if [[ -f "$TEST_LOG" ]]; then
        echo "" >> "$report_file"
        echo "Detailed Log:" >> "$report_file"
        echo "=============" >> "$report_file"
        tail -50 "$TEST_LOG" >> "$report_file"
    fi
    
    # Copy report to backup directory
    if [[ -d "$BACKUP_DIR" ]]; then
        cp "$report_file" "$BACKUP_DIR/last-test-report.txt"
    fi
    
    log_success "Test report generated: $report_file"
}

# Show test report
show_report() {
    log_info "Backup Test Report"
    echo "=================="
    
    # Show last test results
    if [[ -f "$BACKUP_DIR/last-test-report.txt" ]]; then
        cat "$BACKUP_DIR/last-test-report.txt"
    else
        echo "No test report found. Run 'test-complete' to generate one."
    fi
}

# Main function
main() {
    local command=""
    local backup_name=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backup)
                backup_name="$2"
                shift 2
                ;;
            -w|--workspace)
                TEST_WORKSPACE="$2"
                shift 2
                ;;
            -k|--keep)
                KEEP_WORKSPACE="true"
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
            verify|test-restore|test-complete|validate-config|performance-test|schedule-tests|report)
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
    
    # Execute command
    case "$command" in
        verify)
            verify_backups "$backup_name"
            ;;
        test-restore)
            init_test_env
            test_restore "$backup_name"
            cleanup_test_env
            ;;
        test-complete)
            test_complete "$backup_name"
            ;;
        validate-config)
            init_test_env
            validate_config "$backup_name"
            cleanup_test_env
            ;;
        performance-test)
            init_test_env
            performance_test "$backup_name"
            cleanup_test_env
            ;;
        schedule-tests)
            schedule_tests
            ;;
        report)
            show_report
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