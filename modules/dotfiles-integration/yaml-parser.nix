{ lib, pkgs, ... }:

with lib;

rec {
  # Parse YAML file to Nix data structure
  parseYAML = yamlFile:
    let
      # Use pkgs.runCommand to parse YAML at evaluation time
      jsonOutput = pkgs.runCommand "parse-yaml-${baseNameOf yamlFile}" {
        nativeBuildInputs = [ pkgs.yq-go ];
      } ''
        ${pkgs.yq-go}/bin/yq eval -o=json '.' ${yamlFile} > $out
      '';
      jsonContent = builtins.readFile jsonOutput;
    in
    builtins.fromJSON jsonContent;
  
  # Read modules.yml and extract module definitions
  readModulesConfig = modulesYamlPath:
    let
      config = parseYAML modulesYamlPath;
    in
    {
      inherit (config) version;
      modules = config.modules or {};
      categories = config.categories or {};
      platforms = config.platforms or {};
      presets = config.presets or {};
    };
  
  # Read profiles.yml and extract profile definitions
  readProfilesConfig = profilesYamlPath:
    let
      config = parseYAML profilesYamlPath;
    in
    {
      inherit (config) version;
      baseProfiles = config.base_profiles or {};
      profiles = config.profiles or {};
      inheritance = config.inheritance or {};
      environmentVariables = config.environment_variables or {};
      validation = config.validation or {};
    };
  
  # Read enabled-modules.yml and extract current configuration
  readEnabledModulesConfig = enabledModulesYamlPath:
    let
      config = parseYAML enabledModulesYamlPath;
    in
    {
      inherit (config) version;
      user = config.user or {};
      modules = config.modules or {};
      dependencies = config.dependencies or {};
      conflicts = config.conflicts or {};
      installation = config.installation or {};
      logging = config.logging or {};
      metadata = config.metadata or {};
    };
  
  # Get enabled modules based on profile
  getEnabledModules = { modulesConfig, profilesConfig, enabledModulesConfig }:
    let
      currentProfile = enabledModulesConfig.user.profile or "minimal";
      
      # Recursively resolve profile inheritance
      resolveProfile = profileName:
        let
          profile = 
            if hasAttr profileName profilesConfig.profiles then
              profilesConfig.profiles.${profileName}
            else if hasAttr profileName profilesConfig.baseProfiles then
              profilesConfig.baseProfiles.${profileName}
            else
              { modules = []; };
          
          parentModules = 
            if profile ? inherits then
              flatten (map resolveProfile profile.inherits)
            else
              [];
        in
        parentModules ++ (profile.modules or []);
      
      # Get all modules from the profile inheritance chain
      profileModules = unique (resolveProfile currentProfile);
      
      # Check if a module is explicitly enabled/disabled
      isExplicitlySet = moduleName:
        hasAttr moduleName enabledModulesConfig.modules &&
        enabledModulesConfig.modules.${moduleName}.enabled != "auto";
      
      # Get final module status
      getModuleStatus = moduleName:
        if isExplicitlySet moduleName then
          enabledModulesConfig.modules.${moduleName}.enabled == "enabled"
        else
          elem moduleName profileModules;
    in
    filterAttrs (n: v: getModuleStatus n) modulesConfig.modules;
  
  # Get module configuration from module.yml
  readModuleConfig = moduleYamlPath:
    let
      config = parseYAML moduleYamlPath;
    in
    {
      name = config.name or "unknown";
      version = config.version or "1.0.0";
      description = config.description or "";
      category = config.category or "misc";
      platforms = config.platforms or [ "linux" "macos" ];
      shells = config.shells or [ "bash" "zsh" ];
      files = config.files or [];
      dependencies = config.dependencies or {};
      settings = config.settings or {};
      platformSettings = config.platform_settings or {};
      profileSettings = config.profile_settings or {};
      installation = config.installation or {};
      documentation = config.documentation or {};
    };
  
  # Apply profile settings to module configuration
  applyProfileSettings = { moduleConfig, profileName, profilesConfig }:
    let
      getProfileSettings = pName:
        let
          profile = 
            if hasAttr pName profilesConfig.profiles then
              profilesConfig.profiles.${pName}
            else if hasAttr pName profilesConfig.baseProfiles then
              profilesConfig.baseProfiles.${pName}
            else
              {};
        in
        profile.settings or {};
      
      # Get settings for the current profile
      profileSettings = getProfileSettings profileName;
      
      # Module-specific settings from the profile
      moduleSettings = 
        if hasAttr moduleConfig.name profileSettings then
          profileSettings.${moduleConfig.name}
        else
          {};
    in
    recursiveUpdate moduleConfig.settings moduleSettings;
  
  # Check module dependencies
  checkDependencies = { moduleName, enabledModules, modulesConfig }:
    let
      module = modulesConfig.modules.${moduleName} or {};
      requiredDeps = module.dependencies or [];
      
      missingDeps = filter (dep: !hasAttr dep enabledModules) requiredDeps;
    in
    {
      satisfied = length missingDeps == 0;
      missing = missingDeps;
    };
  
  # Check module conflicts
  checkConflicts = { moduleName, enabledModules, modulesConfig }:
    let
      module = modulesConfig.modules.${moduleName} or {};
      conflicts = module.conflicts or [];
      
      activeConflicts = filter (conf: hasAttr conf enabledModules) conflicts;
    in
    {
      hasConflicts = length activeConflicts > 0;
      conflictingModules = activeConflicts;
    };
}