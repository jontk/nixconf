# System Monitoring and Observability Module
{ config, lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
  cfg = config.modules.monitoring;
in
{
  options.modules.monitoring = with lib; {
    enable = mkEnableOption "system monitoring and observability";
    
    prometheus = {
      enable = mkEnableOption "Prometheus metrics collection";
      port = mkOption {
        type = types.int;
        default = 9090;
        description = "Prometheus server port";
      };
    };
    
    grafana = {
      enable = mkEnableOption "Grafana dashboards";
      port = mkOption {
        type = types.int;
        default = 3000;
        description = "Grafana server port";
      };
    };
    
    logs = {
      retention = mkOption {
        type = types.str;
        default = "30d";
        description = "Log retention period";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System monitoring services
    services = lib.mkIf isNixOS {
      # Prometheus monitoring
      prometheus = lib.mkIf cfg.prometheus.enable {
        enable = true;
        port = cfg.prometheus.port;
        
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [
              "systemd"
              "textfile"
              "filesystem"
              "netdev"
              "meminfo"
              "loadavg"
              "cpu"
            ];
            port = 9100;
          };
        };
        
        scrapeConfigs = [
          {
            job_name = "node-exporter";
            static_configs = [{
              targets = [ "localhost:9100" ];
            }];
          }
        ];
      };
      
      # Grafana dashboards
      grafana = lib.mkIf cfg.grafana.enable {
        enable = true;
        port = cfg.grafana.port;
        addr = "127.0.0.1";
        
        provision = {
          enable = true;
          datasources = [{
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString cfg.prometheus.port}";
            isDefault = true;
          }];
        };
        
        settings = {
          security = {
            admin_user = "admin";
            admin_password = "$__file{/run/secrets/grafana-password}";
          };
          
          analytics.reporting_enabled = false;
          analytics.check_for_updates = false;
        };
      };
      
      # Enhanced logging
      journald.extraConfig = ''
        SystemMaxUse=2G
        RuntimeMaxUse=500M
        MaxRetentionSec=${cfg.logs.retention}
        Compress=yes
        ForwardToSyslog=no
      '';
      
      # Log rotation
      logrotate = {
        enable = true;
        settings = {
          "/var/log/auth.log" = {
            frequency = "weekly";
            rotate = 4;
            compress = true;
            delaycompress = true;
            missingok = true;
            notifempty = true;
          };
        };
      };
    };

    # Monitoring packages
    environment.systemPackages = with pkgs; [
      # System monitoring
      htop
      btop
      iotop
      nethogs
      iftop
      bandwhich    # Network utilization by process
      
      # Performance analysis
      perf-tools
      sysstat      # iostat, mpstat, pidstat
      iperf3       # Network performance
      stress-ng    # System stress testing
      
      # Log analysis
      lnav         # Log navigator
      angle-grinder # Log parsing
      
      # System information
      neofetch
      cpufetch
      inxi         # System information
      hwinfo       # Hardware information
      
      # Disk usage
      ncdu         # Disk usage analyzer
      duf          # Better df
      dust         # Disk usage trees
      
      # Process monitoring
      procs        # Better ps
      bottom       # System monitor
    ] ++ lib.optionals isNixOS [
      # NixOS-specific tools
      nix-top      # Nix build monitoring
      nix-du       # Nix store analysis
    ];

    # System health checks
    systemd.timers = lib.mkIf isNixOS {
      disk-health-check = {
        description = "Check disk health";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };

    systemd.services = lib.mkIf isNixOS {
      disk-health-check = {
        description = "Check disk health using SMART";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = "${pkgs.smartmontools}/bin/smartctl -H /dev/sda || echo 'Disk health check failed' | ${pkgs.systemd}/bin/systemd-cat";
        };
      };
    };

    # Network monitoring
    networking.firewall.allowedTCPPorts = lib.mkIf isNixOS (
      lib.optional cfg.prometheus.enable cfg.prometheus.port ++
      lib.optional cfg.grafana.enable cfg.grafana.port
    );
  };
}