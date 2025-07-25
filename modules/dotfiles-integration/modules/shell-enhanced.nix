# Enhanced Shell Module with Advanced Priority Mode Support
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  priorityModes = import ../priority-modes.nix { inherit lib; };
  
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
  dotfilesFunctions = 
    if builtins.pathExists shellFunctionsFile then
      builtins.readFile shellFunctionsFile
    else
      "";
  
  # Read shell RC files
  dotfilesBashrc = 
    if builtins.pathExists bashrcFile then
      builtins.readFile bashrcFile
    else
      "";
      
  dotfilesZshrc = 
    if builtins.pathExists zshrcFile then
      builtins.readFile zshrcFile
    else
      "";
  
  # Get existing NixOS shell configuration
  existingBashAliases = config.programs.bash.shellAliases or {};
  existingZshAliases = config.programs.zsh.shellAliases or {};
  existingBashInit = config.programs.bash.initExtra or "";
  existingZshInit = config.programs.zsh.initExtra or "";
  
  # Apply priority mode to aliases
  bashAliasesResult = priorityModes.applyPriorityMode {
    nixConfig = existingBashAliases;
    dotfilesConfig = dotfilesAliases;
    priorityMode = priorityMode;
    moduleName = "shell-bash-aliases";
  };
  
  zshAliasesResult = priorityModes.applyPriorityMode {
    nixConfig = existingZshAliases;
    dotfilesConfig = dotfilesAliases;
    priorityMode = priorityMode;
    moduleName = "shell-zsh-aliases";
  };
  
  # Merge shell init content
  mergedBashInit = priorityModes.mergeShellInit existingBashInit dotfilesFunctions priorityMode;
  mergedZshInit = priorityModes.mergeShellInit existingZshInit dotfilesFunctions priorityMode;
  
  # Environment variables from dotfiles
  dotfilesEnv = {
    DOTFILES_SHELL_MODULE = "active";
    DOTFILES_SHELL_VERSION = shellModuleConfig.version or "unknown";
    DOTFILES_SHELL_PRIORITY = priorityMode;
  };
  
  # Apply priority mode to environment variables
  envResult = priorityModes.applyPriorityMode {
    nixConfig = config.home.sessionVariables or {};
    dotfilesConfig = dotfilesEnv;
    priorityMode = priorityMode;
    moduleName = "shell-environment";
  };
  
  # Log priority decisions for debugging
  _ = priorityModes.logPriorityDecision {
    moduleName = "shell";
    priorityMode = priorityMode;
    conflicts = bashAliasesResult.conflicts ++ zshAliasesResult.conflicts ++ envResult.conflicts;
    source = "enhanced";
  };
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "shell" enabledModules)) {
    
    # Session variables with enhanced merging
    home.sessionVariables = mkIf (priorityMode != "nixconf") 
      envResult.config;
    
    programs = {
      # Enhanced Bash configuration
      bash = {
        enable = true;
        
        # Apply merged aliases based on priority mode
        shellAliases = mkIf (priorityMode != "separate") 
          bashAliasesResult.config;
        
        initExtra = mkMerge [
          # Add the merged init content
          (mkIf (priorityMode != "nixconf") mergedBashInit)
          
          # Add conflict resolution info in debug mode
          (mkIf (cfg.logging.level == "debug" && bashAliasesResult.conflicts != [])
            ''
              # Dotfiles integration conflicts detected:
              ${concatMapStringsSep "\n" (c: "# - ${c.path}: nixconf='${toString c.nixValue}' vs dotfiles='${toString c.dotfilesValue}'") bashAliasesResult.conflicts}
            '')
          
          # Add bashrc content for override/dotfiles mode
          (mkIf (priorityMode == "override" || priorityMode == "dotfiles")
            ''
              # Dotfiles bashrc content
              ${dotfilesBashrc}
            '')
            
          # Separate mode: provide toggle functionality
          (mkIf (priorityMode == "separate")
            ''
              # Dotfiles integration (separate mode)
              dotfiles_toggle() {
                if [[ "$DOTFILES_SEPARATE_MODE" == "true" ]]; then
                  export DOTFILES_SEPARATE_MODE="false"
                  echo "Dotfiles integration disabled"
                else
                  export DOTFILES_SEPARATE_MODE="true"
                  echo "Dotfiles integration enabled"
                  # Source dotfiles content
                  ${dotfilesFunctions}
                fi
              }
              
              # Auto-enable if not set
              if [[ -z "$DOTFILES_SEPARATE_MODE" ]]; then
                export DOTFILES_SEPARATE_MODE="true"
              fi
              
              # Load dotfiles if enabled
              if [[ "$DOTFILES_SEPARATE_MODE" == "true" ]]; then
                ${dotfilesFunctions}
              fi
            '')
        ];
      };
      
      # Enhanced Zsh configuration
      zsh = {
        enable = true;
        
        # Apply merged aliases based on priority mode
        shellAliases = mkIf (priorityMode != "separate") 
          zshAliasesResult.config;
        
        initExtra = mkMerge [
          # Add the merged init content
          (mkIf (priorityMode != "nixconf") mergedZshInit)
          
          # Add conflict resolution info in debug mode
          (mkIf (cfg.logging.level == "debug" && zshAliasesResult.conflicts != [])
            ''
              # Dotfiles integration conflicts detected:
              ${concatMapStringsSep "\n" (c: "# - ${c.path}: nixconf='${toString c.nixValue}' vs dotfiles='${toString c.dotfilesValue}'") zshAliasesResult.conflicts}
            '')
          
          # Add zshrc content for override/dotfiles mode
          (mkIf (priorityMode == "override" || priorityMode == "dotfiles")
            ''
              # Dotfiles zshrc content
              ${dotfilesZshrc}
            '')
            
          # Separate mode: provide toggle functionality
          (mkIf (priorityMode == "separate")
            ''
              # Dotfiles integration (separate mode)
              dotfiles_toggle() {
                if [[ "$DOTFILES_SEPARATE_MODE" == "true" ]]; then
                  export DOTFILES_SEPARATE_MODE="false"
                  echo "Dotfiles integration disabled"
                else
                  export DOTFILES_SEPARATE_MODE="true"
                  echo "Dotfiles integration enabled"
                  # Source dotfiles content
                  ${dotfilesFunctions}
                fi
              }
              
              # Auto-enable if not set
              if [[ -z "$DOTFILES_SEPARATE_MODE" ]]; then
                export DOTFILES_SEPARATE_MODE="true"
              fi
              
              # Load dotfiles if enabled
              if [[ "$DOTFILES_SEPARATE_MODE" == "true" ]]; then
                ${dotfilesFunctions}
              fi
            '')
        ];
      };
    };
    
    # Additional configuration for separate mode
    home.file = mkIf (priorityMode == "separate") {
      ".config/dotfiles/shell-aliases.sh" = {
        text = ''
          # Dotfiles shell aliases (separate mode)
          ${concatStringsSep "\n" (mapAttrsToList (name: value: "alias ${name}='${value}'") dotfilesAliases)}
        '';
      };
      
      ".config/dotfiles/shell-functions.sh" = {
        text = dotfilesFunctions;
      };
    };
    
    # Provide conflict resolution commands
    home.packages = mkIf (bashAliasesResult.conflicts != [] || zshAliasesResult.conflicts != []) [
      (pkgs.writeShellScriptBin "dotfiles-conflicts" ''
        echo "Dotfiles Integration Conflicts Detected:"
        echo "========================================"
        ${concatMapStringsSep "\n" (c: ''
          echo "Path: ${c.path}"
          echo "  NixOS value: ${toString c.nixValue}"
          echo "  Dotfiles value: ${toString c.dotfilesValue}"
          echo "  Severity: ${c.severity}"
          echo ""
        '') (bashAliasesResult.conflicts ++ zshAliasesResult.conflicts)}
        
        echo "To resolve conflicts, update your priority mode settings in:"
        echo "  users/jontk/default.nix -> dotfiles.priorityModes.shell"
        echo ""
        echo "Available modes: merge, override, nixconf, dotfiles, separate"
      '')
    ];
  };
}