# This module is meant to be imported within home-manager context
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  dependencyResolver = import ./dependency-resolver.nix { inherit lib; };
  
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
  
  # Build enabledModules from Nix configuration with dependency resolution
  enabledModules = 
    let
      allModules = [ "shell" "git" "tmux" "editors" "docker" "golang" "python" "nodejs" "rust" "kubernetes" "claude" ];
      initialEnabled = filter getModuleStatus allModules;
      initialEnabledSet = listToAttrs (map (name: nameValuePair name { enabled = "enabled"; }) initialEnabled);
      
      # Auto-resolve dependencies if YAML structure is available
      resolvedConfig = 
        if yamlStructure != null then
          dependencyResolver.autoResolveDependencies {
            userModules = initialEnabledSet;
            inherit yamlStructure;
            platform = if pkgs.stdenv.isDarwin then "macos" else "linux";
          }
        else
          { resolvedModules = initialEnabledSet; autoEnabledModules = {}; changesApplied = false; };
      
      # Extract final enabled modules
      finalEnabled = filterAttrs (name: config: 
        config.enabled == "enabled" || config.enabled == "auto"
      ) resolvedConfig.resolvedModules;
      
      # Log auto-enabled modules
      _ = if resolvedConfig.changesApplied then
        trace "Auto-enabled module dependencies: ${concatStringsSep ", " (attrNames resolvedConfig.autoEnabledModules)}" null
      else null;
      
    in
    mapAttrs (name: _: true) finalEnabled;
in
{
  imports = [
    ./user-options.nix
  ] ++ (if cfg.enable then [
    ({ config, lib, pkgs, inputs, ... }: {
      imports = [
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
      _module.args = {
        userDotfilesConfig = cfg;
        inherit enabledModules yamlStructure;
      };
    })
  ] else []);
}