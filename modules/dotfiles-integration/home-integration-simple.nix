# This module is meant to be imported within home-manager context
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  dependencyResolver = import ./dependency-resolver.nix { inherit lib; };
in
{
  imports = [
    ./user-options.nix
    # Always import all modules - they will check if they're enabled
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/editors.nix
    ./modules/docker.nix
    ./modules/golang.nix
    ./modules/python.nix
    ./modules/nodejs.nix
    ./modules/rust.nix
    ./modules/kubernetes.nix
    ./modules/claude.nix
    ./validation-command.nix
    ./dependency-commands.nix
    ./settings-commands.nix
    ./file-commands.nix
    ./hooks-commands.nix
  ];
  
  config = mkIf (config.dotfiles.enable or false) {
    _module.args = 
      let
        cfg = config.dotfiles;
        
        # Parse YAML configurations for structure (not for enablement)
        yamlStructure = 
          if inputs ? dotfiles then
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
                    
                    baseModules = 
                      if profile.base or null != null then
                        resolveProfile profile.base
                      else
                        [];
                    
                    profileModules = profile.modules or [];
                  in
                  baseModules ++ profileModules;
                
                profileModules = resolveProfile (cfg.user.profile or "minimal");
              in
              # Check if module is in the profile's modules list
              elem moduleName profileModules
            else
              moduleConfig.autoEnable or false;
        
        # Build enabledModules from Nix configuration with dependency resolution
        enabledModules = 
          let
            allModules = [ "shell" "git" "tmux" "editors" "docker" "golang" "python" "nodejs" "rust" "kubernetes" "claude" ];
            initialEnabled = filter getModuleStatus allModules;
            initialEnabledSet = listToAttrs (map (name: nameValuePair name { enabled = "enabled"; }) initialEnabled);
            
            # Auto-resolve dependencies if YAML structure is available
            resolvedModules = 
              if yamlStructure != null && cfg.resolveDependencies or true then
                let
                  resolver = dependencyResolver.createResolver {
                    modules = yamlStructure.modulesConfig.modules;
                  };
                  resolutionResult = resolver.autoResolveDependencies {
                    enabledModules = initialEnabledSet;
                  };
                in
                if resolutionResult.success then
                  resolutionResult.resolvedModules
                else
                  initialEnabledSet
              else
                initialEnabledSet;
          in
          resolvedModules;
          
      in {
        userDotfilesConfig = cfg;
        inherit enabledModules yamlStructure;
      };
  };
}