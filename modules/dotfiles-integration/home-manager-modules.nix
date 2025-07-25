{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  
  # Paths to YAML configuration files
  configPath = "${inputs.dotfiles}/config";
  modulesYamlPath = "${configPath}/modules.yml";
  profilesYamlPath = "${configPath}/profiles.yml";
  enabledModulesYamlPath = "${configPath}/enabled-modules.yml";
  
  # Parse YAML configurations
  modulesConfig = yamlParser.readModulesConfig modulesYamlPath;
  profilesConfig = yamlParser.readProfilesConfig profilesYamlPath;
  enabledModulesConfig = yamlParser.readEnabledModulesConfig enabledModulesYamlPath;
  
  # Get enabled modules based on configuration
  enabledModules = yamlParser.getEnabledModules {
    inherit modulesConfig profilesConfig enabledModulesConfig;
  };
  
  dotfilesYamlConfig = {
    inherit modulesConfig profilesConfig enabledModulesConfig;
    inherit enabledModules;
    currentProfile = enabledModulesConfig.user.profile or "minimal";
  };
in
{
  # This module configures home-manager with dotfiles integration
  config = mkIf cfg.enable {
    home-manager.users.${cfg.user} = { config, lib, pkgs, ... }: {
      imports = [
        ./modules/shell.nix
        ./modules/git.nix
        ./modules/tmux.nix
        ./modules/editors.nix
      ];
      
      # Pass through the configuration with modules enabled based on YAML
      modules.dotfilesIntegration = cfg // {
        modules = {
          core = {
            shell = hasAttr "shell" enabledModules;
            git = hasAttr "git" enabledModules;
            tmux = hasAttr "tmux" enabledModules;
            editors = hasAttr "editors" enabledModules;
          };
          development = {
            docker = hasAttr "docker" enabledModules;
            golang = hasAttr "golang" enabledModules;
            python = hasAttr "python" enabledModules;
            nodejs = hasAttr "nodejs" enabledModules;
            rust = hasAttr "rust" enabledModules;
            kubernetes = hasAttr "kubernetes" enabledModules;
          };
        };
      };
      
      # Pass through special args
      _module.args = {
        inherit inputs dotfilesYamlConfig;
      };
    };
  };
}