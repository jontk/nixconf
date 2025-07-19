# Performance Optimization Module
{ config, lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
  cfg = config.modules.performance;
in
{
  options.modules.performance = with lib; {
    enable = mkEnableOption "performance optimizations";
    
    zram.enable = mkEnableOption "zram compression";
    oomd.enable = mkEnableOption "systemd-oomd for memory management";
    cpu.governor = mkOption {
      type = types.str;
      default = "schedutil";
      description = "CPU governor for power management";
    };
  };

  config = lib.mkIf cfg.enable {
    # Zram for memory compression
    zramSwap = lib.mkIf (isNixOS && cfg.zram.enable) {
      enable = true;
      memoryPercent = 50; # Use 50% of RAM for zram
      algorithm = "zstd"; # Better compression
      priority = 10;      # Higher priority than disk swap
    };

    # Memory management and service optimizations
    systemd = lib.mkIf isNixOS {
      oomd = lib.mkIf cfg.oomd.enable {
        enable = true;
        enableRootSlice = true;
        enableUserSlices = true;
      };
      
      # Faster service startup
      extraConfig = ''
        DefaultTimeoutStopSec=30s
        DefaultTimeoutStartSec=30s
      '';
      
      # Optimize journald
      services.systemd-journald.serviceConfig = {
        SystemMaxUse = "500M";
        RuntimeMaxUse = "100M";
        SystemMaxFileSize = "50M";
      };
    };

    # CPU performance
    powerManagement = lib.mkIf isNixOS {
      enable = true;
      cpuFreqGovernor = cfg.cpu.governor;
    };

    # I/O scheduling and boot optimizations
    boot = lib.mkIf isNixOS {
      # Kernel sysctl settings
      kernel.sysctl = {
        # VM tuning
        "vm.dirty_ratio" = 15;
        "vm.dirty_background_ratio" = 5;
        "vm.swappiness" = 10;  # Prefer RAM over swap
        "vm.vfs_cache_pressure" = 50;
        
        # Network performance
        "net.core.rmem_max" = 134217728;
        "net.core.wmem_max" = 134217728;
        "net.ipv4.tcp_rmem" = "4096 87380 134217728";
        "net.ipv4.tcp_wmem" = "4096 65536 134217728";
        "net.ipv4.tcp_congestion_control" = "bbr";
        
        # File system
        "fs.file-max" = 2097152;
      };
      
      # Kernel modules
      kernelModules = [ "tcp_bbr" ]; # Better congestion control
      
      # Boot speed optimization
      loader.systemd-boot.configurationLimit = 10;
      loader.timeout = 3;
      
      # Initrd optimization
      initrd.systemd.enable = true; # Faster boot with systemd in initrd
      
      # Kernel parameters
      kernelParams = [
        "mitigations=off" # Disable CPU vulnerability mitigations for performance
        "quiet"
        "splash"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
      
      # Parallel kernel module loading
      kernel.sysctl."kernel.modules_disabled" = 0;
      
      # Temporary file systems
      tmp = {
        useTmpfs = true;
        tmpfsSize = "50%"; # Use 50% of RAM for /tmp
      };
    };

    # Nix store optimizations
    nix.settings = {
      # Build performance
      max-jobs = "auto";
      cores = 0; # Use all cores
      
      # Store optimization
      auto-optimise-store = true;
      min-free = lib.mkDefault (1000 * 1000 * 1000); # 1GB
      max-free = lib.mkDefault (3000 * 1000 * 1000); # 3GB
      
      # Parallel downloads
      http-connections = 128;
      max-substitution-jobs = 32;
      
      # Build isolation improvements
      sandbox = lib.mkDefault true;
      restrict-eval = false;
    };

    # Advanced garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d --max-freed 5G";
    };

    # Additional optimization settings
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };


  };
}