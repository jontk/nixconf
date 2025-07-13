{ config, pkgs, lib, ... }:

{
  imports = [
    ./hyprland.nix
    ./applications.nix
  ];

  # Desktop environment configuration for NixOS
  # This module configures Wayland, graphics drivers, and desktop environment
  
  # Enable feature flags for desktop configuration
  options.desktop = {
    enable = lib.mkEnableOption "desktop environment";
    
    graphics = {
      driver = lib.mkOption {
        type = lib.types.enum [ "intel" "amd" "nvidia" "hybrid-intel-nvidia" "hybrid-amd-nvidia" "vmware" "virtualbox" ];
        default = "intel";
        description = "Graphics driver to use";
      };
      
      highDpi = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable high DPI support";
      };
    };
  };
  
  config = lib.mkIf config.desktop.enable {
    # Enable hardware graphics acceleration
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      
      # Configure driver-specific packages
      extraPackages = with pkgs; (
        if config.desktop.graphics.driver == "intel" then [
          intel-media-driver
          vaapiIntel
          vaapiVdpau
          libvdpau-va-gl
          intel-compute-runtime
        ]
        else if config.desktop.graphics.driver == "amd" then [
          rocm-opencl-icd
          rocm-opencl-runtime
          amdvlk
        ]
        else if config.desktop.graphics.driver == "nvidia" then [
          vaapiVdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
        ]
        else if lib.hasPrefix "hybrid-" config.desktop.graphics.driver then [
          intel-media-driver
          vaapiIntel
          vaapiVdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
        ]
        else [ ]
      );
      
      extraPackages32 = with pkgs.pkgsi686Linux; (
        if config.desktop.graphics.driver == "amd" then [ amdvlk ]
        else [ ]
      );
    };
    
    # NVIDIA-specific configuration
    hardware.nvidia = lib.mkIf (lib.hasInfix "nvidia" config.desktop.graphics.driver) {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = lib.mkIf (lib.hasPrefix "hybrid-" config.desktop.graphics.driver) true;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      
      prime = lib.mkIf (lib.hasPrefix "hybrid-" config.desktop.graphics.driver) {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Bus IDs need to be configured per-system in hardware-configuration.nix
        # intelBusId = "PCI:0:2:0";
        # nvidiaBusId = "PCI:1:0:0";
      };
    };
    
    # X11 configuration (needed for some compatibility even with Wayland)
    services.xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
      
      # Video drivers
      videoDrivers = 
        if config.desktop.graphics.driver == "intel" then [ "modesetting" ]
        else if config.desktop.graphics.driver == "amd" then [ "amdgpu" ]
        else if config.desktop.graphics.driver == "nvidia" then [ "nvidia" ]
        else if lib.hasPrefix "hybrid-" config.desktop.graphics.driver then [ "nvidia" "modesetting" ]
        else if config.desktop.graphics.driver == "vmware" then [ "vmware" ]
        else if config.desktop.graphics.driver == "virtualbox" then [ "virtualbox" ]
        else [ "modesetting" ];
      
      # Display manager (using SDDM for Wayland compatibility)
      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
          theme = "breeze";
          settings = {
            Theme = {
              CursorTheme = "breeze_cursors";
            };
          };
        };
        defaultSession = "hyprland";
      };
      
      # Keyboard configuration
      xkb = {
        layout = "us";
        variant = "";
        options = "caps:escape,compose:ralt";
      };
      
      # Touchpad support
      libinput = {
        enable = true;
        touchpad = {
          naturalScrolling = true;
          tapping = true;
          clickMethod = "clickfinger";
          disableWhileTyping = true;
          scrollMethod = "twofinger";
        };
      };
    };
    
    # Wayland-specific configuration
    # Enable XWayland for X11 application compatibility
    programs.xwayland.enable = true;
    
    # Session variables for Wayland
    environment.sessionVariables = {
      # Wayland-specific
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      
      # Graphics-specific
      LIBVA_DRIVER_NAME = 
        if config.desktop.graphics.driver == "intel" then "iHD"
        else if lib.hasInfix "nvidia" config.desktop.graphics.driver then "nvidia"
        else "radeonsi";
      
      # NVIDIA-specific
      GBM_BACKEND = lib.mkIf (lib.hasInfix "nvidia" config.desktop.graphics.driver) "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = lib.mkIf (lib.hasInfix "nvidia" config.desktop.graphics.driver) "nvidia";
      WLR_NO_HARDWARE_CURSORS = lib.mkIf (lib.hasInfix "nvidia" config.desktop.graphics.driver) "1";
      
      # High DPI
      GDK_SCALE = lib.mkIf config.desktop.graphics.highDpi "2";
      GDK_DPI_SCALE = lib.mkIf config.desktop.graphics.highDpi "0.5";
      QT_AUTO_SCREEN_SCALE_FACTOR = lib.mkIf config.desktop.graphics.highDpi "1";
    };
    
    # Essential Wayland packages
    environment.systemPackages = with pkgs; [
      # Wayland utilities
      wayland
      wayland-utils
      wayland-protocols
      xwayland
      wl-clipboard
      wlr-randr
      wev # Wayland event viewer
      
      # Graphics utilities
      glxinfo
      vulkan-tools
      libva-utils
      vdpauinfo
      mesa-demos
      
      # Screen management
      kanshi # Wayland output management
      wdisplays # GUI display configurator
      
      # Screenshot and recording
      grim
      slurp
      wf-recorder
      
      # Compatibility layers
      qt5.qtwayland
      qt6.qtwayland
      
      # Cursor themes
      breeze-gtk
      breeze-icons
      breeze-qt5
    ];
    
    # Enable portals for desktop integration
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ];
      config = {
        common = {
          default = [ "hyprland" "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
    };
    
    # Security for Wayland
    security.pam.services.swaylock = {};
    
    # DBus configuration
    services.dbus = {
      enable = true;
      packages = with pkgs; [ dconf gcr gnome-keyring ];
    };
    
    # Enable gnome-keyring for secret management
    services.gnome.gnome-keyring.enable = true;
    
    # Power management for desktop
    services.upower.enable = true;
    
    # Notification daemon - should be configured via home-manager, not system services
    # TODO: Move dunst configuration to home-manager
    # services.dunst = {
    #   enable = true;
    #   settings = {
    #     global = {
    #       follow = "mouse";
    #       width = 300;
    #       height = 300;
    #       origin = "top-right";
    #       offset = "30x50";
    #       notification_limit = 3;
    #       progress_bar = true;
    #       transparency = 10;
    #       frame_color = "#89b4fa";
    #       font = "JetBrains Mono 10";
    #     };
    #   };
    # };
  };
}