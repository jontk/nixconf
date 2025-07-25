{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  platformDetection = import ../platform-detection.nix { inherit lib pkgs; };
  settingsParser = import ../settings-parser.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for shell module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.shell or "merge"
    else
      "merge";
  
  # Read shell module configuration from module.yml
  shellModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/shell/module.yml";
  
  # Get platform information
  platformInfo = platformDetection.getPlatformInfo;
  currentPlatform = platformDetection.detectPlatform;
  
  # Apply platform-specific settings to module config
  platformShellConfig = platformDetection.applyPlatformSettings {
    moduleConfig = shellModuleConfig;
    platform = currentPlatform;
  };
  
  # Validate platform compatibility
  platformValidation = platformDetection.validatePlatformCompatibility {
    moduleConfig = platformShellConfig;
    platform = currentPlatform;
  };
  
  # Parse and apply module settings
  settingDefinitions = settingsParser.parseModuleSettings platformShellConfig;
  
  # Apply profile-specific settings
  profileShellConfig = settingsParser.applyProfileSettings {
    moduleConfig = platformShellConfig;
    profile = cfg.user.profile or "default";
  };
  
  # Get user overrides from Nix configuration
  userOverrides = cfg.modules.shell.settings or {};
  
  # Apply user overrides to module settings
  overrideResult = settingsParser.applyUserOverrides {
    moduleSettings = profileShellConfig.settings;
    userOverrides = userOverrides;
  };
  
  # Final settings after all processing
  profileSettings = overrideResult.settings;
  
  # Generate configuration from settings
  settingsConfig = settingsParser.generateConfigFromSettings {
    moduleConfig = profileShellConfig;
    settings = profileSettings;
    platform = currentPlatform;
  };
  
  # Validate settings
  settingsValidation = settingsParser.validateSettings {
    settings = profileSettings;
    settingDefinitions = settingDefinitions;
  };
  
  # Get file paths from module configuration
  getFilePath = fileName:
    let
      fileConfig = findFirst (f: f.name == fileName) {} shellModuleConfig.files;
    in
    "${dotfilesPath}/modules/shell/${fileName}";
  
  # Read shell configuration files from dotfiles
  shellAliasesFile = getFilePath "aliases";
  shellFunctionsFile = getFilePath "functions";
  bashrcFile = getFilePath "bashrc";
  zshrcFile = getFilePath "zshrc";
  
  # Parse aliases from the aliases file
  parseAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          match = builtins.match "alias ([^=]+)='([^']+)'.*" line;
        in
        if match != null then
          { name = elemAt match 0; value = elemAt match 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse dotfiles aliases
  dotfilesAliases = 
    if builtins.pathExists shellAliasesFile then
      parseAliases (builtins.readFile shellAliasesFile)
    else
      {};
  
  # Read functions file
  shellFunctions = 
    if builtins.pathExists shellFunctionsFile then
      builtins.readFile shellFunctionsFile
    else
      "";
  
  # Read profile-specific functions if they exist
  profileFunctionsFile = getFilePath "functions_${cfg.user.profile or "default"}";
  profileFunctions = 
    if builtins.pathExists profileFunctionsFile then
      builtins.readFile profileFunctionsFile
    else
      "";
  
  # Generate custom prompt based on settings
  generateCustomPrompt = 
    let
      promptTheme = profileSettings.shell_theme or "default";
      customPrompt = profileSettings.custom_prompt or "default";
      enableGitPrompt = profileSettings.enable_git_prompt or true;
      enableTimePrompt = profileSettings.enable_time_prompt or false;
    in
    if customPrompt == "minimal" then ''
      # Minimal prompt configuration
      export PS1='\u@\h:\w$ '
    ''
    else if customPrompt == "powerline" then ''
      # Powerline-style prompt
      if command -v starship >/dev/null 2>&1; then
        eval "$(starship init bash)"
      else
        export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ '
      fi
    ''
    else if customPrompt == "git-aware" then ''
      # Git-aware prompt
      ${if enableGitPrompt then ''
        if command -v git >/dev/null 2>&1; then
          parse_git_branch() {
            git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
          }
          export PS1='\u@\h:\w$(parse_git_branch)$ '
        else
          export PS1='\u@\h:\w$ '
        fi
      '' else ''
        export PS1='\u@\h:\w$ '
      ''}
    ''
    else ''
      # Default prompt
      export PS1='\u@\h:\w$ '
    '';
  
  # Generate shell initialization based on settings
  generateShellInit = shell:
    let
      enableCustomPrompt = profileSettings.enable_prompt or true;
      enableHistory = profileSettings.enable_history or true;
      historySize = profileSettings.history_size or 10000;
      enableCompletion = profileSettings.enable_completion or true;
    in
    ''
      # Shell-specific initialization for ${shell}
      ${if enableHistory then ''
        # History configuration
        export HISTSIZE=${toString historySize}
        export HISTFILESIZE=${toString historySize}
        ${if shell == "bash" then ''
          export HISTCONTROL=ignoreboth:erasedups
          shopt -s histappend
        '' else if shell == "zsh" then ''
          export HISTFILE="$HOME/.zsh_history"
          setopt HIST_VERIFY
          setopt SHARE_HISTORY
          setopt APPEND_HISTORY
          setopt INC_APPEND_HISTORY
          setopt HIST_IGNORE_DUPS
          setopt HIST_IGNORE_ALL_DUPS
          setopt HIST_SAVE_NO_DUPS
        '' else ""}
      '' else ""}
      
      ${if enableCompletion then ''
        # Enable completion
        ${if shell == "bash" then ''
          if [ -f /etc/bash_completion ]; then
            . /etc/bash_completion
          fi
        '' else if shell == "zsh" then ''
          autoload -Uz compinit
          compinit
        '' else ""}
      '' else ""}
      
      ${if enableCustomPrompt then generateCustomPrompt else ""}
      
      # Load shell functions
      ${if profileSettings.enable_functions or true then ''
        # Core shell functions
        ${shellFunctions}
        
        # Profile-specific functions
        ${profileFunctions}
      '' else ""}
    '';
  
  # Generate platform-specific aliases and environment
  platformAliases = platformDetection.generatePlatformAliases { platform = currentPlatform; };
  platformEnvironment = platformDetection.generatePlatformEnvironment { platform = currentPlatform; };
  platformShellInit = platformDetection.generatePlatformShellInit { platform = currentPlatform; };
  
  # Merge dotfiles aliases with platform-specific aliases
  allAliases = dotfilesAliases // platformAliases;
  
  # Merge configurations based on priority mode
  mergeAliases = existing: dotfiles:
    if priorityMode == "nixconf" then existing
    else if priorityMode == "dotfiles" || priorityMode == "override" then dotfiles
    else if priorityMode == "merge" then existing // dotfiles
    else existing;  # separate mode
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "shell" enabledModules)) {
    # Platform-specific and settings-based environment variables
    home.sessionVariables = mkMerge [
      (mkIf (priorityMode != "nixconf" && platformValidation.isSupported) 
        platformEnvironment)
      
      # Environment variables from module settings
      (mkIf (settingsValidation.isValid)
        settingsConfig.environment)
      
      # Dotfiles integration status variables
      (mkIf (priorityMode != "nixconf") {
        DOTFILES_INTEGRATED = "true";
        DOTFILES_MODE = priorityMode;
        DOTFILES_SHELL_MODULE = "active";
        DOTFILES_SHELL_VERSION = shellModuleConfig.version or "unknown";
        DOTFILES_SHELL_SETTINGS_VALID = toString settingsValidation.isValid;
        DOTFILES_SHELL_USER_OVERRIDES = toString overrideResult.hasOverrides;
      })
    ];
    
    programs = {
      # Bash configuration
      bash = {
        enable = true;
        
        shellAliases = mkIf (priorityMode != "separate" && profileSettings.enable_aliases or true) 
          allAliases;
        
        initExtra = mkMerge [
          # Enhanced shell initialization
          (mkIf (priorityMode != "nixconf")
            (generateShellInit "bash"))
          
          # Platform-specific initialization
          (mkIf (priorityMode != "nixconf" && platformValidation.isSupported)
            platformShellInit)
          
          # For separate mode, source files directly
          (mkIf (priorityMode == "separate")
            ''
              # Source dotfiles separately
              if [ -f "${shellAliasesFile}" ]; then
                source "${shellAliasesFile}"
              fi
              if [ -f "${shellFunctionsFile}" ]; then
                source "${shellFunctionsFile}"
              fi
              if [ -f "${profileFunctionsFile}" ]; then
                source "${profileFunctionsFile}"
              fi
            '')
          
          # Add custom bashrc content for override/dotfiles mode
          (mkIf (priorityMode == "override" || priorityMode == "dotfiles")
            (if builtins.pathExists bashrcFile then
              ''
                # Dotfiles bashrc content
                ${builtins.readFile bashrcFile}
              ''
            else ""))
        ];
      };
      
      # Zsh configuration
      zsh = {
        enable = true;
        
        shellAliases = mkIf (priorityMode != "separate" && profileSettings.enable_aliases or true)
          dotfilesAliases;
        
        initExtra = mkMerge [
          # Enhanced shell initialization
          (mkIf (priorityMode != "nixconf")
            (generateShellInit "zsh"))
          
          # Platform-specific initialization for zsh
          (mkIf (priorityMode != "nixconf" && platformValidation.isSupported)
            platformShellInit)
          
          # For separate mode, source files directly
          (mkIf (priorityMode == "separate")
            ''
              # Source dotfiles separately
              if [ -f "${shellAliasesFile}" ]; then
                source "${shellAliasesFile}"
              fi
              if [ -f "${shellFunctionsFile}" ]; then
                source "${shellFunctionsFile}"
              fi
              if [ -f "${profileFunctionsFile}" ]; then
                source "${profileFunctionsFile}"
              fi
            '')
          
          # Add custom zshrc content for override/dotfiles mode
          (mkIf (priorityMode == "override" || priorityMode == "dotfiles")
            (if builtins.pathExists zshrcFile then
              ''
                # Dotfiles zshrc content
                ${builtins.readFile zshrcFile}
              ''
            else ""))
        ];
      };
    };
    
    # Merge all environment variables into the existing home.sessionVariables above
  };
}