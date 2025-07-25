{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for git module
  priorityMode = cfg.priorityMode.git or cfg.mode;
  
  # Read git module configuration from module.yml
  gitModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/git/module.yml";
  
  # Use default settings for now
  profileSettings = gitModuleConfig.settings;
  
  # Git configuration files from dotfiles
  gitconfigFile = "${dotfilesPath}/modules/git/gitconfig";
  gitAliasesFile = "${dotfilesPath}/modules/git/git_aliases";
  gitignoreFile = "${dotfilesPath}/modules/git/gitignore_global";
  
  # Parse git aliases file
  parseGitAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          # Git aliases are in format: alias_name = command
          parts = splitString " = " line;
        in
        if length parts == 2 then
          { name = elemAt parts 0; value = elemAt parts 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse git aliases
  dotfilesGitAliases = 
    if builtins.pathExists gitAliasesFile then
      parseGitAliases (builtins.readFile gitAliasesFile)
    else
      {};
  
  # Read gitignore patterns
  gitignorePatterns = 
    if builtins.pathExists gitignoreFile then
      splitString "\n" (builtins.readFile gitignoreFile)
    else
      [];
  
  # Merge git aliases based on priority mode
  mergeGitAliases = existing: dotfiles:
    if priorityMode == "nixconf" then existing
    else if priorityMode == "dotfiles" || priorityMode == "override" then dotfiles
    else if priorityMode == "merge" then existing // dotfiles
    else existing;  # separate mode
in
{
  config = mkIf (cfg.enable && (cfg.modules.core.git or true)) {
    # Only configure if we're in home-manager context
    programs.git = {
      enable = true;
      
      # User configuration (let user set these in their config)
      userName = mkDefault config.programs.git.userName or null;
      userEmail = mkDefault config.programs.git.userEmail or null;
      
      # Git aliases
      aliases = mkIf (priorityMode != "separate")
        dotfilesGitAliases;
      
      # Global gitignore
      ignores = mkIf (priorityMode != "nixconf")
        gitignorePatterns;
      
      # Extra configuration
      extraConfig = mkMerge [
        # Existing extra config
        # Skip existing config to avoid recursion
        
        # Core settings from dotfiles gitconfig
        (mkIf (priorityMode != "nixconf" && priorityMode != "separate" && builtins.pathExists gitconfigFile)
          (let
            # Extract key git settings from gitconfig
            # This is a simplified approach - in a real implementation, we'd parse the INI format
          in {
            core = {
              editor = mkDefault "vim";
              whitespace = mkDefault "trailing-space,space-before-tab";
              autocrlf = mkDefault "input";
              filemode = mkDefault true;
            };
            
            init = {
              defaultBranch = mkDefault "main";
            };
            
            pull = {
              rebase = mkDefault true;
            };
            
            push = {
              default = mkDefault "current";
              autoSetupRemote = mkDefault true;
            };
            
            merge = {
              ff = mkDefault false;
              tool = mkDefault "vimdiff";
            };
            
            diff = {
              colorMoved = mkDefault "default";
              algorithm = mkDefault "patience";
            };
            
            color = {
              ui = mkDefault "auto";
              diff = mkDefault "auto";
              status = mkDefault "auto";
              branch = mkDefault "auto";
            };
            
            rerere = {
              enabled = mkDefault true;
            };
          }))
        
        # For separate mode, include the gitconfig path
        (mkIf (priorityMode == "separate")
          {
            include = {
              path = gitconfigFile;
            };
          })
      ];
    };
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_GIT_MODULE = "active";
      DOTFILES_GIT_VERSION = gitModuleConfig.version or "unknown";
    };
  };
}