{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  dotfilesPath = cfg.dotfilesPath;
  
  # YAML parsing function using yq
  parseYaml = file: 
    if builtins.pathExists file then
      builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommand "yaml-to-json" {} ''
            ${pkgs.yq-go}/bin/yq eval -o=json '.' ${file} > $out
          ''
        )
      )
    else
      {};
  
  # Example YAML configuration structure
  # This would normally be read from dotfiles YAML files
  exampleYamlConfig = {
    modules = {
      shell = {
        enabled = true;
        priority = "merge";
        config = {
          aliases = {
            ll = "ls -la";
            gs = "git status";
          };
          environment = {
            EDITOR = "vim";
            PAGER = "less";
          };
        };
      };
      git = {
        enabled = true;
        priority = "dotfiles";
        config = {
          user = {
            name = "Jon TK";
            email = "git@jontk.com";
          };
          aliases = {
            co = "checkout";
            br = "branch";
            ci = "commit";
            st = "status";
          };
        };
      };
    };
    profiles = {
      developer = {
        description = "Developer profile with common tools";
        modules = [ "shell" "git" "tmux" "editors" "docker" "golang" "python" "nodejs" ];
      };
    };
  };
  
  # Helper to convert YAML module config to Nix module config
  yamlToNixModule = moduleName: moduleConfig:
    if moduleConfig.enabled or false then
      {
        enable = true;
        priority = moduleConfig.priority or cfg.mode;
        settings = moduleConfig.config or {};
      }
    else
      {
        enable = false;
      };
  
  # Helper to apply YAML configuration overrides
  applyYamlOverrides = yamlConfig:
    let
      moduleOverrides = mapAttrs yamlToNixModule (yamlConfig.modules or {});
    in
    moduleOverrides;
in
{
  options.modules.dotfilesIntegration.yamlConfig = {
    enable = mkEnableOption "YAML configuration support";
    
    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to YAML configuration file";
      example = "/home/user/dotfiles/config.yaml";
    };
    
    autoDiscover = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically discover YAML config files in dotfiles";
    };
  };
  
  config = mkIf (cfg.enable && cfg.yamlConfig.enable) {
    # This would normally parse and apply YAML configurations
    # For now, it's a placeholder structure
    warnings = optional (cfg.yamlConfig.configFile != null && !builtins.pathExists cfg.yamlConfig.configFile)
      "YAML config file ${toString cfg.yamlConfig.configFile} does not exist";
  };
  
  # Export YAML parsing utilities
  _module.args.yamlUtils = {
    inherit parseYaml;
    inherit yamlToNixModule;
    inherit applyYamlOverrides;
  };
}