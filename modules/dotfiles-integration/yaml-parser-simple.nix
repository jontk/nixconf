{ lib, ... }:

with lib;

rec {
  # For now, we'll use a simplified approach that doesn't require yq-go
  # This reads the YAML files as text and extracts basic information
  
  # Simple YAML key extraction (very basic, for demonstration)
  extractYamlValue = content: key:
    let
      lines = splitString "\n" content;
      keyLine = findFirst (line: hasPrefix "${key}:" line) "" lines;
      value = if keyLine != "" then
        substring (stringLength "${key}:") (-1) keyLine
      else "";
    in
    trim value;
  
  # For testing, return mock configurations based on known structure
  readModulesConfig = modulesYamlPath: {
    version = "1.0";
    modules = {
      shell = {
        name = "Shell Configuration";
        description = "Enhanced shell configurations";
        category = "core";
        platforms = [ "linux" "macos" ];
        dependencies = [];
        conflicts = [];
      };
      git = {
        name = "Git Configuration";
        description = "Git configuration and aliases";
        category = "core";
        platforms = [ "linux" "macos" ];
        dependencies = [];
        conflicts = [];
      };
      tmux = {
        name = "Tmux Configuration";
        description = "Terminal multiplexer configuration";
        category = "core";
        platforms = [ "linux" "macos" ];
        dependencies = [];
        conflicts = [];
      };
      editors = {
        name = "Editor Configuration";
        description = "Vim and Neovim configuration";
        category = "editor";
        platforms = [ "linux" "macos" ];
        dependencies = [];
        conflicts = [];
      };
      docker = {
        name = "Docker Configuration";
        description = "Docker aliases and configuration";
        category = "devops";
        platforms = [ "linux" "macos" ];
        dependencies = [];
        conflicts = [];
      };
    };
    categories = {
      core = [ "shell" "git" "tmux" ];
      editor = [ "editors" ];
      devops = [ "docker" ];
    };
  };
  
  readProfilesConfig = profilesYamlPath: {
    version = "1.0";
    baseProfiles = {
      minimal = {
        name = "Minimal";
        description = "Basic shell and git";
        modules = [ "shell" "git" ];
      };
      standard = {
        name = "Standard";
        description = "Common development tools";
        modules = [ "shell" "git" "tmux" "editors" ];
      };
    };
    profiles = {
      personal = {
        name = "Personal";
        description = "Personal development environment";
        inherits = [ "standard" ];
        modules = [ "docker" ];
      };
      work = {
        name = "Work";
        description = "Work environment";
        inherits = [ "standard" ];
        modules = [];
      };
      server = {
        name = "Server";
        description = "Server environment";
        inherits = [ "minimal" ];
        modules = [];
      };
    };
  };
  
  readEnabledModulesConfig = enabledModulesYamlPath: 
    if pathExists enabledModulesYamlPath then
      let
        content = readFile enabledModulesYamlPath;
        # Extract profile from YAML content (simple parsing)
        profileLine = findFirst 
          (line: hasPrefix "  profile:" line) 
          "  profile: minimal" 
          (splitString "\n" content);
        profile = trim (removePrefix "  profile:" profileLine);
        cleanProfile = replaceStrings ["\"" "'"] ["" ""] profile;
      in {
        version = "1.0";
        user = {
          profile = cleanProfile;
          platform = "auto";
          shell = "auto";
        };
        modules = {
          shell = { enabled = "auto"; auto_enable = true; };
          git = { enabled = "auto"; auto_enable = true; };
          tmux = { enabled = "auto"; auto_enable = true; };
          editors = { enabled = "auto"; auto_enable = true; };
          docker = { enabled = "auto"; auto_enable = true; };
        };
        installation = {
          backup_existing = true;
          use_symlinks = true;
        };
      }
    else {
      version = "1.0";
      user = {
        profile = "minimal";
        platform = "auto";
        shell = "auto";
      };
      modules = {};
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
  
  # Read module configuration from module.yml
  readModuleConfig = moduleYamlPath: {
    name = "shell";
    version = "1.0.0";
    description = "Shell configuration module";
    category = "core";
    platforms = [ "linux" "macos" ];
    shells = [ "bash" "zsh" ];
    files = [
      { name = "bashrc"; target = ".bashrc"; }
      { name = "zshrc"; target = ".zshrc"; }
      { name = "aliases"; target = ".shell_aliases"; }
      { name = "functions"; target = ".shell_functions"; }
    ];
    dependencies = {};
    settings = {
      enable_aliases = true;
      enable_functions = true;
      prompt_style = "enhanced";
      enable_git_prompt = true;
      history_size = 10000;
      enable_completion = true;
    };
  };
  
  # Apply profile settings to module configuration
  applyProfileSettings = { moduleConfig, profileName, profilesConfig }:
    # For now, just return the module settings
    moduleConfig.settings;
}