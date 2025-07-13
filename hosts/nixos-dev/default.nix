{ config, pkgs, lib, ... }:

{
  # NixOS base configuration for development machine
  
  # System identification
  networking.hostName = "nixos-dev";
  networking.domain = "local";
  
  # System state version - IMPORTANT: Don't change after initial install
  system.stateVersion = "24.05";
  
  # Nix configuration
  nix = {
    # Enable flakes and new nix command
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Trusted users for binary cache
      trusted-users = [ "root" "@wheel" "jontk" ];
      # Auto optimize store
      auto-optimise-store = true;
      # Build options
      max-jobs = "auto";
      cores = 0; # Use all available cores
      # Substituters
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
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  
  # Hardware configuration import
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/development
    ../../modules/desktop
    ../../modules/remote-access
  ];
  
  # Enable desktop environment
  desktop = {
    enable = true;
    graphics = {
      driver = "intel"; # Change to "amd", "nvidia", "hybrid-intel-nvidia", etc. as needed
      highDpi = false; # Set to true for high DPI displays
    };
  };
  
  # Boot loader configuration
  boot = {
    # Use systemd-boot
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Keep last 10 generations
        editor = false; # Disable editor for security
      };
      efi.canTouchEfiVariables = true;
      timeout = 3; # Boot menu timeout in seconds
    };
    
    # Kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "nvidia-drm.modeset=1" # For NVIDIA GPUs
    ];
    
    # Use latest kernel
    kernelPackages = pkgs.linuxPackages_latest;
    
    # Enable SysRq keys
    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };
    
    # Initial RAM disk
    initrd = {
      # Modules to load early
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    
    # Support NTFS
    supportedFilesystems = [ "ntfs" ];
    
    # Plymouth boot splash
    plymouth = {
      enable = true;
      theme = "breeze";
    };
  };
  
  # Networking configuration
  networking = {
    # Enable NetworkManager (desktop-friendly)
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      wifi = {
        backend = "wpa_supplicant";
        macAddress = "random"; # Privacy
      };
    };
    
    # Firewall configuration
    firewall = {
      enable = true;
      allowPing = true;
      # Open ports for development
      allowedTCPPorts = [
        22    # SSH
        80    # HTTP
        443   # HTTPS
        3000  # Development servers
        3001  # Development servers
        8080  # Alternative HTTP
        8081  # Alternative HTTP
      ];
      allowedUDPPorts = [
        # mDNS
        5353
      ];
    };
    
    # Enable IPv6
    enableIPv6 = true;
    
    # Hosts file additions
    hosts = {
      "127.0.0.1" = [ "localhost" "dev.local" ];
      "::1" = [ "localhost" "dev.local" ];
    };
  };
  
  # Time zone and locale
  time.timeZone = "UTC"; # Change to your timezone
  
  # Internationalization
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
  
  # Console configuration
  console = {
    packages = with pkgs; [ terminus_font ];
    font = "ter-v16b";
    keyMap = "us";
  };
  
  # Users configuration
  users = {
    # Disable mutable users
    mutableUsers = false;
    
    # Define users
    users = {
      jontk = {
        isNormalUser = true;
        description = "Jon Thor Kristinsson";
        hashedPassword = "$6$rounds=424242$yourhashedpasswordhere"; # Use mkpasswd to generate
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "video"
          "dialout"
          "docker"
          "libvirtd"
          "kvm"
          "input"
          "render"
        ];
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = [
          # Add your SSH public key here
          # "ssh-ed25519 AAAAC3... user@host"
        ];
      };
      
      # Root user configuration
      root = {
        hashedPassword = "!"; # Disable root login
      };
    };
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Essential system tools
    vim
    wget
    curl
    git
    htop
    btop
    tree
    file
    which
    gnumake
    
    # System administration
    pciutils
    usbutils
    lshw
    dmidecode
    
    # Network tools
    iproute2
    iputils
    dnsutils
    nmap
    netcat
    traceroute
    
    # File systems
    ntfs3g
    exfat
    e2fsprogs
    btrfs-progs
    xfsprogs
    
    # Compression
    zip
    unzip
    p7zip
    
    # Terminal utilities
    tmux
    screen
    
    # Hardware monitoring
    lm_sensors
    smartmontools
  ];
  
  # Programs configuration
  programs = {
    # Enable zsh system-wide
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };
    
    # Enable mtr (network diagnostic tool)
    mtr.enable = true;
    
    # Enable GNU Privacy Guard
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-gtk2;
    };
    
    # Enable git
    git = {
      enable = true;
      lfs.enable = true;
    };
    
    # SSH configuration
    ssh = {
      startAgent = false; # We use gpg-agent
      extraConfig = ''
        Host *
          ServerAliveInterval 60
          ServerAliveCountMax 3
      '';
    };
    
    # Neovim as default editor
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };
  
  # Services configuration
  services = {
    # X11 configuration (for compatibility, even with Wayland)
    xserver = {
      enable = true;
      
      # Configure keyboard
      xkb = {
        layout = "us";
        variant = "";
        options = "caps:escape"; # Caps Lock as Escape
      };
      
      # Enable touchpad support
      libinput = {
        enable = true;
        touchpad = {
          naturalScrolling = true;
          tapping = true;
          clickMethod = "clickfinger";
          disableWhileTyping = true;
        };
      };
      
      # Video drivers (will be specified in hardware-configuration.nix)
      videoDrivers = [ ];
    };
    
    # Enable CUPS for printing
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        hplip
        epson-escpr
        epson-escpr2
      ];
    };
    
    # Enable sound with PipeWire
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
    
    # SSH server
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = true;
      };
      extraConfig = ''
        StreamLocalBindUnlink yes
      '';
    };
    
    # Enable fstrim for SSDs
    fstrim.enable = true;
    
    # Enable thermald for Intel CPUs
    thermald.enable = true;
    
    # Enable TLP for laptop power management
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
    
    # Bluetooth
    blueman.enable = true;
    
    # Enable GVFS for trash and mounting
    gvfs.enable = true;
    
    # Enable Avahi for network discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
    
    # System monitoring
    smartd = {
      enable = true;
      autodetect = true;
    };
    
    # Enable locate database
    locate = {
      enable = true;
      package = pkgs.plocate;
      localuser = null; # Update as root
      pruneBindMounts = true;
    };
  };
  
  # Security configuration
  security = {
    # Enable PolicyKit
    polkit.enable = true;
    
    # Enable rtkit for real-time scheduling
    rtkit.enable = true;
    
    # PAM configuration
    pam.services = {
      swaylock = {};
      login.enableGnomeKeyring = true;
    };
    
    # Sudo configuration
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
      extraRules = [
        {
          users = [ "jontk" ];
          commands = [
            {
              command = "${pkgs.systemd}/bin/systemctl";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
  };
  
  # Hardware configuration
  hardware = {
    # Enable all firmware
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    
    # CPU microcode
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    
    # Graphics
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    
    # Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
    
    # Sound
    pulseaudio.enable = false; # Using PipeWire instead
  };
  
  # System environment
  environment = {
    # Session variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BROWSER = "firefox";
      TERMINAL = "alacritty";
      # XDG directories
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
    
    # Default shell
    shells = with pkgs; [ bash zsh ];
    
    # System-wide aliases
    shellAliases = {
      # System management
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos";
      update = "nix flake update";
      upgrade = "sudo nixos-rebuild switch --upgrade --flake /etc/nixos";
      
      # Convenience
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      
      # Safety
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";
    };
  };
  
  # Systemd configuration
  systemd = {
    # Faster boot
    services.NetworkManager-wait-online.enable = false;
    
    # User services
    user.services = {
      # Example: Backup service
      # backup-home = {
      #   description = "Backup home directory";
      #   serviceConfig = {
      #     Type = "oneshot";
      #     ExecStart = "${pkgs.rsync}/bin/rsync -av $HOME/ /backup/";
      #   };
      # };
    };
    
    # Temporary files
    tmpfiles.rules = [
      "d /var/cache/nixos 0755 root root -"
      "d /var/log/journal 0755 root root -"
    ];
  };
  
  # Fonts configuration
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # System fonts
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      
      # Programming fonts
      fira-code
      fira-code-symbols
      jetbrains-mono
      cascadia-code
      
      # Nerd Fonts
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "JetBrainsMono"
          "Hack"
          "Iosevka"
          "NerdFontsSymbolsOnly"
        ];
      })
      
      # Icon fonts
      font-awesome
      material-design-icons
    ];
    
    # Font configuration
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif" "DejaVu Serif" ];
        sansSerif = [ "Noto Sans" "DejaVu Sans" ];
        monospace = [ "JetBrains Mono" "FiraCode Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
  
  # Virtualisation
  virtualisation = {
    # Docker
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    
    # Libvirt for VMs
    libvirtd = {
      enable = true;
      qemu = {
        ovmf.enable = true;
        swtpm.enable = true;
      };
    };
    
    # Podman as Docker alternative
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  
  # Documentation
  documentation = {
    enable = true;
    man.enable = true;
    info.enable = true;
    doc.enable = true;
    nixos.enable = true;
  };
  
  # Home Manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jontk = import ../../users/jontk {
      inherit config pkgs lib;
      isDarwin = false;
      isNixOS = true;
    };
    extraSpecialArgs = {
      inherit (config.nixpkgs) overlays;
      isDarwin = false;
      isNixOS = true;
    };
  };
  
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}