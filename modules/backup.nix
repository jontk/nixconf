# Comprehensive Backup Module
# Provides automated backup strategies with multiple tools and destinations

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.backup;
  isNixOS = pkgs.stdenv.isLinux;
  
  # Backup tools
  backupTools = with pkgs; [
    rsync
    borgbackup
    restic
    rclone
    duplicity
    awscli2
    google-cloud-sdk
    azure-cli
  ];
  
  # Database backup scripts
  postgresBackupScript = pkgs.writeShellScript "postgres-backup" ''
    set -euo pipefail
    
    BACKUP_DIR="$1"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    
    echo "Starting PostgreSQL backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR/postgresql"
    
    # Global backup (users, roles, etc.)
    sudo -u postgres pg_dumpall --globals-only > "$BACKUP_DIR/postgresql/globals_$TIMESTAMP.sql"
    
    # Individual database backups
    for db in $(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname != 'postgres';"); do
        db=$(echo $db | xargs)  # trim whitespace
        if [[ -n "$db" ]]; then
            echo "Backing up database: $db"
            sudo -u postgres pg_dump -Fc "$db" > "$BACKUP_DIR/postgresql/${db}_$TIMESTAMP.dump"
        fi
    done
    
    # Create checksums
    cd "$BACKUP_DIR/postgresql"
    sha256sum *.sql *.dump > "checksums_$TIMESTAMP.sha256" 2>/dev/null || true
    
    echo "PostgreSQL backup completed"
  '';
  
  redisBackupScript = pkgs.writeShellScript "redis-backup" ''
    set -euo pipefail
    
    BACKUP_DIR="$1"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    
    echo "Starting Redis backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR/redis"
    
    # Save current state
    redis-cli BGSAVE
    
    # Wait for background save to complete
    while [ "$(redis-cli LASTSAVE)" = "$(redis-cli LASTSAVE)" ]; do
        sleep 1
    done
    
    # Copy RDB file
    if [[ -f /var/lib/redis/dump.rdb ]]; then
        cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis/dump_$TIMESTAMP.rdb"
        sha256sum "$BACKUP_DIR/redis/dump_$TIMESTAMP.rdb" > "$BACKUP_DIR/redis/dump_$TIMESTAMP.rdb.sha256"
    fi
    
    echo "Redis backup completed"
  '';
  
  systemBackupScript = pkgs.writeShellScript "system-backup" ''
    set -euo pipefail
    
    BACKUP_DIR="$1"
    STRATEGY="$2"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    
    echo "Starting system backup with strategy: $strategy"
    
    case "$STRATEGY" in
        "rsync")
            mkdir -p "$BACKUP_DIR/system-rsync"
            rsync -av --exclude='/dev' --exclude='/proc' --exclude='/sys' \
                  --exclude='/tmp' --exclude='/run' --exclude='/mnt' \
                  --exclude='/media' --exclude='/lost+found' \
                  / "$BACKUP_DIR/system-rsync/root_$TIMESTAMP/"
            ;;
        "borg")
            export BORG_REPO="$BACKUP_DIR/system-borg"
            mkdir -p "$BORG_REPO"
            
            # Initialize repo if it doesn't exist
            if [[ ! -f "$BORG_REPO/config" ]]; then
                borg init --encryption=repokey-blake2 "$BORG_REPO"
            fi
            
            # Create backup
            borg create --verbose --filter AME --list --stats --show-rc \
                 --compression lz4 --exclude-caches \
                 --exclude '/dev' --exclude '/proc' --exclude '/sys' \
                 --exclude '/tmp' --exclude '/run' --exclude '/mnt' \
                 --exclude '/media' --exclude '/lost+found' \
                 --exclude '/var/cache' --exclude '/var/tmp' \
                 "$BORG_REPO::system-{now}" /
            
            # Prune old backups
            borg prune --list --prefix system- --show-rc \
                 --keep-daily 7 --keep-weekly 4 --keep-monthly 12 \
                 "$BORG_REPO"
            ;;
        "restic")
            export RESTIC_REPOSITORY="$BACKUP_DIR/system-restic"
            export RESTIC_PASSWORD="$(openssl rand -base64 32)"
            
            mkdir -p "$RESTIC_REPOSITORY"
            
            # Initialize repo if it doesn't exist
            if [[ ! -f "$RESTIC_REPOSITORY/config" ]]; then
                restic init
                echo "$RESTIC_PASSWORD" > "$BACKUP_DIR/.restic-password"
                chmod 600 "$BACKUP_DIR/.restic-password"
            else
                export RESTIC_PASSWORD="$(cat "$BACKUP_DIR/.restic-password")"
            fi
            
            # Create backup
            restic backup --verbose / \
                   --exclude='/dev' --exclude='/proc' --exclude='/sys' \
                   --exclude='/tmp' --exclude='/run' --exclude='/mnt' \
                   --exclude='/media' --exclude='/lost+found' \
                   --exclude='/var/cache' --exclude='/var/tmp' \
                   --tag system
            
            # Forget old snapshots
            restic forget --verbose --tag system \
                   --keep-daily 7 --keep-weekly 4 --keep-monthly 12 \
                   --prune
            ;;
        *)
            echo "Unknown backup strategy: $STRATEGY"
            exit 1
            ;;
    esac
    
    echo "System backup completed with strategy: $STRATEGY"
  '';
  
  cloudSyncScript = pkgs.writeShellScript "cloud-sync" ''
    set -euo pipefail
    
    SOURCE_DIR="$1"
    CLOUD_PROVIDER="$2"
    DESTINATION="$3"
    
    echo "Syncing to cloud: $CLOUD_PROVIDER"
    
    case "$CLOUD_PROVIDER" in
        "s3")
            aws s3 sync "$SOURCE_DIR" "s3://$DESTINATION" --delete
            ;;
        "gcs")
            gsutil -m rsync -r -d "$SOURCE_DIR" "gs://$DESTINATION"
            ;;
        "azure")
            az storage blob sync --source "$SOURCE_DIR" --container "$DESTINATION"
            ;;
        "rclone")
            rclone sync "$SOURCE_DIR" "$DESTINATION" --progress
            ;;
        *)
            echo "Unknown cloud provider: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
    
    echo "Cloud sync completed"
  '';
  
