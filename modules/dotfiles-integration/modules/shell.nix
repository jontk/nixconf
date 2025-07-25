{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for shell module
  priorityMode = cfg.priorityMode.shell or cfg.mode;
  
  # Read shell module configuration from module.yml
  shellModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/shell/module.yml";
  
  # Use default settings for now
  profileSettings = shellModuleConfig.settings;
  
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
  
  # Merge configurations based on priority mode
  mergeAliases = existing: dotfiles:
    if priorityMode == "nixconf" then existing
    else if priorityMode == "dotfiles" || priorityMode == "override" then dotfiles
    else if priorityMode == "merge" then existing // dotfiles
    else existing;  # separate mode
in
{
  config = mkIf (cfg.enable && (cfg.modules.core.shell or true)) {
    programs = {
      # Bash configuration
      bash = {
        enable = true;
        
        shellAliases = mkIf (priorityMode != "separate" && profileSettings.enable_aliases or true) 
          dotfilesAliases;
        
        initExtra = mkMerge [
          # Existing init content
          # Skip existing content for now to avoid recursion
          
          # Add shell functions from dotfiles
          (mkIf (priorityMode != "nixconf" && priorityMode != "separate" && profileSettings.enable_functions or true)
            ''
              # Dotfiles shell functions
              ${shellFunctions}
            '')
          
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
          # Existing init content
          # Skip existing content for now to avoid recursion
          
          # Add shell functions from dotfiles
          (mkIf (priorityMode != "nixconf" && priorityMode != "separate" && profileSettings.enable_functions or true)
            ''
              # Dotfiles shell functions
              ${shellFunctions}
            '')
          
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
    
    # Environment variables from dotfiles
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_INTEGRATED = "true";
      DOTFILES_MODE = priorityMode;
      DOTFILES_SHELL_MODULE = "active";
      DOTFILES_SHELL_VERSION = shellModuleConfig.version or "unknown";
    };
  };
}