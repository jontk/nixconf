{ config, pkgs, lib, options, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  # Common configuration options with sensible defaults
  cfg = config.nixconf.common;
in
{
  # Import additional common modules
  imports = [
    ./feature-flags.nix
    ./feature-implementations.nix
    ./feature-presets.nix
    ./performance.nix
    ./nix-settings.nix
  ];
  # Module options for customization
  options.nixconf.common = with lib; {
    enable = mkEnableOption "common configuration" // { default = true; };
    
    performanceOptimizations = mkEnableOption "performance optimizations" // { default = true; };
    
    networking.enableNetworkManager = mkEnableOption "NetworkManager" // { default = isNixOS; };
    
    locale = {
      timeZone = mkOption {
        type = types.str;
        default = "UTC";
        description = "System timezone";
      };
      
      defaultLocale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = "Default system locale";
      };
    };
    
    security = {
      enableFirewall = mkEnableOption "firewall" // { default = isNixOS; };
      allowUnfreePackages = mkEnableOption "unfree packages" // { default = true; };
    };
  };

  # Configuration implementation
  config = lib.mkIf cfg.enable {
    # Nix configuration - shared across all systems
    nix = {
      settings = {
        # Enable flakes and new nix command
        experimental-features = [ "nix-command" "flakes" ];
        
        # Performance optimizations
        auto-optimise-store = lib.mkIf cfg.performanceOptimizations true;
        max-jobs = lib.mkIf cfg.performanceOptimizations "auto";
        cores = lib.mkIf cfg.performanceOptimizations 0; # Use all available cores
        
        # Substituters for faster builds
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://hyprland.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
        
        # Build settings
        keep-outputs = true;
        keep-derivations = true;
        
        # Allow builds on all users (Darwin)
        trusted-users = lib.mkIf isDarwin [ "root" "@admin" ];
      };
      
      # Garbage collection
      gc = {
        automatic = true;
        dates = if isDarwin then "weekly" else "weekly";
        options = "--delete-older-than 30d";
      };
      
      # Additional nix configuration for performance
      extraOptions = lib.mkIf cfg.performanceOptimizations ''
        keep-outputs = true
        keep-derivations = true
        experimental-features = nix-command flakes
      '';
    };

    # Package configuration
    nixpkgs.config = {
      allowUnfree = cfg.security.allowUnfreePackages;
      allowUnsupportedSystem = true;
      permittedInsecurePackages = [
        "libsoup-2.74.3"  # Required for webex and citrix_workspace
      ];
    };

    # Common system packages - essential tools for all systems
    environment.systemPackages = with pkgs; [
      # Essential command line tools
      curl
      wget
      git
      vim
      nano
      
      # File and archive utilities
      tree
      unzip
      zip
      p7zip
      rsync
      
      # System monitoring and information
      htop
      btop
      neofetch
      lsof
      
      # Network utilities
      nmap
      netcat
      dig
      whois
      
      # Development utilities
      jq
      yq
      
      # Text processing
      ripgrep
      fd
      bat
      eza
      
      # System utilities
      pciutils
      usbutils
    ] ++ lib.optionals isNixOS [
      # NixOS-specific packages
      nixos-option
      nix-index
    ] ++ lib.optionals isDarwin [
      # Darwin-specific packages
      coreutils
      findutils
      gnu-sed
      gnu-tar
      gawk
    ];

    # Shell configuration
    programs = {
      # Enable zsh system-wide
      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestions.enable = true;
        syntaxHighlighting.enable = true;
      };
      
      # Git system configuration
      git = {
        enable = true;
        config = {
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
        };
      };
      
      # Direnv for development environments
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    # NixOS-specific configuration
  } // lib.optionalAttrs isNixOS {
    # Time and locale configuration
    time.timeZone = cfg.locale.timeZone;

    # NixOS-specific locale configuration
    i18n = {
      defaultLocale = cfg.locale.defaultLocale;
      extraLocaleSettings = {
        LC_ADDRESS = cfg.locale.defaultLocale;
        LC_IDENTIFICATION = cfg.locale.defaultLocale;
        LC_MEASUREMENT = cfg.locale.defaultLocale;
        LC_MONETARY = cfg.locale.defaultLocale;
        LC_NAME = cfg.locale.defaultLocale;
        LC_NUMERIC = cfg.locale.defaultLocale;
        LC_PAPER = cfg.locale.defaultLocale;
        LC_TELEPHONE = cfg.locale.defaultLocale;
        LC_TIME = cfg.locale.defaultLocale;
      };
    };

    # Networking configuration
    networking = {
      networkmanager.enable = cfg.networking.enableNetworkManager;
      firewall.enable = cfg.security.enableFirewall;
    };

    # Security configuration
    security = {
      sudo = {
        enable = true;
        wheelNeedsPassword = true;
      };
      polkit.enable = true;
      rtkit.enable = true;
    };

    # Font configuration
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          monospace = [ "Fira Code" "Liberation Mono" ];
          sansSerif = [ "Noto Sans" "Liberation Sans" ];
          serif = [ "Noto Serif" "Liberation Serif" ];
        };
      };
    };

    # Services configuration
    services = {
      printing.enable = true;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
      udisks2.enable = true;
      dbus.enable = true;
      fwupd.enable = true;
    };

    # Hardware configuration
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      pulseaudio.enable = false;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    # User configuration
    users = {
      defaultUserShell = pkgs.zsh;
      users.jontk = {
        isNormalUser = true;
        description = "Jon Thor Kristinsson";
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "video"
          "docker"
          "plugdev"
        ];
        shell = pkgs.zsh;
      };
    };

    # macOS-specific configuration
  } // lib.optionalAttrs isDarwin {
    system = {
      # macOS defaults
      defaults = {
        NSGlobalDomain = {
          # Key repeat settings
          InitialKeyRepeat = 14;
          KeyRepeat = 1;
          
          # Disable automatic capitalization
          NSAutomaticCapitalizationEnabled = false;
          
          # Disable automatic dash substitution
          NSAutomaticDashSubstitutionEnabled = false;
          
          # Disable automatic period substitution
          NSAutomaticPeriodSubstitutionEnabled = false;
          
          # Disable automatic quote substitution
          NSAutomaticQuoteSubstitutionEnabled = false;
          
          # Disable automatic spelling correction
          NSAutomaticSpellingCorrectionEnabled = false;
        };
        
        dock = {
          # Auto-hide dock
          autohide = true;
          
          # Remove delay for showing dock
          autohide-delay = 0.0;
          
          # Faster dock animation
          autohide-time-modifier = 0.5;
          
          # Don't show recent applications
          show-recents = false;
          
          # Dock position
          orientation = "bottom";
        };
        
        finder = {
          # Show all filename extensions
          AppleShowAllExtensions = true;
          
          # Show hidden files
          AppleShowAllFiles = true;
          
          # Show path bar
          ShowPathbar = true;
          
          # Show status bar
          ShowStatusBar = true;
        };
      };
    };
  };
}