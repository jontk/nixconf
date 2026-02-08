{ config, lib, pkgs, ... }:

with lib;

{
  # Dotfiles integration configuration for user jontk
  modules.dotfilesIntegration = {
    enable = true;
    
    # Use developer profile as the base
    profile = "developer";
    
    # Integration mode
    mode = "merge";
    
    # User-specific module overrides
    modules = {
      # Core modules - all enabled by developer profile
      core = {
        # Inherits from developer profile
      };
      
      # Development modules - customize as needed
      development = {
        # Add rust support
        rust = true;
        # Add kubernetes for cloud development
        kubernetes = true;
      };
    };
    
    # Module-specific priority configurations
    priorityMode = {
      shell = "dotfiles";   # Use portable dotfiles shell config
      git = "dotfiles";     # Use portable dotfiles git config
      tmux = "dotfiles";    # Use dotfiles tmux config completely
      editors = "dotfiles"; # Use portable dotfiles editor config
    };
  };
  
  # Additional user-specific dotfiles settings
  home.sessionVariables = {
    DOTFILES_USER = "jontk";
    DOTFILES_PROFILE = "developer";
  };
}