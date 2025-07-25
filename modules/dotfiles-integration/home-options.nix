# Options definition for home-manager modules
{ lib, ... }:

with lib;

{
  options.modules.dotfilesIntegration = {
    enable = mkEnableOption "dotfiles integration in home-manager";
    
    mode = mkOption {
      type = types.enum [ "merge" "override" "separate" ];
      default = "merge";
      description = "Integration mode for dotfiles";
    };
    
    profile = mkOption {
      type = types.str;
      default = "minimal";
      description = "Profile to use";
    };
    
    user = mkOption {
      type = types.str;
      default = "user";
      description = "User name";
    };
    
    modules = mkOption {
      type = types.attrs;
      default = {};
      description = "Module configuration";
    };
    
    priorityMode = mkOption {
      type = types.attrs;
      default = {};
      description = "Priority mode configuration";
    };
    
    dotfilesPath = mkOption {
      type = types.path;
      default = null;
      description = "Path to dotfiles";
    };
  };
}