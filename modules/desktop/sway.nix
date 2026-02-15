{ config, pkgs, lib, ... }:

{
  # Sway window manager configuration
  config = lib.mkIf config.desktop.enable {
    # Enable Sway
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      # Required for proprietary NVIDIA drivers
      extraOptions = [ "--unsupported-gpu" ];
      extraPackages = with pkgs; [
        # Core Sway utilities
        swaylock # Screen locker
        swayidle # Idle management daemon
        swaybg # Wallpaper utility

        # Wayland utilities
        wl-clipboard # Clipboard utilities
        grim # Screenshot tool
        slurp # Screen area selection
        wf-recorder # Screen recorder

        # Status bar (shared with Hyprland)
        waybar

        # Application launcher
        wofi # Native wayland launcher
        rofi-wayland # Alternative launcher

        # Terminal emulators
        kitty
        alacritty
        foot # Lightweight wayland terminal

        # File manager
        nautilus

        # Notification daemon
        dunst # Managed by chezmoi/systemd

        # Polkit authentication agent
        polkit_gnome

        # Network manager applet
        networkmanagerapplet

        # Clipboard manager
        cliphist

        # System tray support
        libappindicator-gtk3

        # Theme and appearance
        gnome-themes-extra
        gtk-engine-murrine
        lxappearance

        # Brightness control
        brightnessctl

        # Audio control
        pavucontrol
      ];
    };

    # Environment variables for Wayland (shared between Sway and Hyprland)
    # Note: XDG_CURRENT_DESKTOP and XDG_SESSION_DESKTOP are set by the session itself
    # Note: WLR_NO_HARDWARE_CURSORS is set by desktop/default.nix for NVIDIA GPUs
    environment.sessionVariables = {
      # Wayland support
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";
      GDK_BACKEND = lib.mkDefault "wayland,x11";
      SDL_VIDEODRIVER = lib.mkDefault "wayland";
      CLUTTER_BACKEND = lib.mkDefault "wayland";

      # XDG Session Type
      XDG_SESSION_TYPE = lib.mkDefault "wayland";

      # Fix Java apps
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Enable Wayland for Mozilla apps
      MOZ_ENABLE_WAYLAND = "1";
    };

    # Additional system packages for Sway
    environment.systemPackages = with pkgs; [
      # Sway-specific tools
      sway-contrib.grimshot # Screenshot script

      # Additional utilities
      kanshi # Dynamic display configuration
      mako # Lightweight notification daemon (alternative to dunst)

      # Power management
      poweralertd

      # Theme tools
      qt5.qtwayland
      qt6.qtwayland
    ];

    # XDG Desktop Portal for Sway (for screensharing, etc.)
    xdg.portal = {
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
      # Portal config is handled by desktop/default.nix
    };

    # Security configuration
    security.pam.services.swaylock = {};
  };
}
