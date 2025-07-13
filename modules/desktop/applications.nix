{ config, pkgs, lib, ... }:

{
  # Desktop applications configuration
  config = lib.mkIf config.desktop.enable {
    # Essential desktop applications
    environment.systemPackages = with pkgs; [
      # Web browsers
      firefox
      chromium
      
      # Communication
      thunderbird
      discord
      slack
      teams-for-linux
      zoom-us
      
      # Office and productivity
      libreoffice-fresh
      evince # PDF viewer
      okular # Alternative PDF viewer with more features
      zathura # Minimal PDF viewer
      
      # Media players
      vlc
      mpv
      spotify
      
      # Image viewers and editors
      feh # Minimal image viewer
      imv # Wayland native image viewer
      gimp
      inkscape
      
      # System utilities
      pavucontrol # PulseAudio volume control
      blueman # Bluetooth manager
      gnome-system-monitor
      baobab # Disk usage analyzer
      
      # File management
      xfce.thunar # Alternative file manager
      ranger # Terminal file manager
      
      # Archive managers
      file-roller
      unrar
      
      # Password management
      bitwarden
      bitwarden-cli
      
      # Note-taking and organization
      obsidian
      logseq
      
      # Development-related GUI apps
      dbeaver-bin # Database GUI
      postman # API testing
      
      # Screen capture and recording
      obs-studio
      flameshot # Works with XWayland
      
      # Remote desktop
      remmina
      
      # System configuration
      dconf-editor
      gnome-tweaks
      
      # Fonts and themes
      papirus-icon-theme
      catppuccin-gtk
      catppuccin-cursors
      
      # Calculator
      gnome-calculator
      
      # Text editors (GUI)
      gedit
      
      # Virtualization
      virt-manager
      
      # Clipboard managers
      copyq
      
      # Download managers
      wget
      aria2
      youtube-dl
      yt-dlp
      
      # Security tools
      keepassxc
      
      # Graphics tools
      blender
      krita
      
      # CAD software
      freecad
      
      # Science and engineering
      octave
      
      # Games and entertainment
      steam
      lutris
      
      # Backup tools
      deja-dup
      
      # Diff tools
      meld
      
      # Hex editors
      ghex
      
      # System info
      neofetch
      htop
      btop
      
      # Wayland-specific tools
      wdisplays # Display configuration
      wev # Event viewer
      wl-mirror # Screen mirroring
    ];
    
    # Firefox configuration
    programs.firefox = {
      enable = true;
      preferences = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.aboutConfig.showWarning" = false;
      };
    };
    
    # Chromium configuration
    programs.chromium = {
      enable = true;
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "pkehgijcmpdhfbdbbnkijodmdjhbjlgp" # Privacy Badger
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      ];
      extraOpts = {
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [ "en-US" ];
      };
    };
    
    # Thunar file manager plugins
    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
        thunar-media-tags-plugin
      ];
    };
    
    # Steam configuration
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    
    # Enable flatpak for additional applications
    services.flatpak.enable = true;
    
    # XDG mime types
    xdg.mime = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.gnome.Evince.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "image/webp" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "audio/mpeg" = "mpv.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/mailto" = "thunderbird.desktop";
      };
    };
    
    # GTK theme configuration
    programs.dconf.enable = true;
    
    # Qt theme configuration
    qt = {
      enable = true;
      platformTheme = "gtk2";
      style = "gtk2";
    };
    
    # Enable GStreamer plugins for media playback
    environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-base
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-libav
      pkgs.gst_all_1.gst-vaapi
    ];
    
    # Thumbnail support
    services.tumbler.enable = true;
    
    # Enable GVFS for mounting and trash support
    services.gvfs = {
      enable = true;
      package = pkgs.gnome.gvfs;
    };
    
    # Application-specific services
    services.gnome.gnome-keyring.enable = true;
    programs.seahorse.enable = true; # GUI for gnome-keyring
    
    # Java configuration for GUI applications
    programs.java = {
      enable = true;
      package = pkgs.openjdk17;
    };
  };
}