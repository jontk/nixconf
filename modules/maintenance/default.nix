{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.maintenance;
in
{
  options.modules.maintenance = {
    enable = mkEnableOption "configuration maintenance and updates system";
    
    # Update system configuration
    updates = {
      enable = mkEnableOption "automated dependency updates";
      
      strategy = mkOption {
        type = types.enum [ "conservative" "balanced" "aggressive" ];
        default = "balanced";
        description = ''
          Update strategy:
          - conservative: Only security fixes and critical patches
          - balanced: Stable releases and security fixes
          - aggressive: Latest available versions
        '';
      };
      
      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "Update schedule (systemd timer format)";
      };
      
      autoApply = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically apply updates without confirmation";
      };
      
      securityUpdates = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic security updates";
      };
      
      flakeUpdates = mkOption {
        type = types.bool;
        default = true;
        description = "Enable flake input updates";
      };
      
      testBeforeApply = mkOption {
        type = types.bool;
        default = true;
        description = "Test updates before applying";
      };
      
      rollbackOnFailure = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically rollback failed updates";
      };
      
      notificationEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email address for update notifications";
      };
    };
    
    # Health monitoring configuration
    monitoring = {
      enable = mkEnableOption "configuration health monitoring";
      
      interval = mkOption {
        type = types.int;
        default = 300;
        description = "Health check interval in seconds";
      };
      
      baseline = {
        autoCreate = mkOption {
          type = types.bool;
          default = true;
          description = "Automatically create configuration baselines";
        };
        
        schedule = mkOption {
          type = types.str;
          default = "daily";
          description = "Baseline creation schedule";
        };
        
        retention = mkOption {
          type = types.int;
          default = 30;
          description = "Number of baselines to retain";
        };
      };
      
      driftDetection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable configuration drift detection";
      };
      
      complianceChecks = mkOption {
        type = types.bool;
        default = true;
        description = "Enable compliance checking";
      };
      
      autoFix = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically fix detected issues";
      };
      
      alertEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email address for health alerts";
      };
    };
    
    # Vulnerability scanning
    security = {
      enable = mkEnableOption "security vulnerability scanning";
      
      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "Security scan schedule";
      };
      
      tools = mkOption {
        type = types.listOf types.str;
        default = [ "vulnix" ];
        description = "Security scanning tools to use";
      };
      
      autoUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically apply security updates";
      };
    };
    
    # Maintenance tasks
    tasks = {
      enable = mkEnableOption "automated maintenance tasks";
      
      cleanup = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable system cleanup tasks";
        };
        
        schedule = mkOption {
          type = types.str;
          default = "daily";
          description = "Cleanup schedule";
        };
        
        nixStore = mkOption {
          type = types.bool;
          default = true;
          description = "Clean Nix store";
        };
        
        logs = mkOption {
          type = types.bool;
          default = true;
          description = "Clean old logs";
        };
        
        retention = mkOption {
          type = types.str;
          default = "30d";
          description = "Log retention period";
        };
      };
      
      optimization = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable system optimization tasks";
        };
        
        schedule = mkOption {
          type = types.str;
          default = "weekly";
          description = "Optimization schedule";
        };
        
        nixStoreOptimize = mkOption {
          type = types.bool;
          default = true;
          description = "Optimize Nix store";
        };
      };
    };
    
    # Reporting
    reporting = {
      enable = mkEnableOption "maintenance reporting";
      
      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "Report generation schedule";
      };
      
      email = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email address for reports";
      };
      
      format = mkOption {
        type = types.enum [ "text" "json" "html" ];
        default = "text";
        description = "Report format";
      };
    };
  };

  config = mkIf cfg.enable {
    # Install maintenance tools
    environment.systemPackages = with pkgs; [
      # Dependency management
      nix-update
      nvd  # Nix version diff
      
      # Security scanning
      vulnix
      
      # System utilities
      jq
      bc
      mailutils  # For email notifications
    ];

    # Dependency update service
    systemd.services.dependency-update = mkIf cfg.updates.enable {
      description = "Automated Dependency Updates";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = [
          "UPDATE_STRATEGY=${cfg.updates.strategy}"
          "UPDATE_REPORT_EMAIL=${toString cfg.updates.notificationEmail}"
        ];
      };
      script = ''
        ${pkgs.bash}/bin/bash /etc/nixos/scripts/dependency-update.sh update \
          --strategy ${cfg.updates.strategy} \
          ${optionalString (!cfg.updates.autoApply) "--dry-run"} \
          ${optionalString cfg.updates.autoApply "--force"}
      '';
      
      # Post-update health check
      postStart = mkIf cfg.updates.testBeforeApply ''
        if ! ${pkgs.bash}/bin/bash /etc/nixos/scripts/config-health-monitor.sh check; then
          ${optionalString cfg.updates.rollbackOnFailure ''
            echo "Health check failed, rolling back..."
            ${pkgs.bash}/bin/bash /etc/nixos/scripts/dependency-update.sh rollback
          ''}
          exit 1
        fi
      '';
    };

    systemd.timers.dependency-update = mkIf cfg.updates.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.updates.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Security update service (separate from main updates)
    systemd.services.security-update = mkIf cfg.updates.securityUpdates {
      description = "Security Updates";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        ${pkgs.bash}/bin/bash /etc/nixos/scripts/dependency-update.sh security \
          ${optionalString cfg.updates.autoApply "--force"}
      '';
    };

    systemd.timers.security-update = mkIf cfg.updates.securityUpdates {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # Configuration health monitoring service
    systemd.services.config-health-monitor = mkIf cfg.monitoring.enable {
      description = "Configuration Health Monitor";
      serviceConfig = {
        Type = "simple";
        User = "config-monitor";
        Group = "config-monitor";
        Restart = "always";
        RestartSec = "60";
        Environment = [
          "MONITORING_INTERVAL=${toString cfg.monitoring.interval}"
          "ALERTS_EMAIL=${toString cfg.monitoring.alertEmail}"
        ];
      };
      script = ''
        ${pkgs.bash}/bin/bash /etc/nixos/scripts/config-health-monitor.sh monitor \
          --interval ${toString cfg.monitoring.interval} \
          ${optionalString (cfg.monitoring.alertEmail != null) "--email ${cfg.monitoring.alertEmail}"}
      '';
      wantedBy = [ "multi-user.target" ];
    };

    # Baseline creation service
    systemd.services.config-baseline = mkIf (cfg.monitoring.enable && cfg.monitoring.baseline.autoCreate) {
      description = "Configuration Baseline Creation";
      serviceConfig = {
        Type = "oneshot";
        User = "config-monitor";
        Group = "config-monitor";
      };
      script = ''
        ${pkgs.bash}/bin/bash /etc/nixos/scripts/config-health-monitor.sh baseline
        
        # Cleanup old baselines
        find /var/lib/config-baselines -name "baseline_*.json" -type f | \
          sort -r | tail -n +${toString (cfg.monitoring.baseline.retention + 1)} | \
          xargs rm -f
      '';
    };

    systemd.timers.config-baseline = mkIf (cfg.monitoring.enable && cfg.monitoring.baseline.autoCreate) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.monitoring.baseline.schedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # Security vulnerability scanning
    systemd.services.security-scan = mkIf cfg.security.enable {
      description = "Security Vulnerability Scan";
      serviceConfig = {
        Type = "oneshot";
        User = "security-scanner";
        Group = "security-scanner";
      };
      script = ''
        scan_report="/var/log/security-scan-$(date +%Y%m%d_%H%M%S).log"
        
        echo "=== Security Vulnerability Scan: $(date) ===" > "$scan_report"
        echo "Hostname: $(hostname)" >> "$scan_report"
        echo "" >> "$scan_report"
        
        ${concatMapStringsSep "\n" (tool: 
          if tool == "vulnix" then ''
            echo "Vulnix Scan Results:" >> "$scan_report"
            ${pkgs.vulnix}/bin/vulnix --system >> "$scan_report" 2>&1 || true
            echo "" >> "$scan_report"
          '' else ""
        ) cfg.security.tools}
        
        # Check for critical vulnerabilities
        if grep -i "critical\|high" "$scan_report" >/dev/null; then
          echo "Critical vulnerabilities found!" >> "$scan_report"
          
          ${optionalString cfg.security.autoUpdate ''
            echo "Applying security updates..." >> "$scan_report"
            ${pkgs.bash}/bin/bash /etc/nixos/scripts/dependency-update.sh security --force
          ''}
          
          # Send alert
          ${optionalString (cfg.monitoring.alertEmail != null) ''
            mail -s "Security Alert - $(hostname)" "${cfg.monitoring.alertEmail}" < "$scan_report"
          ''}
        fi
        
        echo "Security scan completed: $scan_report"
      '';
    };

    systemd.timers.security-scan = mkIf cfg.security.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.security.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # System cleanup service
    systemd.services.maintenance-cleanup = mkIf cfg.tasks.cleanup.enable {
      description = "System Maintenance Cleanup";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        echo "Starting system cleanup..."
        
        ${optionalString cfg.tasks.cleanup.nixStore ''
          echo "Cleaning Nix store..."
          nix-collect-garbage -d
          
          echo "Removing old generations..."
          nix-env --delete-generations old
          
          if command -v nixos-rebuild >/dev/null 2>&1; then
            nixos-rebuild switch --delete-generations old
          fi
        ''}
        
        ${optionalString cfg.tasks.cleanup.logs ''
          echo "Cleaning logs..."
          journalctl --vacuum-time=${cfg.tasks.cleanup.retention}
          journalctl --vacuum-size=500M
          
          # Clean old log files
          find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
          find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
        ''}
        
        # Clean temporary files
        find /tmp -type f -atime +3 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        
        echo "System cleanup completed"
      '';
    };

    systemd.timers.maintenance-cleanup = mkIf cfg.tasks.cleanup.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.tasks.cleanup.schedule;
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };

    # System optimization service
    systemd.services.maintenance-optimization = mkIf cfg.tasks.optimization.enable {
      description = "System Optimization";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        echo "Starting system optimization..."
        
        ${optionalString cfg.tasks.optimization.nixStoreOptimize ''
          echo "Optimizing Nix store..."
          nix-store --optimise
          
          echo "Verifying Nix store..."
          nix-store --verify --check-contents --repair
        ''}
        
        # Update locate database
        if command -v updatedb >/dev/null 2>&1; then
          echo "Updating locate database..."
          updatedb
        fi
        
        echo "System optimization completed"
      '';
    };

    systemd.timers.maintenance-optimization = mkIf cfg.tasks.optimization.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.tasks.optimization.schedule;
        Persistent = true;
        RandomizedDelaySec = "3h";
      };
    };

    # Maintenance reporting service
    systemd.services.maintenance-report = mkIf cfg.reporting.enable {
      description = "Maintenance Report Generation";
      serviceConfig = {
        Type = "oneshot";
        User = "maintenance-reporter";
        Group = "maintenance-reporter";
      };
      script = ''
        report_file="/tmp/maintenance-report-$(date +%Y%m%d_%H%M%S).${cfg.reporting.format}"
        
        ${pkgs.bash}/bin/bash /etc/nixos/scripts/config-health-monitor.sh report > "$report_file"
        
        # Add dependency update information
        echo "" >> "$report_file"
        echo "Dependency Update Status" >> "$report_file"
        echo "======================" >> "$report_file"
        
        if [[ -f "/var/log/dependency-updates.log" ]]; then
          echo "Recent updates:" >> "$report_file"
          tail -20 /var/log/dependency-updates.log >> "$report_file"
        fi
        
        # Add security scan results
        echo "" >> "$report_file"
        echo "Security Status" >> "$report_file"
        echo "==============" >> "$report_file"
        
        latest_scan=$(ls -t /var/log/security-scan-*.log 2>/dev/null | head -1)
        if [[ -n "$latest_scan" ]]; then
          echo "Latest security scan results:" >> "$report_file"
          tail -10 "$latest_scan" >> "$report_file"
        fi
        
        echo "Maintenance report generated: $report_file"
        
        ${optionalString (cfg.reporting.email != null) ''
          mail -s "Maintenance Report - $(hostname)" "${cfg.reporting.email}" < "$report_file"
        ''}
      '';
    };

    systemd.timers.maintenance-report = mkIf cfg.reporting.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.reporting.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Create required users
    users.users = {
      config-monitor = mkIf cfg.monitoring.enable {
        isSystemUser = true;
        group = "config-monitor";
        home = "/var/lib/config-monitor";
        createHome = true;
      };
      
      security-scanner = mkIf cfg.security.enable {
        isSystemUser = true;
        group = "security-scanner";
        home = "/var/lib/security-scanner";
        createHome = true;
      };
      
      maintenance-reporter = mkIf cfg.reporting.enable {
        isSystemUser = true;
        group = "maintenance-reporter";
        home = "/var/lib/maintenance-reporter";
        createHome = true;
      };
    };

    users.groups = {
      config-monitor = mkIf cfg.monitoring.enable {};
      security-scanner = mkIf cfg.security.enable {};
      maintenance-reporter = mkIf cfg.reporting.enable {};
    };

    # Create log directories
    systemd.tmpfiles.rules = [
      "d /var/log/maintenance 0755 root root -"
      "d /var/lib/config-baselines 0755 config-monitor config-monitor -"
      "d /var/lib/config-monitor 0755 config-monitor config-monitor -"
      "d /var/lib/security-scanner 0755 security-scanner security-scanner -"
      "d /var/lib/maintenance-reporter 0755 maintenance-reporter maintenance-reporter -"
    ];

    # Maintenance script locations
    environment.etc = {
      "nixos/scripts/dependency-update.sh" = {
        source = ../../scripts/dependency-update.sh;
        mode = "0755";
      };
      
      "nixos/scripts/config-health-monitor.sh" = {
        source = ../../scripts/config-health-monitor.sh;
        mode = "0755";
      };
    };
  };
}