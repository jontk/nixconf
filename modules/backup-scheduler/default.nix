# Backup Scheduler Module
# Provides automated backup scheduling with systemd timers

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.backup-scheduler;
  isNixOS = pkgs.stdenv.isLinux;
  
  # Script paths
  backupScript = "${pkgs.bash}/bin/bash ${../../../scripts/backup.sh}";
  testScript = "${pkgs.bash}/bin/bash ${../../../scripts/backup-test.sh}";
  recoveryScript = "${pkgs.bash}/bin/bash ${../../../scripts/recovery.sh}";
in

{
  options.modules.backup-scheduler = {
    enable = mkEnableOption "automated backup scheduling";
    
    backup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated backups";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "Backup schedule (systemd calendar format)";
      };
      
      retention = mkOption {
        type = types.int;
        default = 7;
        description = "Number of local backups to retain";
      };
      
      remote = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable remote backup sync";
        };
        
        destination = mkOption {
          type = types.str;
          default = "";
          description = "Remote backup destination (rsync compatible)";
        };
      };
      
      cloud = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable cloud storage backup";
        };
        
        provider = mkOption {
          type = types.enum [ "s3" "gcs" "azure" ];
          default = "s3";
          description = "Cloud storage provider";
        };
        
        bucket = mkOption {
          type = types.str;
          default = "";
          description = "Cloud storage bucket/container name";
        };
      };
    };
    
    testing = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated backup testing";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "Test schedule (systemd calendar format)";
      };
      
      verifyAll = mkOption {
        type = types.bool;
        default = false;
        description = "Verify all backups during testing (vs. latest only)";
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable backup monitoring and alerting";
      };
      
      healthchecks = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Send status to healthchecks.io";
        };
        
        url = mkOption {
          type = types.str;
          default = "";
          description = "Healthchecks.io ping URL";
        };
      };
      
      email = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Send email notifications";
        };
        
        to = mkOption {
          type = types.str;
          default = "";
          description = "Email address for notifications";
        };
        
        onFailure = mkOption {
          type = types.bool;
          default = true;
          description = "Send email on backup failure";
        };
        
        onSuccess = mkOption {
          type = types.bool;
          default = false;
          description = "Send email on backup success";
        };
      };
    };
    
    snapshots = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable pre-backup snapshots";
      };
      
      beforeBackup = mkOption {
        type = types.bool;
        default = true;
        description = "Create snapshot before backup";
      };
      
      beforeUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Create snapshot before system update";
      };
    };
  };

  config = mkIf (cfg.enable && isNixOS) {
    # Install backup scripts
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nixconf-backup" ''
        exec ${backupScript} "$@"
      '')
      (pkgs.writeShellScriptBin "nixconf-backup-test" ''
        exec ${testScript} "$@"
      '')
      (pkgs.writeShellScriptBin "nixconf-recovery" ''
        exec ${recoveryScript} "$@"
      '')
    ];
    
    # Main backup service
    systemd.services.nixconf-backup = mkIf cfg.backup.enable {
      description = "NixOS Configuration Backup";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStartPre = mkIf cfg.snapshots.beforeBackup "${pkgs.bash}/bin/bash -c 'nixconf-snapshot create || true'";
        ExecStart = pkgs.writeShellScript "nixconf-backup-service" ''
          set -euo pipefail
          
          # Build backup command
          cmd="${backupScript} backup"
          
          # Add remote destination
          ${optionalString cfg.backup.remote.enable ''
            cmd="$cmd --remote '${cfg.backup.remote.destination}'"
          ''}
          
          # Add cloud storage
          ${optionalString cfg.backup.cloud.enable ''
            cmd="$cmd --cloud '${cfg.backup.cloud.provider}'"
            case "${cfg.backup.cloud.provider}" in
              s3)
                cmd="$cmd --s3-bucket '${cfg.backup.cloud.bucket}'"
                ;;
              gcs)
                cmd="$cmd --gcs-bucket '${cfg.backup.cloud.bucket}'"
                ;;
              azure)
                cmd="$cmd --azure-container '${cfg.backup.cloud.bucket}'"
                ;;
            esac
          ''}
          
          # Execute backup
          eval "$cmd"
          
          # Health check ping
          ${optionalString cfg.monitoring.healthchecks.enable ''
            ${pkgs.curl}/bin/curl -fsS --retry 3 "${cfg.monitoring.healthchecks.url}" || true
          ''}
        '';
        StandardOutput = "journal";
        StandardError = "journal";
        
        # Environment variables for cloud providers
        Environment = mkMerge [
          (mkIf cfg.backup.cloud.enable [
            "CLOUD_STORAGE=true"
            "CLOUD_PROVIDER=${cfg.backup.cloud.provider}"
          ])
          (mkIf (cfg.backup.cloud.enable && cfg.backup.cloud.provider == "s3") [
            "S3_BUCKET=${cfg.backup.cloud.bucket}"
          ])
          (mkIf (cfg.backup.cloud.enable && cfg.backup.cloud.provider == "gcs") [
            "GCS_BUCKET=${cfg.backup.cloud.bucket}"
          ])
          (mkIf (cfg.backup.cloud.enable && cfg.backup.cloud.provider == "azure") [
            "AZURE_CONTAINER=${cfg.backup.cloud.bucket}"
          ])
          [
            "MAX_LOCAL_BACKUPS=${toString cfg.backup.retention}"
          ]
        ];
      };
      
      # Email notifications
      onFailure = mkIf cfg.monitoring.email.enable [ "nixconf-backup-failure.service" ];
      onSuccess = mkIf (cfg.monitoring.email.enable && cfg.monitoring.email.onSuccess) [ "nixconf-backup-success.service" ];
    };
    
    # Backup timer
    systemd.timers.nixconf-backup = mkIf cfg.backup.enable {
      description = "NixOS Configuration Backup Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
    
    # Backup testing service
    systemd.services.nixconf-backup-test = mkIf cfg.testing.enable {
      description = "NixOS Configuration Backup Test";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "nixconf-backup-test-service" ''
          set -euo pipefail
          
          # Run backup verification and testing
          ${testScript} test-complete
          
          # Health check ping for testing
          ${optionalString cfg.monitoring.healthchecks.enable ''
            ${pkgs.curl}/bin/curl -fsS --retry 3 "${cfg.monitoring.healthchecks.url}/test" || true
          ''}
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Backup testing timer
    systemd.timers.nixconf-backup-test = mkIf cfg.testing.enable {
      description = "NixOS Configuration Backup Test Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.testing.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    # Email notification services
    systemd.services.nixconf-backup-failure = mkIf cfg.monitoring.email.enable {
      description = "NixOS Configuration Backup Failure Notification";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-failure-notify" ''
          ${pkgs.mailutils}/bin/mail -s "NixOS Backup Failed - $(hostname)" "${cfg.monitoring.email.to}" << EOF
          NixOS Configuration backup failed on $(hostname) at $(date).
          
          Please check the system logs for details:
          journalctl -u nixconf-backup.service -n 50
          
          You can also check the backup status with:
          nixconf-backup list
          nixconf-backup verify
          
          Consider running a manual backup:
          nixconf-backup backup
          EOF
        '';
      };
    };
    
    systemd.services.nixconf-backup-success = mkIf (cfg.monitoring.email.enable && cfg.monitoring.email.onSuccess) {
      description = "NixOS Configuration Backup Success Notification";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-success-notify" ''
          ${pkgs.mailutils}/bin/mail -s "NixOS Backup Successful - $(hostname)" "${cfg.monitoring.email.to}" << EOF
          NixOS Configuration backup completed successfully on $(hostname) at $(date).
          
          Latest backups:
          $(nixconf-backup list | tail -5)
          EOF
        '';
      };
    };
    
    # Pre-update snapshot service
    systemd.services.nixconf-pre-update-snapshot = mkIf cfg.snapshots.beforeUpdate {
      description = "Create snapshot before system update";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash -c 'nixconf-snapshot create || true'";
      };
    };
    
    # Backup cleanup service
    systemd.services.nixconf-backup-cleanup = {
      description = "NixOS Configuration Backup Cleanup";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${backupScript} cleanup";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Backup cleanup timer (monthly)
    systemd.timers.nixconf-backup-cleanup = {
      description = "NixOS Configuration Backup Cleanup Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };
    
    # Status monitoring service
    systemd.services.nixconf-backup-status = mkIf cfg.monitoring.enable {
      description = "NixOS Configuration Backup Status Monitor";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "backup-status-monitor" ''
          set -euo pipefail
          
          # Check backup age
          latest_backup=$(find /home/*/.local/share/nixconf-backups -name "nixconf_backup_*.tar.gz" -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2 || echo "")
          
          if [[ -n "$latest_backup" ]]; then
            backup_age=$(($(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || echo 0)))
            max_age=$((2 * 24 * 3600))  # 2 days
            
            if [[ $backup_age -gt $max_age ]]; then
              echo "WARNING: Latest backup is $(($backup_age / 3600)) hours old"
              ${optionalString cfg.monitoring.email.enable ''
                ${pkgs.mailutils}/bin/mail -s "NixOS Backup Warning - $(hostname)" "${cfg.monitoring.email.to}" << EOF
                The latest NixOS configuration backup is $(($backup_age / 3600)) hours old.
                
                This exceeds the maximum recommended age of 48 hours.
                Please check the backup system:
                
                systemctl status nixconf-backup.timer
                journalctl -u nixconf-backup.service
                EOF
              ''}
            else
              echo "OK: Latest backup is $(($backup_age / 3600)) hours old"
            fi
          else
            echo "ERROR: No backups found"
            ${optionalString cfg.monitoring.email.enable ''
              ${pkgs.mailutils}/bin/mail -s "NixOS Backup Error - $(hostname)" "${cfg.monitoring.email.to}" << EOF
              No NixOS configuration backups found on $(hostname).
              
              The backup system may not be working correctly.
              Please check:
              
              systemctl status nixconf-backup.timer
              systemctl status nixconf-backup.service
              nixconf-backup list
              EOF
            ''}
          fi
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Status monitoring timer (daily)
    systemd.timers.nixconf-backup-status = mkIf cfg.monitoring.enable {
      description = "NixOS Configuration Backup Status Monitor Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };
    
    # Enable snapshots module if needed
    modules.snapshots.enable = mkIf cfg.snapshots.enable true;
    
    # Mail configuration for notifications
    programs.msmtp = mkIf cfg.monitoring.email.enable {
      enable = true;
      setSendmail = true;
      defaults = {
        aliases = "/etc/aliases";
        port = 587;
        tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
        tls = "on";
        auth = "login";
        tls_starttls = "on";
      };
      accounts = {
        default = {
          host = "smtp.gmail.com";  # Default to Gmail, should be configured per system
          passwordeval = "echo 'your-app-password'";  # Should be configured with secrets management
          user = cfg.monitoring.email.to;
          from = cfg.monitoring.email.to;
        };
      };
    };
    
    # Ensure required packages are available
    environment.systemPackages = mkIf cfg.monitoring.email.enable (with pkgs; [
      mailutils
      msmtp
    ]);
  };
}