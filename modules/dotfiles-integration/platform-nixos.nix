{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  isNixOS = config.system.stateVersion or null != null;
in
{
  config = mkIf (cfg.enable && isNixOS) {
    # NixOS-specific configurations
    
    # Ensure modules are available in the correct context
    warnings = optional (cfg.enable && !config ? home-manager) 
      "Dotfiles integration is enabled but home-manager is not configured. Some features may not work.";
    
    # System-level dependencies for dotfiles modules
    environment.systemPackages = with pkgs; mkIf cfg.enable (
      flatten [
        # Core tools
        (optional cfg.modules.core.shell [ bash zsh ])
        (optional cfg.modules.core.git [ git ])
        (optional cfg.modules.core.tmux [ tmux ])
        (optional cfg.modules.core.editors [ vim neovim ])
        
        # Development tools
        (optional cfg.modules.development.docker [ docker docker-compose ])
        (optional cfg.modules.development.golang [ go gopls ])
        (optional cfg.modules.development.python [ python3 python3Packages.pip ])
        (optional cfg.modules.development.nodejs [ nodejs nodePackages.npm ])
        (optional cfg.modules.development.rust [ rustc cargo ])
        (optional cfg.modules.development.kubernetes [ kubectl kubernetes-helm ])
      ]
    );
    
    # NixOS-specific module configurations
    programs = mkIf cfg.enable {
      # Enable shell programs system-wide if needed
      bash.enable = mkDefault cfg.modules.core.shell;
      zsh.enable = mkDefault cfg.modules.core.shell;
    };
    
    # Docker daemon configuration
    virtualisation.docker = mkIf (cfg.enable && cfg.modules.development.docker) {
      enable = true;
      enableOnBoot = mkDefault true;
    };
    
    # Platform-specific environment variables
    environment.variables = mkIf cfg.enable {
      DOTFILES_PLATFORM = "nixos";
      DOTFILES_INTEGRATION = "true";
    };
  };
}