# Desktop profile - GUI applications and desktop environment
{ config, pkgs, lib, isDarwin ? false, ... }:

{
  home.packages = with pkgs; [
    # Web browsers
    firefox
    chromium
    
    # Communication
    discord
    signal-desktop
    
    # Development GUI tools
    dbeaver-bin
    insomnia
    
    # Media
    vlc
    mpv
    
    # Productivity
    obsidian
    libreoffice
    
    # Graphics
    gimp
    inkscape
    
    # File management
    xfce.thunar
    
    # Terminal emulators
    alacritty
    kitty
  ] ++ lib.optionals (!isDarwin) [
    # Linux-specific applications
    zathura # PDF viewer
    rofi    # Application launcher
  ];

  programs = {
    firefox = {
      enable = true;
      profiles.default = {
        settings = {
          "browser.startup.homepage" = "about:home";
          "privacy.trackingprotection.enabled" = true;
          "dom.security.https_only_mode" = true;
        };
      };
    };
    
    alacritty = {
      enable = true;
      settings = {
        window = {
          opacity = 0.95;
          padding = { x = 10; y = 10; };
        };
        font = {
          normal.family = "JetBrains Mono Nerd Font";
          size = 12;
        };
        colors = {
          primary = {
            background = "#1e1e2e";
            foreground = "#cdd6f4";
          };
        };
      };
    };
  };

  # XDG desktop entries
  xdg.desktopEntries = lib.mkIf (!isDarwin) {
    "project-browser" = {
      name = "Project Browser";
      comment = "Browse development projects";
      exec = "thunar /home/jontk/projects";
      icon = "folder-development";
      categories = [ "Development" "FileManager" ];
    };
  };
}