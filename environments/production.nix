# Production Environment Configuration
{ config, lib, pkgs, ... }:

{
  # Production-specific module configurations
  modules = {
    # Maximum security for production
    security = {
      enable = true;
      # Enable all security features
      auditd.enable = true;
      apparmor.enable = true;
      hardening.enable = true;
    };

    # Production-optimized performance
    performance = {
      enable = true;
      zram.enable = true;
      oomd.enable = true;
      cpu.governor = "schedutil"; # Balanced for production workloads
    };

    # Comprehensive monitoring for production
    monitoring = {
      enable = true;
      prometheus.enable = true;
      grafana.enable = true;
      logs.retention = "90d"; # Extended retention for compliance
    };

    # Strict secrets management
    secrets = {
      enable = true;
      # Require sops-nix for all secrets in production
    };
  };

  # Production-specific system configuration
  config = {
    # Restrict unfree packages in production
    nixpkgs.config.allowUnfree = false;

    # Conservative Nix features
    nix.settings.experimental-features = [ 
      "nix-command" 
      "flakes"
    ];

    # Minimal production package set
    environment.systemPackages = let
      packageSets = import ../packages/sets/default.nix { inherit pkgs lib; };
    in with packageSets; 
      core ++ sysadmin ++ security ++ network;

    # Production firewall - highly restrictive
    networking.firewall = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      # Only essential production ports
      allowedTCPPorts = [
        80 443       # HTTP/HTTPS only
        22           # SSH (should be restricted by IP)
      ];
      allowedUDPPorts = [
        # No UDP ports by default
      ];
      
      # Additional security rules
      extraCommands = ''
        # Rate limit SSH connections
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 3 -j DROP
        
        # Drop all other traffic
        iptables -A INPUT -j DROP
        iptables -A FORWARD -j DROP
      '';
    };

    # Production-specific services
    services = lib.mkIf pkgs.stdenv.isLinux {
      # Strict fail2ban configuration
      fail2ban = {
        enable = true;
        maxretry = 2; # Very strict
        bantime = "24h"; # Long ban times
        jails = {
          sshd = {
            settings = {
              enabled = true;
              maxretry = 2;
              bantime = "24h";
              findtime = "10m";
            };
          };
        };
      };

      # Production monitoring
      prometheus = {
        enable = true;
        retentionTime = "90d";
        extraFlags = [
          "--storage.tsdb.retention.size=10GB"
          "--web.enable-admin-api"
        ];
      };

      # Audit logging
      auditd = {
        enable = true;
        rules = [
          # Monitor file access
          "-w /etc/passwd -p wa -k identity"
          "-w /etc/shadow -p wa -k identity"
          "-w /etc/group -p wa -k identity"
          "-w /etc/sudoers -p wa -k identity"
          
          # Monitor system calls
          "-a always,exit -F arch=b64 -S execve -k execve"
          "-a always,exit -F arch=b32 -S execve -k execve"
        ];
      };

      # Secure log management
      journald.settings = {
        SystemMaxUse = "2G";
        RuntimeMaxUse = "200M";
        MaxRetentionSec = "90d";
        Compress = "yes";
        Seal = "yes"; # Forward Secure Sealing
      };

      # Automatic security updates (consider carefully)
      # unattended-upgrades = {
      #   enable = true;
      #   automaticReboot = false; # Manual reboot for production
      # };
    };

    # No user profiles in production (headless)
    home-manager.users.jontk = {
      profiles = {
        development.enable = false;
        desktop.enable = false;
        gaming.enable = false;
        minimal.enable = true; # Absolutely minimal
      };
    };

    # Production-hardened system settings
    boot.kernel.sysctl = {
      # Security hardening
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
      
      # Network security
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.ip_forward" = 0;
      "net.ipv4.tcp_syncookies" = 1;
      
      # Performance optimization
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    # Production backup and recovery
    systemd.timers.system-backup = {
      description = "System backup timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    systemd.services.system-backup = {
      description = "System configuration backup";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.rsync}/bin/rsync -av /etc/nixos/ /backup/nixos/";
      };
    };
  };
}