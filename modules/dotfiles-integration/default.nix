{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  dotfilesInput = inputs.dotfiles;
in
{
  imports = [ 
    ./modules.nix
    ./profiles.nix
  ];
  
  options.modules.dotfilesIntegration = {
    enable = mkEnableOption "dotfiles integration";
    
    mode = mkOption {
      type = types.enum [ "merge" "override" "separate" ];
      default = "merge";
      description = ''
        Integration mode for dotfiles:
        - merge: Merge dotfiles with existing configuration
        - override: Dotfiles take precedence over existing configuration
        - separate: Keep dotfiles configuration separate
      '';
    };
    
    modules = {
      core = {
        shell = mkEnableOption "shell configuration integration" // { default = true; };
        git = mkEnableOption "git configuration integration" // { default = true; };
        tmux = mkEnableOption "tmux configuration integration" // { default = true; };
        editors = mkEnableOption "editor configuration integration" // { default = true; };
      };
      
      development = {
        docker = mkEnableOption "docker configuration integration";
        golang = mkEnableOption "golang configuration integration";
        python = mkEnableOption "python configuration integration";
        nodejs = mkEnableOption "nodejs configuration integration";
        rust = mkEnableOption "rust configuration integration";
        kubernetes = mkEnableOption "kubernetes configuration integration";
      };
    };
    
    profile = mkOption {
      type = types.enum [ "minimal" "developer" "full" "custom" ];
      default = "developer";
      description = ''
        Profile preset to use:
        - minimal: Only essential dotfiles
        - developer: Common development tools
        - full: All available modules
        - custom: Manual module selection
      '';
    };
    
    user = mkOption {
      type = types.str;
      default = config.users.defaultUser or "jontk";
      description = "User to apply dotfiles configuration to";
    };
    
    priorityMode = mkOption {
      type = types.attrsOf (types.enum [ "merge" "override" "nixconf" "dotfiles" ]);
      default = {};
      example = {
        shell = "merge";
        git = "dotfiles";
        tmux = "nixconf";
      };
      description = ''
        Per-module priority configuration:
        - merge: Combine configurations
        - override: Module-specific override
        - nixconf: Use nixconf configuration
        - dotfiles: Use dotfiles configuration
      '';
    };
    
    dotfilesPath = mkOption {
      type = types.path;
      default = dotfilesInput;
      description = "Path to the dotfiles repository";
    };
  };
  
  config = mkIf cfg.enable (mkMerge [
    {
      # Apply profile presets
      modules.dotfilesIntegration.modules = mkMerge [
        (mkIf (cfg.profile == "minimal") {
          core.shell = true;
          core.git = true;
        })
        
        (mkIf (cfg.profile == "developer") {
          core = {
            shell = true;
            git = true;
            tmux = true;
            editors = true;
          };
          development = {
            docker = true;
            golang = true;
            python = true;
            nodejs = true;
          };
        })
        
        (mkIf (cfg.profile == "full") {
          core = {
            shell = true;
            git = true;
            tmux = true;
            editors = true;
          };
          development = {
            docker = true;
            golang = true;
            python = true;
            nodejs = true;
            rust = true;
            kubernetes = true;
          };
        })
      ];
    }
  ]);
}