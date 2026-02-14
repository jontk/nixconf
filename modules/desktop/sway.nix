{ config, pkgs, lib, ... }:

{
  # Sway window manager configuration
  config = lib.mkIf config.desktop.enable {
    # Enable Sway
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
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

    # Environment variables for Sway
    environment.sessionVariables = {
      # Wayland support
      QT_QPA_PLATFORM = "wayland;xcb";
      GDK_BACKEND = "wayland,x11";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";

      # XDG Desktop Portal
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";

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
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "*";
    };

    # Security configuration
    security.pam.services.swaylock = {};
  };
}
