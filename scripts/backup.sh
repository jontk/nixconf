#!/usr/bin/env bash

# Automated Backup Script for Nix Configuration Repository
# Provides comprehensive backup and recovery capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/nixconf-backups}"
REMOTE_BACKUP="${REMOTE_BACKUP:-}"
CLOUD_STORAGE="${CLOUD_STORAGE:-}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-s3}"
S3_BUCKET="${S3_BUCKET:-}"
GCS_BUCKET="${GCS_BUCKET:-}"
AZURE_CONTAINER="${AZURE_CONTAINER:-}"
MAX_LOCAL_BACKUPS="${MAX_LOCAL_BACKUPS:-10}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_NAME="nixconf_backup_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Automated backup and recovery for Nix configuration repository

COMMANDS:
    backup          Create a new backup
    restore         Restore from a backup
    list            List available backups
    cleanup         Remove old backups
    verify          Verify backup integrity
    init            Initialize backup system

OPTIONS:
    -d, --backup-dir DIR    Backup directory (default: ~/.local/share/nixconf-backups)
    -r, --remote URL        Remote backup location (rsync compatible)
    -c, --cloud PROVIDER    Cloud storage provider (s3, gcs, azure)
    --s3-bucket NAME        S3 bucket name for cloud backups
    --gcs-bucket NAME       Google Cloud Storage bucket name
    --azure-container NAME  Azure Storage container name
    -n, --name NAME         Backup name suffix
    -f, --force             Force operation without confirmation
    -v, --verbose           Verbose output
    -h, --help              Show this help

EXAMPLES:
    $0 backup                           # Create local backup
    $0 backup -r user@server:/backups  # Create backup and sync to remote
    $0 backup -c s3 --s3-bucket my-backups     # Backup to AWS S3
    $0 backup -c gcs --gcs-bucket my-backups   # Backup to Google Cloud Storage
    $0 restore nixconf_backup_20240119_143022  # Restore specific backup
    $0 list                             # List all available backups
    $0 cleanup                          # Remove old backups

EOF
}

# Initialize backup system
init_backup_system() {
    log_info "Initializing backup system..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    
    # Create backup metadata directory
    mkdir -p "$BACKUP_DIR/.metadata"
    
    # Create backup configuration
    cat > "$BACKUP_DIR/.metadata/config" << EOF
# Backup configuration
CREATED=$(date -Iseconds)
REPO_PATH=$REPO_ROOT
MAX_BACKUPS=$MAX_LOCAL_BACKUPS
REMOTE_BACKUP=$REMOTE_BACKUP
EOF
    
    log_success "Backup system initialized at $BACKUP_DIR"
}

# Create backup
create_backup() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    log_info "Creating backup: $BACKUP_NAME"
    
    # Ensure backup directory exists
    [[ -d "$BACKUP_DIR" ]] || init_backup_system
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "repo_path": "$REPO_ROOT",
    "git_commit": "$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(cd "$REPO_ROOT" && git branch --show-current 2>/dev/null || echo 'unknown')",
    "nix_version": "$(nix --version 2>/dev/null || echo 'unknown')",
    "system": "$(uname -s)",
    "architecture": "$(uname -m)"
}
EOF
    
    # Backup Nix configuration files
    log_info "Backing up Nix configuration files..."
    rsync -av --exclude='.git' --exclude='result*' --exclude='logs/' \
          "$REPO_ROOT/" "$backup_path/nixconf/"
    
    # Backup current system generation (NixOS)
    if command -v nixos-rebuild >/dev/null 2>&1; then
        log_info "Backing up NixOS system generation..."
        mkdir -p "$backup_path/system"
        
        # Current generation info
        nixos-version > "$backup_path/system/nixos-version" 2>/dev/null || true
        ls -la /nix/var/nix/profiles/system* > "$backup_path/system/generations" 2>/dev/null || true
        
        # Hardware configuration
        if [[ -f /etc/nixos/hardware-configuration.nix ]]; then
            cp /etc/nixos/hardware-configuration.nix "$backup_path/system/" 2>/dev/null || true
        fi
    fi
    
    # Backup current user generation (Home Manager)
    if command -v home-manager >/dev/null 2>&1; then
        log_info "Backing up Home Manager generation..."
        mkdir -p "$backup_path/home-manager"
        ls -la ~/.local/state/nix/profiles/home-manager* > "$backup_path/home-manager/generations" 2>/dev/null || true
    fi
    
    # Backup important system files
    log_info "Backing up system files..."
    mkdir -p "$backup_path/system-files"
    
    # SSH keys (if they exist)
    if [[ -d ~/.ssh ]]; then
        cp -r ~/.ssh "$backup_path/system-files/" 2>/dev/null || true
    fi
    
    # GPG keys (if they exist)
    if [[ -d ~/.gnupg ]]; then
        cp -r ~/.gnupg "$backup_path/system-files/" 2>/dev/null || true
    fi
    
    # Create backup archive
    log_info "Creating backup archive..."
    tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    
    # Verify backup
    if tar -tzf "$backup_path.tar.gz" >/dev/null 2>&1; then
        log_success "Backup archive created successfully: $backup_path.tar.gz"
    else
        log_error "Backup archive verification failed"
        return 1
    fi
    
    # Calculate checksums
    cd "$BACKUP_DIR"
    sha256sum "$BACKUP_NAME.tar.gz" > "$BACKUP_NAME.tar.gz.sha256"
    
    # Remove uncompressed backup directory
    rm -rf "$backup_path"
    
    # Sync to remote if specified
    if [[ -n "$REMOTE_BACKUP" ]]; then
        log_info "Syncing backup to remote location: $REMOTE_BACKUP"
        rsync -av "$backup_path.tar.gz" "$backup_path.tar.gz.sha256" "$REMOTE_BACKUP/"
        log_success "Remote backup completed"
    fi
    
    # Upload to cloud storage if specified
    if [[ -n "$CLOUD_STORAGE" ]]; then
        upload_to_cloud "$backup_path.tar.gz" "$backup_path.tar.gz.sha256"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    log_success "Backup completed: $BACKUP_NAME"
}

