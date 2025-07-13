{ config, pkgs, lib, ... }:

{
  # NixOS-specific configuration will be implemented here
  
  # System state version
  system.stateVersion = "25.05";
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Hardware configuration will be imported
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/development
    ../../modules/desktop
    ../../modules/remote-access
  ];
  
  # Enable NetworkManager
  networking.networkmanager.enable = true;
  
  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jontk = import ../../users/jontk;
  };
}