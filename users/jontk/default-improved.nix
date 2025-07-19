# Improved modular user configuration
{ config, pkgs, lib, isDarwin ? false, isNixOS ? false, ... }:

{
  imports = [
    ./profiles/base.nix
    ./profiles/development.nix
    ./profiles/desktop.nix
  ];

  # Home Manager basics
  home.stateVersion = "25.05";
  home.username = "jontk";
  home.homeDirectory = if isDarwin then "/Users/jontk" else "/home/jontk";
  programs.home-manager.enable = true;

  # Environment-specific overrides
  config = lib.mkMerge [
    # Base configuration for all environments
    {
      home.sessionVariables = {
        EDITOR = "nvim";
        BROWSER = if isDarwin then "open" else "firefox";
        TERMINAL = "alacritty";
      };
    }
    
    # Development environment specific
    (lib.mkIf (config.profiles.development.enable or true) {
      home.sessionVariables = {
        DOCKER_HOST = "unix:///var/run/docker.sock";
        KUBECONFIG = "$HOME/.kube/config";
      };
    })
    
    # Desktop environment specific  
    (lib.mkIf (config.profiles.desktop.enable or true) {
      # Desktop-specific settings
      xdg.enable = !isDarwin;
      
      # Theme configuration
      gtk = lib.mkIf (!isDarwin) {
        enable = true;
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome.gnome-themes-extra;
        };
      };
    })
  ];

  # Profile toggle options
  options.profiles = with lib; {
    development.enable = mkEnableOption "development profile" // { default = true; };
    desktop.enable = mkEnableOption "desktop profile" // { default = !isDarwin; };
    gaming.enable = mkEnableOption "gaming profile" // { default = false; };
  };
}