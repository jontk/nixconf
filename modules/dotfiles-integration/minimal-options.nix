# Minimal dotfiles options to prevent errors
{ lib, ... }:

with lib;

{
  options.dotfiles = {
    enable = mkEnableOption "dotfiles integration";
    
    user = {
      profile = mkOption {
        type = types.str;
        default = "minimal";
        description = "Profile name";
      };
      
      platform = mkOption {
        type = types.str;
        default = "auto";
        description = "Platform";
      };
      
      shell = mkOption {
        type = types.str;
        default = "auto";
        description = "Shell";
      };
    };
    
    modules = mkOption {
      type = types.attrs;
      default = {};
      description = "Module configurations";
    };
    
    priorityModes = mkOption {
      type = types.attrs;
      default = {};
      description = "Priority modes";
    };
    
    installation = mkOption {
      type = types.attrs;
      default = {};
      description = "Installation preferences";
    };
    
    logging = mkOption {
      type = types.attrs;
      default = {};
      description = "Logging configuration";
    };
  };
}