{ config, pkgs, lib, ... }:

{
  # User-specific home-manager configuration
  # Will be expanded in subsequent tasks
  
  home.stateVersion = "25.05";
  
  # Basic user configuration
  home.packages = with pkgs; [
    # User packages will be added here
  ];
  
  # Git configuration placeholder
  programs.git = {
    enable = true;
    # Git config will be added here
  };
}