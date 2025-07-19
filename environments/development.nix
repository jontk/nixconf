# Development Environment Configuration
{ config, lib, pkgs, ... }:

{
  # Development-specific module configurations
  modules = {
    # Relaxed security for development
    security = {
      enable = true;
      # Disable strict security measures for development convenience
      auditd.enable = false;
      apparmor.enable = false;
      hardening.enable = false;
    };

    # Enhanced performance for development workloads
    performance = {
      enable = true;
      zram.enable = true;
      oomd.enable = true;
      cpu.governor = "performance";
    };

    # Comprehensive monitoring for development debugging
    monitoring = {
      enable = true;
      prometheus.enable = true;
      grafana.enable = true;
      logs.retention = "7d"; # Shorter retention for development
    };

    # Development-friendly secrets management
    secrets = {
      enable = true;
      # Allow fallback for development systems without sops-nix
    };
  };

  # Development-specific system configuration
  config = {
    # Allow unfree packages for development tools
    nixpkgs.config.allowUnfree = true;

    # Enable experimental features for development
    nix.settings.experimental-features = [ 
      "nix-command" 
      "flakes" 
      "ca-derivations"
      "auto-allocate-uids"
    ];

    # Development tools and packages
    environment.systemPackages = let
      packageSets = import ../packages/sets/default.nix { inherit pkgs lib; };
    in with packageSets; 
      core ++ cli ++ development ++ 
      languages.rust ++ languages.go ++ 
      languages.python ++ languages.javascript ++
      languages.java ++ languages.cAndCpp ++
      cloud ++ database ++ network;

    # Development-friendly firewall
    networking.firewall = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      # Open common development ports
      allowedTCPPorts = [
        3000 3001 3002 3003  # Frontend dev servers
        4000 4001 4002 4003  # Backend dev servers
        5000 5001 5002 5003  # Additional dev servers
        8000 8001 8080 8081  # HTTP alternatives
        9000 9001 9090 9091  # Monitoring and debugging
      ];
      allowedUDPPorts = [
        # Development multicast
        5353  # mDNS
      ];
    };

    # Development-specific services
    services = lib.mkIf pkgs.stdenv.isLinux {
      # Docker for development
      docker = {
        enable = true;
        enableOnBoot = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };

      # Development database services
      postgresql = {
        enable = true;
        package = pkgs.postgresql_15;
        authentication = ''
          local all all trust
          host all all 127.0.0.1/32 trust
          host all all ::1/128 trust
        '';
      };

      redis = {
        enable = true;
        openFirewall = false; # Only local access
      };
    };

    # User profiles for development
    home-manager.users.jontk = {
      profiles = {
        development.enable = true;
        desktop.enable = true;
        gaming.enable = false;
        minimal.enable = false;
      };
    };
  };
}