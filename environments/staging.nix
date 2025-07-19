# Staging Environment Configuration
{ config, lib, pkgs, ... }:

{
  # Staging-specific module configurations
  modules = {
    # Balanced security for staging
    security = {
      enable = true;
      # Enable most security features but not as strict as production
      auditd.enable = true;
      apparmor.enable = true;
      hardening.enable = true;
    };

    # Optimized performance for staging workloads
    performance = {
      enable = true;
      zram.enable = true;
      oomd.enable = true;
      cpu.governor = "schedutil"; # Balanced performance
    };

    # Full monitoring for staging validation
    monitoring = {
      enable = true;
      prometheus.enable = true;
      grafana.enable = true;
      logs.retention = "30d"; # Standard retention
    };

    # Production-like secrets management
    secrets = {
      enable = true;
      # Require proper secrets management in staging
    };
  };

  # Staging-specific system configuration
  config = {
    # Allow unfree packages but be more selective
    nixpkgs.config.allowUnfree = true;

    # Standard Nix features
    nix.settings.experimental-features = [ 
      "nix-command" 
      "flakes"
    ];

    # Production-like package selection
    environment.systemPackages = let
      packageSets = import ../packages/sets/default.nix { inherit pkgs lib; };
    in with packageSets; 
      core ++ cli ++ sysadmin ++ security ++ network;

    # Staging firewall - more restrictive than development
    networking.firewall = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      # Only necessary ports for staging services
      allowedTCPPorts = [
        80 443       # HTTP/HTTPS
        22           # SSH
        9090 3000    # Monitoring (Prometheus, Grafana)
      ];
      allowedUDPPorts = [
        # Minimal UDP access
      ];
    };

    # Staging-specific services
    services = lib.mkIf pkgs.stdenv.isLinux {
      # Fail2ban for security
      fail2ban = {
        enable = true;
        maxretry = 3; # Stricter than development
        bantime = "1h";
      };

      # System monitoring
      prometheus = {
        enable = true;
        retentionTime = "30d";
      };

      # Log management
      journald.settings = {
        SystemMaxUse = "1G";
        RuntimeMaxUse = "100M";
        MaxRetentionSec = "30d";
      };
    };

    # User profiles for staging
    home-manager.users.jontk = {
      profiles = {
        development.enable = false; # No dev tools in staging
        desktop.enable = false;     # Headless staging
        gaming.enable = false;
        minimal.enable = true;      # Minimal profile for staging
      };
    };

    # Staging-specific system settings
    boot.kernel.sysctl = {
      # More conservative settings
      "vm.swappiness" = 30;
      "net.ipv4.tcp_congestion_control" = "cubic";
    };
  };
}