in

{
  options.modules.backup = {
    enable = mkEnableOption "comprehensive backup system";
    
    strategies = {
      rsync = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable rsync-based backups";
        };
        
        destinations = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Rsync destinations (local paths or remote)";
        };
      };
      
      borg = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable BorgBackup (deduplicating backups)";
        };
        
        repositories = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Borg repository paths";
        };
        
        encryption = mkOption {
          type = types.str;
          default = "repokey-blake2";
          description = "Borg encryption mode";
        };
      };
      
      restic = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Restic backups";
        };
        
        repositories = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Restic repository paths";
        };
      };
    };
    
    database = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable database backups";
      };
      
      postgresql = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable PostgreSQL backups";
        };
      };
      
      redis = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Redis backups";
        };
      };
      
      mongodb = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable MongoDB backups";
        };
      };
    };
    
    cloud = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable cloud storage backups";
      };
      
      provider = mkOption {
        type = types.enum [ "s3" "gcs" "azure" "rclone" ];
        default = "s3";
        description = "Cloud storage provider";
      };
      
      destination = mkOption {
        type = types.str;
        default = "";
        description = "Cloud storage destination (bucket/container)";
      };
      
      sync = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically sync backups to cloud";
      };
    };
    
    schedule = {
      system = mkOption {
        type = types.str;
        default = "daily";
        description = "System backup schedule (systemd calendar format)";
      };
      
      database = mkOption {
        type = types.str;
        default = "*-*-* 02:00:00";
        description = "Database backup schedule (systemd calendar format)";
      };
      
      cloud = mkOption {
        type = types.str;
        default = "*-*-* 04:00:00";
        description = "Cloud sync schedule (systemd calendar format)";
      };
    };
    
    retention = {
      local = {
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily backups to keep locally";
        };
        
        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly backups to keep locally";
        };
        
        monthly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of monthly backups to keep locally";
        };
      };
      
      cloud = {
        daily = mkOption {
          type = types.int;
          default = 30;
          description = "Number of daily backups to keep in cloud";
        };
        
        weekly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of weekly backups to keep in cloud";
        };
        
        monthly = mkOption {
          type = types.int;
          default = 36;
          description = "Number of monthly backups to keep in cloud";
        };
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable backup monitoring and alerts";
      };
      
      prometheus = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Export backup metrics to Prometheus";
        };
        
        port = mkOption {
          type = types.int;
          default = 9999;
          description = "Prometheus metrics port";
        };
      };
      
      notifications = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable backup notifications";
        };
        
        onFailure = mkOption {
          type = types.bool;
          default = true;
          description = "Notify on backup failures";
        };
        
        onSuccess = mkOption {
          type = types.bool;
          default = false;
          description = "Notify on backup success";
        };
      };
    };
    
    paths = {
      backup = mkOption {
        type = types.str;
        default = "/var/lib/backups";
        description = "Main backup directory";
      };
      
      include = mkOption {
        type = types.listOf types.str;
        default = [
          "/etc"
          "/home"
          "/var/lib"
          "/root"
        ];
        description = "Paths to include in backups";
      };
      
      exclude = mkOption {
        type = types.listOf types.str;
        default = [
          "/dev"
          "/proc"
          "/sys"
          "/tmp"
          "/run"
          "/mnt"
          "/media"
          "/lost+found"
          "/var/cache"
          "/var/tmp"
          "/var/log"
        ];
        description = "Paths to exclude from backups";
      };
    };
  };

  config = mkIf (cfg.enable && isNixOS) {
    # Install backup tools
    environment.systemPackages = backupTools ++ [
      (pkgs.writeShellScriptBin "backup-system" ''
        exec ${systemBackupScript} "$@"
      '')
      (pkgs.writeShellScriptBin "backup-databases" ''
        set -euo pipefail
        BACKUP_DIR="$1"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        
        echo "Starting database backups..."
        mkdir -p "$BACKUP_DIR/databases"
        
        ${optionalString cfg.database.postgresql.enable ''
          if systemctl is-active postgresql.service >/dev/null 2>&1; then
            ${postgresBackupScript} "$BACKUP_DIR/databases"
          fi
        ''}
        
        ${optionalString cfg.database.redis.enable ''
          if systemctl is-active redis.service >/dev/null 2>&1; then
            ${redisBackupScript} "$BACKUP_DIR/databases"
          fi
        ''}
        
        echo "Database backups completed"
      '')
      (pkgs.writeShellScriptBin "backup-cloud-sync" ''
        exec ${cloudSyncScript} "$@"
      '')
    ];
    
    # Create backup directory
    systemd.tmpfiles.rules = [
      "d ${cfg.paths.backup} 0750 root root -"
      "d ${cfg.paths.backup}/system 0750 root root -"
      "d ${cfg.paths.backup}/databases 0750 root root -"
      "d ${cfg.paths.backup}/cloud 0750 root root -"
    ] ++ (mkIf cfg.monitoring.prometheus.enable [
      "d /var/lib/node_exporter/textfile_collector 0755 root root -"
    ]);
    
    # System backup service
    systemd.services.backup-system = {
      description = "System Backup Service";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-system-service" ''
          set -euo pipefail
          
          BACKUP_DIR="${cfg.paths.backup}/system"
          TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
          
          echo "Starting system backup at $(date)"
          
          # Create timestamped backup directory
          mkdir -p "$BACKUP_DIR/$TIMESTAMP"
          
          ${optionalString cfg.strategies.rsync.enable ''
            echo "Running rsync backup..."
            backup-system "$BACKUP_DIR/$TIMESTAMP" rsync
          ''}
          
          ${optionalString cfg.strategies.borg.enable ''
            echo "Running Borg backup..."
            backup-system "$BACKUP_DIR/$TIMESTAMP" borg
          ''}
          
          ${optionalString cfg.strategies.restic.enable ''
            echo "Running Restic backup..."
            backup-system "$BACKUP_DIR/$TIMESTAMP" restic
          ''}
          
          echo "System backup completed at $(date)"
          
          # Update metrics
          echo "backup_system_last_success $(date +%s)" > /var/lib/node_exporter/textfile_collector/backup_system.prom
        '';
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutSec = "4h";
      };
      onFailure = [ "backup-failure-notification.service" ];
    };
    
    # Database backup service
    systemd.services.backup-databases = mkIf cfg.database.enable {
      description = "Database Backup Service";
      after = [ "network.target" "postgresql.service" "redis.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-databases-service" ''
          set -euo pipefail
          
          BACKUP_DIR="${cfg.paths.backup}/databases"
          TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
          
          echo "Starting database backup at $(date)"
          
          # Create timestamped backup directory
          mkdir -p "$BACKUP_DIR/$TIMESTAMP"
          
          # Run database backups
          backup-databases "$BACKUP_DIR/$TIMESTAMP"
          
          echo "Database backup completed at $(date)"
          
          # Update metrics
          echo "backup_databases_last_success $(date +%s)" > /var/lib/node_exporter/textfile_collector/backup_databases.prom
        '';
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutSec = "2h";
      };
      onFailure = [ "backup-failure-notification.service" ];
    };
    
    # Cloud sync service
    systemd.services.backup-cloud-sync = mkIf cfg.cloud.enable {
      description = "Cloud Backup Sync Service";
      after = [ "network.target" "backup-system.service" "backup-databases.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-cloud-sync-service" ''
          set -euo pipefail
          
          echo "Starting cloud sync at $(date)"
          
          # Sync system backups
          backup-cloud-sync "${cfg.paths.backup}/system" "${cfg.cloud.provider}" "${cfg.cloud.destination}/system"
          
          ${optionalString cfg.database.enable ''
            # Sync database backups
            backup-cloud-sync "${cfg.paths.backup}/databases" "${cfg.cloud.provider}" "${cfg.cloud.destination}/databases"
          ''}
          
          echo "Cloud sync completed at $(date)"
          
          # Update metrics
          echo "backup_cloud_sync_last_success $(date +%s)" > /var/lib/node_exporter/textfile_collector/backup_cloud.prom
        '';
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutSec = "2h";
      };
      onFailure = [ "backup-failure-notification.service" ];
    };
    
    # Backup cleanup service
    systemd.services.backup-cleanup = {
      description = "Backup Cleanup Service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-cleanup-service" ''
          set -euo pipefail
          
          echo "Starting backup cleanup at $(date)"
          
          # Clean up old system backups
          find "${cfg.paths.backup}/system" -type d -name "20*" -mtime +${toString cfg.retention.local.daily} -exec rm -rf {} + || true
          
          # Clean up old database backups
          find "${cfg.paths.backup}/databases" -type d -name "20*" -mtime +${toString cfg.retention.local.daily} -exec rm -rf {} + || true
          
          echo "Backup cleanup completed at $(date)"
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Backup verification service
    systemd.services.backup-verify = {
      description = "Backup Verification Service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-verify-service" ''
          set -euo pipefail
          
          echo "Starting backup verification at $(date)"
          
          VERIFIED=0
          FAILED=0
          
          # Verify latest backups
          for backup_dir in "${cfg.paths.backup}"/*/; do
            if [[ -d "$backup_dir" ]]; then
              latest=$(ls -1t "$backup_dir" | head -1)
              if [[ -n "$latest" && -d "$backup_dir/$latest" ]]; then
                if [[ -f "$backup_dir/$latest/metadata.json" ]]; then
                  echo "Verified: $backup_dir/$latest"
                  ((VERIFIED++))
                else
                  echo "Failed: $backup_dir/$latest (missing metadata)"
                  ((FAILED++))
                fi
              fi
            fi
          done
          
          echo "Backup verification completed: $VERIFIED verified, $FAILED failed"
          
          # Update metrics
          echo "backup_verification_verified $VERIFIED" > /var/lib/node_exporter/textfile_collector/backup_verification.prom
          echo "backup_verification_failed $FAILED" >> /var/lib/node_exporter/textfile_collector/backup_verification.prom
          echo "backup_verification_last_run $(date +%s)" >> /var/lib/node_exporter/textfile_collector/backup_verification.prom
          
          if [[ $FAILED -gt 0 ]]; then
            exit 1
          fi
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
      onFailure = [ "backup-failure-notification.service" ];
    };
    
    # Backup failure notification service
    systemd.services.backup-failure-notification = mkIf cfg.monitoring.notifications.enable {
      description = "Backup Failure Notification";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-failure-notification" ''
          set -euo pipefail
          
          # Get the failed service name from environment
          FAILED_SERVICE="''${FAILED_UNIT:-unknown}"
          
          echo "Backup failure detected for service: $FAILED_SERVICE"
          
          # Log to journald
          echo "BACKUP_FAILURE: $FAILED_SERVICE failed at $(date)" | systemd-cat -t backup-monitor
          
          # Send alert to monitoring system (if Prometheus is enabled)
          ${optionalString cfg.monitoring.prometheus.enable ''
            echo "backup_failure{service=\"$FAILED_SERVICE\"} 1" > /var/lib/node_exporter/textfile_collector/backup_failure.prom
          ''}
          
          # TODO: Add email/webhook notifications here
          echo "Backup failure notification sent for: $FAILED_SERVICE"
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Systemd timers
    systemd.timers = {
      backup-system = {
        description = "System Backup Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.schedule.system;
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
      
      backup-databases = mkIf cfg.database.enable {
        description = "Database Backup Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.schedule.database;
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
      
      backup-cloud-sync = mkIf cfg.cloud.enable {
        description = "Cloud Backup Sync Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.schedule.cloud;
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
      };
      
      backup-cleanup = {
        description = "Backup Cleanup Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "2h";
        };
      };
      
      backup-verify = {
        description = "Backup Verification Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
    
    # Prometheus monitoring integration
    services.prometheus.exporters.node = mkIf cfg.monitoring.prometheus.enable {
      enabledCollectors = [ "textfile" ];
      extraFlags = [
        "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector"
      ];
    };
    
    
    # Enable backup-scheduler module for additional features
    modules.backup-scheduler = {
      enable = mkDefault true;
    } // (mkIf config.modules.secrets.enable {
      monitoring.email = {
        enable = true;
        to = "admin@localhost";  # Should be configured with actual email
      };
    });
  };
}