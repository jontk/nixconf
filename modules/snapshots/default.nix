# Filesystem Snapshots Module
# Provides system state snapshots using BTRFS or ZFS

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.snapshots;
  isNixOS = pkgs.stdenv.isLinux;
in

{
  options.modules.snapshots = {
    enable = mkEnableOption "filesystem snapshots";
    
    filesystem = mkOption {
      type = types.enum [ "btrfs" "zfs" "auto" ];
      default = "auto";
      description = "Filesystem type for snapshots";
    };
    
    btrfs = {
      enable = mkEnableOption "BTRFS snapshots";
      
      subvolumes = mkOption {
        type = types.listOf types.str;
        default = [ "/" "/home" ];
        description = "Subvolumes to snapshot";
      };
      
      snapshotLocation = mkOption {
        type = types.str;
        default = "/.snapshots";
        description = "Location to store snapshots";
      };
      
      retentionPolicy = {
        hourly = mkOption {
          type = types.int;
          default = 24;
          description = "Number of hourly snapshots to keep";
        };
        
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily snapshots to keep";
        };
        
        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly snapshots to keep";
        };
        
        monthly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of monthly snapshots to keep";
        };
      };
    };
    
    zfs = {
      enable = mkEnableOption "ZFS snapshots";
      
      datasets = mkOption {
        type = types.listOf types.str;
        default = [ "rpool/ROOT" "rpool/home" ];
        description = "ZFS datasets to snapshot";
      };
      
      retentionPolicy = {
        frequent = mkOption {
          type = types.int;
          default = 4;
          description = "Number of frequent snapshots to keep (15min intervals)";
        };
        
        hourly = mkOption {
          type = types.int;
          default = 24;
          description = "Number of hourly snapshots to keep";
        };
        
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily snapshots to keep";
        };
        
        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly snapshots to keep";
        };
        
        monthly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of monthly snapshots to keep";
        };
      };
    };
    
    autoSnapshot = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic snapshots";
      };
      
      beforeSystemUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Create snapshot before system updates";
      };
    };
  };

  config = mkIf (cfg.enable && isNixOS) {
    # Auto-detect filesystem if set to auto
    modules.snapshots.filesystem = mkIf (cfg.filesystem == "auto") (
      if (config.fileSystems."/".fsType == "btrfs") then "btrfs"
      else if (config.fileSystems."/".fsType == "zfs") then "zfs"
      else "btrfs" # Default to btrfs
    );
    
    # Enable BTRFS snapshots
    modules.snapshots.btrfs.enable = mkIf (cfg.filesystem == "btrfs") true;
    
    # Enable ZFS snapshots
    modules.snapshots.zfs.enable = mkIf (cfg.filesystem == "zfs") true;
    
    # ZFS Configuration
    boot.supportedFilesystems = mkIf cfg.zfs.enable [ "zfs" ];
    services.zfs.autoScrub.enable = mkIf cfg.zfs.enable true;
    
    # ZFS snapshot configuration
    services.zfs.autoSnapshot = mkIf cfg.zfs.enable {
      enable = cfg.autoSnapshot.enable;
      frequent = cfg.zfs.retentionPolicy.frequent;
      hourly = cfg.zfs.retentionPolicy.hourly;
      daily = cfg.zfs.retentionPolicy.daily;
      weekly = cfg.zfs.retentionPolicy.weekly;
      monthly = cfg.zfs.retentionPolicy.monthly;
    };
    
    # Snapper configuration for BTRFS
    services.snapper = mkIf cfg.btrfs.enable {
      snapshotInterval = "hourly";
      cleanupInterval = "1d";
      
      configs = listToAttrs (map (subvol: {
        name = if subvol == "/" then "root" else (builtins.replaceStrings ["/"] [""] subvol);
        value = {
          SUBVOLUME = subvol;
          ALLOW_USERS = [ ];
          ALLOW_GROUPS = [ "wheel" ];
          SYNC_ACL = true;
          
          # Timeline cleanup
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = cfg.btrfs.retentionPolicy.hourly;
          TIMELINE_LIMIT_DAILY = cfg.btrfs.retentionPolicy.daily;
          TIMELINE_LIMIT_WEEKLY = cfg.btrfs.retentionPolicy.weekly;
          TIMELINE_LIMIT_MONTHLY = cfg.btrfs.retentionPolicy.monthly;
          
          # Number cleanup
          NUMBER_CLEANUP = true;
          NUMBER_MIN_AGE = 1800;
          NUMBER_LIMIT = 50;
          NUMBER_LIMIT_IMPORTANT = 10;
        };
      }) cfg.btrfs.subvolumes);
    };
    
    # Systemd services for snapshot management
    systemd.services.snapshot-before-rebuild = mkIf cfg.autoSnapshot.beforeSystemUpdate {
      description = "Create snapshot before system rebuild";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "snapshot-before-rebuild" ''
          set -euo pipefail
          
          ${if cfg.btrfs.enable then ''
            # Create BTRFS snapshot before rebuild
            for subvol in ${concatStringsSep " " cfg.btrfs.subvolumes}; do
              echo "Creating snapshot of $subvol before rebuild..."
              ${pkgs.snapper}/bin/snapper -c "''${subvol//\//_}" create \
                --description "Pre-rebuild snapshot $(date)" \
                --type pre \
                --print-number
            done
          '' else ""}
          
          ${if cfg.zfs.enable then ''
            # Create ZFS snapshot before rebuild
            for dataset in ${concatStringsSep " " cfg.zfs.datasets}; do
              echo "Creating snapshot of $dataset before rebuild..."
              ${pkgs.zfs}/bin/zfs snapshot "$dataset@pre-rebuild-$(date +%Y%m%d_%H%M%S)"
            done
          '' else ""}
        '';
      };
    };
    
    # System packages and helper scripts
    environment.systemPackages = with pkgs; lib.mkMerge [
      (mkIf cfg.btrfs.enable [
        btrfs-progs
        snapper
      ])
      (mkIf cfg.enable [
      (pkgs.writeShellScriptBin "nixconf-snapshot" ''
        #!/usr/bin/env bash
        # NixOS Configuration Snapshot Manager
        
        set -euo pipefail
        
        case "''${1:-help}" in
          create)
            echo "Creating manual snapshot..."
            ${if cfg.btrfs.enable then ''
              for subvol in ${concatStringsSep " " cfg.btrfs.subvolumes}; do
                ${pkgs.snapper}/bin/snapper -c "''${subvol//\//_}" create \
                  --description "Manual snapshot $(date)" \
                  --type single
              done
            '' else ""}
            ${if cfg.zfs.enable then ''
              for dataset in ${concatStringsSep " " cfg.zfs.datasets}; do
                ${pkgs.zfs}/bin/zfs snapshot "$dataset@manual-$(date +%Y%m%d_%H%M%S)"
              done
            '' else ""}
            ;;
          list)
            echo "Available snapshots:"
            ${if cfg.btrfs.enable then ''
              for subvol in ${concatStringsSep " " cfg.btrfs.subvolumes}; do
                echo "=== $subvol ==="
                ${pkgs.snapper}/bin/snapper -c "''${subvol//\//_}" list
              done
            '' else ""}
            ${if cfg.zfs.enable then ''
              for dataset in ${concatStringsSep " " cfg.zfs.datasets}; do
                echo "=== $dataset ==="
                ${pkgs.zfs}/bin/zfs list -t snapshot | grep "$dataset@"
              done
            '' else ""}
            ;;
          restore)
            if [[ -z "''${2:-}" ]]; then
              echo "Usage: nixconf-snapshot restore <snapshot-id>"
              exit 1
            fi
            echo "Restoring from snapshot: $2"
            ${if cfg.btrfs.enable then ''
              # BTRFS restore would be implemented here
              echo "BTRFS restore functionality not yet implemented"
              echo "Use: snapper -c <config> undochange <pre>..<post>"
            '' else ""}
            ${if cfg.zfs.enable then ''
              # ZFS restore would be implemented here
              echo "ZFS restore functionality not yet implemented"
              echo "Use: zfs rollback <dataset@snapshot>"
            '' else ""}
            ;;
          cleanup)
            echo "Cleaning up old snapshots..."
            ${if cfg.btrfs.enable then ''
              for subvol in ${concatStringsSep " " cfg.btrfs.subvolumes}; do
                ${pkgs.snapper}/bin/snapper -c "''${subvol//\//_}" cleanup timeline
              done
            '' else ""}
            ${if cfg.zfs.enable then ''
              # ZFS cleanup is handled automatically by autoSnapshot service
              echo "ZFS cleanup is handled automatically"
            '' else ""}
            ;;
          *)
            echo "NixOS Configuration Snapshot Manager"
            echo "Usage: nixconf-snapshot {create|list|restore|cleanup}"
            echo ""
            echo "Commands:"
            echo "  create   - Create manual snapshot"
            echo "  list     - List available snapshots"
            echo "  restore  - Restore from snapshot"
            echo "  cleanup  - Clean up old snapshots"
            ;;
        esac
      '')
      ])
    ];
    
    # Automatic cleanup timers
    systemd.timers.snapshot-cleanup = mkIf cfg.autoSnapshot.enable {
      description = "Cleanup old snapshots";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    systemd.services.snapshot-cleanup = mkIf cfg.autoSnapshot.enable {
      description = "Cleanup old snapshots";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash -c 'nixconf-snapshot cleanup'";
      };
    };
  };
}