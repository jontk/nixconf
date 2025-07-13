{ config, pkgs, lib, ... }:

{
  # macOS-specific configuration will be implemented here
  
  # Enable nix-darwin
  system.stateVersion = 4;
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Basic system configuration placeholder
  system.defaults = {
    # System defaults will be configured here
  };
  
  # Import common modules
  imports = [
    ../../modules/common
    ../../modules/development
  ];
  
  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jontk = import ../../users/jontk;
  };
}