{ config, pkgs, lib, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  cfg = config.nixconf.performance;
in
{
  options.nixconf.performance = with lib; {
    enable = mkEnableOption "performance optimizations" // { default = true; };
    
    cpu = {
      governor = mkOption {
        type = types.enum [ "performance" "powersave" "ondemand" "conservative" "schedutil" ];
        default = "schedutil";
        description = "CPU governor for power management";
      };
      
      enableMicrocode = mkEnableOption "microcode updates" // { default = true; };
    };
    
    memory = {
      enableZram = mkEnableOption "zram compression" // { default = false; };
      swappiness = mkOption {
        type = types.ints.between 0 100;
        default = 10;
        description = "Swappiness value (0-100)";
      };
    };
    
    storage = {
      enableFstrim = mkEnableOption "SSD TRIM support" // { default = true; };
      scheduler = mkOption {
        type = types.enum [ "mq-deadline" "kyber" "bfq" "none" ];
        default = "mq-deadline";
        description = "I/O scheduler";
      };
    };
    
    network = {
      optimizeTcp = mkEnableOption "TCP optimization" // { default = true; };
      enableBbr = mkEnableOption "BBR congestion control" // { default = true; };
    };
  };
  
  config = lib.mkIf cfg.enable ({
    # macOS performance optimizations
  } // lib.optionalAttrs isNixOS {
    # CPU performance tuning
    powerManagement = {
      enable = true;
      cpuFreqGovernor = cfg.cpu.governor;
    };

    # Microcode updates
    hardware.cpu.intel.updateMicrocode = lib.mkIf cfg.cpu.enableMicrocode (
      lib.mkDefault config.hardware.enableRedistributableFirmware
    );
    hardware.cpu.amd.updateMicrocode = lib.mkIf cfg.cpu.enableMicrocode (
      lib.mkDefault config.hardware.enableRedistributableFirmware
    );

    # Memory management
    boot = {
      # Kernel parameters for performance (boot-time only)
      kernelParams = [
        # I/O scheduler
        "elevator=${cfg.storage.scheduler}"
      ];

      # Kernel modules for performance
      kernelModules = lib.optionals cfg.network.enableBbr [ "tcp_bbr" ];

      # Sysctl parameters (runtime kernel settings)
      kernel.sysctl = {
        # Memory management
        "vm.swappiness" = cfg.memory.swappiness;
      } // lib.optionalAttrs cfg.network.optimizeTcp {
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_max" = 16777216;
        "net.ipv4.tcp_rmem" = "4096 16384 16777216";
        "net.ipv4.tcp_wmem" = "4096 16384 16777216";
      } // lib.optionalAttrs cfg.network.enableBbr {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
    };

    # Zram configuration
    zramSwap = lib.mkIf cfg.memory.enableZram {
      enable = true;
      memoryPercent = 25;
      algorithm = "zstd";
    };

    # SSD optimization
    services = {
      # TRIM support for SSDs
      fstrim = lib.mkIf cfg.storage.enableFstrim {
        enable = true;
        interval = "weekly";
      };

      # Thermald for Intel thermal management
      thermald.enable = lib.mkDefault true;

      # Power management
      power-profiles-daemon.enable = lib.mkDefault false;
      tlp = {
        enable = lib.mkDefault true;
        settings = {
          # CPU performance
          CPU_SCALING_GOVERNOR_ON_AC = cfg.cpu.governor;
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

          # Energy savings
          ENERGY_PERF_POLICY_ON_AC = "performance";
          ENERGY_PERF_POLICY_ON_BAT = "power";

          # Platform profile
          PLATFORM_PROFILE_ON_AC = "performance";
          PLATFORM_PROFILE_ON_BAT = "low-power";

          # USB autosuspend
          USB_AUTOSUSPEND = 1;
          USB_BLACKLIST_PHONE = 1;
        };
      };
    };

    # System limits and kernel parameters
    systemd = {
      settings.Manager = {
        # Increase default limits
        DefaultLimitNOFILE = 1048576;
        DefaultLimitSTACK = "16M";
      };

      # Tmpfs for /tmp
      tmpfiles.rules = [
        "D /tmp 1777 root root 10d"
      ];
    };
  } // lib.optionalAttrs isDarwin {
    system = {
      defaults = {
        NSGlobalDomain = {
          # Disable window animations for speed
          NSAutomaticWindowAnimationsEnabled = false;
          
          # Faster key repeat
          InitialKeyRepeat = 14;
          KeyRepeat = 1;
        };
        
        dock = {
          # Faster animations
          autohide-time-modifier = 0.2;
          expose-animation-duration = 0.1;
        };
        
        finder = {
          # Disable animations
          DisableAllAnimations = true;
        };
        
        universalaccess = {
          # Reduce motion for performance
          reduceMotion = true;
        };
      };
    };
  });
}