# List available backups
list_backups() {
    log_info "Available backups in $BACKUP_DIR:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warning "No backup directory found. Run 'init' first."
        return 1
    fi
    
    local count=0
    for backup in "$BACKUP_DIR"/nixconf_backup_*.tar.gz; do
        if [[ -f "$backup" ]]; then
            local basename
            local size
            local date
            basename=$(basename "$backup" .tar.gz)
            size=$(du -h "$backup" | cut -f1)
            date=$(echo "$basename" | sed 's/nixconf_backup_//' | sed 's/_/ /')
            printf "  %-30s  %8s  %s\n" "$basename" "$size" "$date"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_warning "No backups found"
    else
        log_info "Total backups: $count"
    fi
}

# Restore from backup
restore_backup() {
    local backup_name="$1"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    # Try to download from cloud if backup not found locally
    if [[ ! -f "$backup_file" && -n "$CLOUD_STORAGE" ]]; then
        log_info "Backup not found locally, attempting cloud download..."
        download_from_cloud "$backup_name"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup not found: $backup_file"
        return 1
    fi
    
    log_warning "This will restore configuration from backup: $backup_name"
    log_warning "Current configuration will be backed up first"
    
    if [[ "${FORCE:-}" != "true" ]]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restore cancelled"
            return 0
        fi
    fi
    
    # Create backup of current state first
    log_info "Creating backup of current state..."
    BACKUP_NAME="nixconf_backup_pre_restore_${TIMESTAMP}"
    create_backup
    
    # Extract backup
    log_info "Extracting backup: $backup_name"
    local temp_dir
    temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore Nix configuration
    log_info "Restoring Nix configuration..."
    rsync -av --delete "$temp_dir/$backup_name/nixconf/" "$REPO_ROOT/"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Restore completed from: $backup_name"
    log_info "You may need to rebuild your system configuration"
}

# Verify backup integrity
verify_backup() {
    local backup_name="${1:-}"
    local verified=0
    local failed=0
    
    log_info "Verifying backup integrity..."
    
    if [[ -n "$backup_name" ]]; then
        # Verify specific backup
        local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
        local checksum_file="$BACKUP_DIR/${backup_name}.tar.gz.sha256"
        
        if [[ -f "$backup_file" && -f "$checksum_file" ]]; then
            if (cd "$BACKUP_DIR" && sha256sum -c "${backup_name}.tar.gz.sha256" >/dev/null 2>&1); then
                log_success "Backup verified: $backup_name"
                ((verified++))
            else
                log_error "Backup verification failed: $backup_name"
                ((failed++))
            fi
        else
            log_error "Backup or checksum file not found: $backup_name"
            ((failed++))
        fi
    else
        # Verify all backups
        for backup in "$BACKUP_DIR"/nixconf_backup_*.tar.gz; do
            if [[ -f "$backup" ]]; then
                local basename
                local checksum_file="${backup}.sha256"
                basename=$(basename "$backup" .tar.gz)
                
                if [[ -f "$checksum_file" ]]; then
                    if (cd "$BACKUP_DIR" && sha256sum -c "${basename}.tar.gz.sha256" >/dev/null 2>&1); then
                        log_success "Backup verified: $basename"
                        ((verified++))
                    else
                        log_error "Backup verification failed: $basename"
                        ((failed++))
                    fi
                else
                    log_warning "No checksum file for: $basename"
                    ((failed++))
                fi
            fi
        done
    fi
    
    log_info "Verification complete: $verified verified, $failed failed"
    return $failed
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping $MAX_LOCAL_BACKUPS)..."
    
    local count=0
    while IFS= read -r -d $'\0' backup; do
        ((count++))
        if [[ $count -gt $MAX_LOCAL_BACKUPS ]]; then
            local basename
            basename=$(basename "$backup" .tar.gz)
            log_info "Removing old backup: $basename"
            rm -f "$backup" "${backup}.sha256"
        fi
    done < <(find "$BACKUP_DIR" -name "nixconf_backup_*.tar.gz" -print0 | sort -z -r)
}

