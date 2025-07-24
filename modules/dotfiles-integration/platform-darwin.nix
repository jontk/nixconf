{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  config = mkIf (cfg.enable && isDarwin) {
    # macOS/nix-darwin specific configurations
    
    # Homebrew integration for packages not in nixpkgs
    homebrew = mkIf (config ? homebrew) {
      enable = mkDefault true;
      
      # Homebrew packages for development tools
      brews = mkMerge [
        (optional cfg.modules.development.docker [ "docker" "docker-compose" ])
        (optional cfg.modules.development.kubernetes [ "kubectl" "helm" ])
      ];
      
      # Homebrew casks for GUI applications
      casks = mkMerge [
        (optional cfg.modules.development.docker [ "docker" ])
      ];
    };
    
    # macOS-specific environment variables
    environment.variables = mkIf cfg.enable {
      DOTFILES_PLATFORM = "darwin";
      DOTFILES_INTEGRATION = "true";
    };
    
    # macOS system defaults for development
    system.defaults = mkIf (config ? system.defaults) {
      # Finder settings
      finder = {
        ShowPathbar = mkDefault true;
        ShowStatusBar = mkDefault true;
      };
      
      # Dock settings for development
      dock = {
        autohide = mkDefault true;
        show-recents = mkDefault false;
      };
    };
    
    # Platform-specific warnings
    warnings = flatten [
      (optional (cfg.modules.development.docker && !config ? homebrew)
        "Docker module is enabled but Homebrew is not configured. Docker Desktop installation may fail.")
    ];
    
    # macOS-specific shell configurations
    programs.zsh = mkIf cfg.modules.core.shell {
      # Ensure zsh is properly configured on macOS
      enable = mkDefault true;
    };
  };
}