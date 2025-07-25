# Simplified home-manager integration for dotfiles
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.dotfiles;
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  
  # Parse YAML configurations for structure (not for enablement)
  yamlStructure = 
    if cfg.enable && inputs ? dotfiles then
      let
        # Paths to YAML configuration files
        configPath = "${inputs.dotfiles}/config";
        modulesYamlPath = "${configPath}/modules.yml";
        profilesYamlPath = "${configPath}/profiles.yml";
        
        # Parse YAML configurations for structure only
        modulesConfig = yamlParser.readModulesConfig modulesYamlPath;
        profilesConfig = yamlParser.readProfilesConfig profilesYamlPath;
      in {
        inherit modulesConfig profilesConfig;
        currentProfile = cfg.user.profile;
      }
    else null;
  
  # Determine which modules are enabled based on Nix configuration
  getModuleStatus = moduleName:
    let
      moduleConfig = cfg.modules.${moduleName} or null;
    in
    if moduleConfig == null then false
    else if moduleConfig.enabled == "enabled" then true
    else if moduleConfig.enabled == "disabled" then false
    else # "auto" mode
      if yamlStructure != null then
        let
          # Resolve profile inheritance to determine auto-enablement
          resolveProfile = profileName:
            let
              profile = 
                if hasAttr profileName yamlStructure.profilesConfig.profiles then
                  yamlStructure.profilesConfig.profiles.${profileName}
                else if hasAttr profileName yamlStructure.profilesConfig.baseProfiles then
                  yamlStructure.profilesConfig.baseProfiles.${profileName}
                else
                  { modules = []; };
              
              parentModules = 
                if profile ? inherits then
                  flatten (map resolveProfile profile.inherits)
                else
                  [];
            in
            parentModules ++ (profile.modules or []);
          
          profileModules = unique (resolveProfile cfg.user.profile);
        in
        elem moduleName profileModules
      else
        moduleConfig.autoEnable or false;
  
  # Build enabledModules from Nix configuration
  enabledModules = 
    let
      allModules = [ "shell" "git" "tmux" "editors" "docker" "golang" "python" "nodejs" "rust" "kubernetes" ];
      enabledList = filter getModuleStatus allModules;
    in
    listToAttrs (map (name: nameValuePair name true) enabledList);
in
{
  imports = [
    ./user-options.nix
  ] ++ lib.optionals cfg.enable [
    (import ./modules/shell.nix { 
      inherit config lib pkgs inputs; 
      userDotfilesConfig = cfg; 
      inherit enabledModules yamlStructure; 
    })
    (import ./modules/git.nix { 
      inherit config lib pkgs inputs; 
      userDotfilesConfig = cfg; 
      inherit enabledModules yamlStructure; 
    })
    (import ./modules/tmux.nix { 
      inherit config lib pkgs inputs; 
      userDotfilesConfig = cfg; 
      inherit enabledModules yamlStructure; 
    })
    (import ./modules/editors.nix { 
      inherit config lib pkgs inputs; 
      userDotfilesConfig = cfg; 
      inherit enabledModules yamlStructure; 
    })
  ];
}