# Cloud storage functions

# Upload backup to cloud storage
upload_to_cloud() {
    local backup_file="$1"
    local checksum_file="$2"
    
    if [[ -z "$CLOUD_STORAGE" ]]; then
        return 0
    fi
    
    log_info "Uploading backup to cloud storage ($CLOUD_PROVIDER)..."
    
    case "$CLOUD_PROVIDER" in
        s3)
            upload_to_s3 "$backup_file" "$checksum_file"
            ;;
        gcs)
            upload_to_gcs "$backup_file" "$checksum_file"
            ;;
        azure)
            upload_to_azure "$backup_file" "$checksum_file"
            ;;
        *)
            log_error "Unsupported cloud provider: $CLOUD_PROVIDER"
            return 1
            ;;
    esac
}

# Upload to AWS S3
upload_to_s3() {
    local backup_file="$1"
    local checksum_file="$2"
    
    if [[ -z "$S3_BUCKET" ]]; then
        log_error "S3_BUCKET not specified for S3 upload"
        return 1
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install aws-cli package."
        return 1
    fi
    
    log_info "Uploading to S3 bucket: $S3_BUCKET"
    
    # Upload backup file
    if aws s3 cp "$backup_file" "s3://$S3_BUCKET/$(basename "$backup_file")"; then
        log_success "Backup uploaded to S3"
    else
        log_error "Failed to upload backup to S3"
        return 1
    fi
    
    # Upload checksum file
    if aws s3 cp "$checksum_file" "s3://$S3_BUCKET/$(basename "$checksum_file")"; then
        log_success "Checksum uploaded to S3"
    else
        log_error "Failed to upload checksum to S3"
        return 1
    fi
}

# Upload to Google Cloud Storage
upload_to_gcs() {
    local backup_file="$1"
    local checksum_file="$2"
    
    if [[ -z "$GCS_BUCKET" ]]; then
        log_error "GCS_BUCKET not specified for GCS upload"
        return 1
    fi
    
    if ! command -v gsutil >/dev/null 2>&1; then
        log_error "Google Cloud SDK not found. Please install google-cloud-sdk."
        return 1
    fi
    
    log_info "Uploading to GCS bucket: $GCS_BUCKET"
    
    # Upload backup file
    if gsutil cp "$backup_file" "gs://$GCS_BUCKET/$(basename "$backup_file")"; then
        log_success "Backup uploaded to GCS"
    else
        log_error "Failed to upload backup to GCS"
        return 1
    fi
    
    # Upload checksum file
    if gsutil cp "$checksum_file" "gs://$GCS_BUCKET/$(basename "$checksum_file")"; then
        log_success "Checksum uploaded to GCS"
    else
        log_error "Failed to upload checksum to GCS"
        return 1
    fi
}

# Upload to Azure Storage
upload_to_azure() {
    local backup_file="$1"
    local checksum_file="$2"
    
    if [[ -z "$AZURE_CONTAINER" ]]; then
        log_error "AZURE_CONTAINER not specified for Azure upload"
        return 1
    fi
    
    if ! command -v az >/dev/null 2>&1; then
        log_error "Azure CLI not found. Please install azure-cli package."
        return 1
    fi
    
    log_info "Uploading to Azure container: $AZURE_CONTAINER"
    
    # Upload backup file
    if az storage blob upload --file "$backup_file" --name "$(basename "$backup_file")" --container-name "$AZURE_CONTAINER"; then
        log_success "Backup uploaded to Azure"
    else
        log_error "Failed to upload backup to Azure"
        return 1
    fi
    
    # Upload checksum file
    if az storage blob upload --file "$checksum_file" --name "$(basename "$checksum_file")" --container-name "$AZURE_CONTAINER"; then
        log_success "Checksum uploaded to Azure"
    else
        log_error "Failed to upload checksum to Azure"
        return 1
    fi
}

