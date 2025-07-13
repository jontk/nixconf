{ config, lib, ... }:

{
  # Feature presets for common configuration patterns
  # These can be enabled in host configurations for quick setup
  
  options.nixconf.presets = with lib; {
    # Development workstation preset
    developer = mkEnableOption "developer workstation preset";
    
    # Server preset
    server = mkEnableOption "server preset";
    
    # Desktop user preset
    desktop = mkEnableOption "desktop user preset";
    
    # Gaming preset
    gamer = mkEnableOption "gaming preset";
    
    # Security-focused preset
    security = mkEnableOption "security-focused preset";
    
    # Minimal preset
    minimal = mkEnableOption "minimal preset";
  };
  
  config = let
    cfg = config.nixconf.presets;
  in {
    # Developer workstation preset
    nixconf.features = lib.mkMerge [
      (lib.mkIf cfg.developer {
        development = {
          enable = true;
          rust = true;
          python = true;
          nodejs = true;
          go = true;
          docker = true;
          kubernetes = true;
        };
        virtualization = {
          docker = true;
          podman = true;
        };
        remote.ssh = true;
        backup = {
          enable = true;
          syncthing = true;
        };
        network.tailscale = true;
      })
      
      # Server preset
      (lib.mkIf cfg.server {
        server = {
          enable = true;
          web = true;
          database = true;
          monitoring = true;
        };
        security.hardening = true;
        remote.ssh = true;
        backup = {
          enable = true;
          restic = true;
        };
        virtualization = {
          docker = true;
          podman = true;
        };
        network = {
          wireguard = true;
          tailscale = true;
        };
      })
      
      # Desktop user preset
      (lib.mkIf cfg.desktop {
        desktop = {
          enable = true;
          multimedia = true;
          office = true;
        };
        development.enable = true;
        backup = {
          enable = true;
          syncthing = true;
          nextcloud = true;
        };
        network.tailscale = true;
      })
      
      # Gaming preset
      (lib.mkIf cfg.gamer {
        desktop = {
          enable = true;
          gaming = true;
          multimedia = true;
        };
        virtualization.libvirt = true; # For Windows VMs
        network.tailscale = true;
      })
      
      # Security-focused preset
      (lib.mkIf cfg.security {
        security = {
          hardening = true;
          vpn = true;
          tor = true;
          yubikey = true;
        };
        network = {
          wireguard = true;
          tailscale = true;
        };
        backup = {
          enable = true;
          restic = true;
        };
        remote.ssh = true;
      })
      
      # Minimal preset - only essential features
      (lib.mkIf cfg.minimal {
        remote.ssh = true;
        # Everything else disabled by default
      })
    ];
    
    # Performance optimizations for different presets
    nixconf.performance = {
      cpu.governor = lib.mkDefault (
        if cfg.gamer then "performance"
        else if cfg.server then "powersave" 
        else "schedutil"
      );
      
      memory.enableZram = lib.mkDefault (cfg.minimal || cfg.server);
      
      network.enableBbr = lib.mkDefault (cfg.server || cfg.developer);
    };
    
    # Locale settings based on preset
    nixconf.common.locale = {
      timeZone = lib.mkDefault "UTC";
      defaultLocale = lib.mkDefault "en_US.UTF-8";
    };
  };
}