# Download backup from cloud storage
download_from_cloud() {
    local backup_name="$1"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    local checksum_file="$BACKUP_DIR/${backup_name}.tar.gz.sha256"
    
    if [[ -z "$CLOUD_STORAGE" ]]; then
        return 0
    fi
    
    log_info "Downloading backup from cloud storage ($CLOUD_PROVIDER)..."
    
    case "$CLOUD_PROVIDER" in
        s3)
            download_from_s3 "$backup_name" "$backup_file" "$checksum_file"
            ;;
        gcs)
            download_from_gcs "$backup_name" "$backup_file" "$checksum_file"
            ;;
        azure)
            download_from_azure "$backup_name" "$backup_file" "$checksum_file"
            ;;
        *)
            log_error "Unsupported cloud provider: $CLOUD_PROVIDER"
            return 1
            ;;
    esac
}

# Download from AWS S3
download_from_s3() {
    local backup_name="$1"
    local backup_file="$2"
    local checksum_file="$3"
    
    if [[ -z "$S3_BUCKET" ]]; then
        log_error "S3_BUCKET not specified for S3 download"
        return 1
    fi
    
    # Download backup file
    if aws s3 cp "s3://$S3_BUCKET/$(basename "$backup_file")" "$backup_file"; then
        log_success "Backup downloaded from S3"
    else
        log_error "Failed to download backup from S3"
        return 1
    fi
    
    # Download checksum file
    if aws s3 cp "s3://$S3_BUCKET/$(basename "$checksum_file")" "$checksum_file"; then
        log_success "Checksum downloaded from S3"
    else
        log_error "Failed to download checksum from S3"
        return 1
    fi
}

# Download from Google Cloud Storage
download_from_gcs() {
    local backup_name="$1"
    local backup_file="$2"
    local checksum_file="$3"
    
    if [[ -z "$GCS_BUCKET" ]]; then
        log_error "GCS_BUCKET not specified for GCS download"
        return 1
    fi
    
    # Download backup file
    if gsutil cp "gs://$GCS_BUCKET/$(basename "$backup_file")" "$backup_file"; then
        log_success "Backup downloaded from GCS"
    else
        log_error "Failed to download backup from GCS"
        return 1
    fi
    
    # Download checksum file
    if gsutil cp "gs://$GCS_BUCKET/$(basename "$checksum_file")" "$checksum_file"; then
        log_success "Checksum downloaded from GCS"
    else
        log_error "Failed to download checksum from GCS"
        return 1
    fi
}

# Download from Azure Storage
download_from_azure() {
    local backup_name="$1"
    local backup_file="$2"
    local checksum_file="$3"
    
    if [[ -z "$AZURE_CONTAINER" ]]; then
        log_error "AZURE_CONTAINER not specified for Azure download"
        return 1
    fi
    
    # Download backup file
    if az storage blob download --name "$(basename "$backup_file")" --file "$backup_file" --container-name "$AZURE_CONTAINER"; then
        log_success "Backup downloaded from Azure"
    else
        log_error "Failed to download backup from Azure"
        return 1
    fi
    
    # Download checksum file
    if az storage blob download --name "$(basename "$checksum_file")" --file "$checksum_file" --container-name "$AZURE_CONTAINER"; then
        log_success "Checksum downloaded from Azure"
    else
        log_error "Failed to download checksum from Azure"
        return 1
    fi
}

# Main function
main() {
    local command=""
    local backup_name=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_BACKUP="$2"
                shift 2
                ;;
            -c|--cloud)
                CLOUD_STORAGE="true"
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --gcs-bucket)
                GCS_BUCKET="$2"
                shift 2
                ;;
            --azure-container)
                AZURE_CONTAINER="$2"
                shift 2
                ;;
            -n|--name)
                BACKUP_NAME="nixconf_backup_${2}_${TIMESTAMP}"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
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
            backup|restore|list|cleanup|verify|init)
                command="$1"
                shift
                ;;
            *)
                if [[ -z "$backup_name" && "$command" == "restore" ]]; then
                    backup_name="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    show_usage
                    exit 1
                fi
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
        init)
            init_backup_system
            ;;
        backup)
            create_backup
            ;;
        restore)
            if [[ -z "$backup_name" ]]; then
                log_error "Backup name required for restore"
                exit 1
            fi
            restore_backup "$backup_name"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        verify)
            verify_backup "$backup_name"
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
