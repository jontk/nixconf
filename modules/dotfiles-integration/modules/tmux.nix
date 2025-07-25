{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for tmux module
  priorityMode = cfg.priorityMode.tmux or cfg.mode;
  
  # Read tmux module configuration from module.yml
  tmuxModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/tmux/module.yml";
  
  # Use default settings for now
  profileSettings = tmuxModuleConfig.settings;
  
  # Tmux configuration files from dotfiles
  tmuxConfFile = "${dotfilesPath}/modules/tmux/tmux.conf";
  tmuxAliasesFile = "${dotfilesPath}/modules/tmux/tmux_aliases";
  
  # Read tmux configuration
  tmuxConfig = 
    if builtins.pathExists tmuxConfFile then
      builtins.readFile tmuxConfFile
    else
      "";
  
  # Parse tmux aliases
  parseTmuxAliases = content:
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
  
  # Read and parse tmux aliases
  tmuxAliases = 
    if builtins.pathExists tmuxAliasesFile then
      parseTmuxAliases (builtins.readFile tmuxAliasesFile)
    else
      {};
in
{
  config = mkIf (cfg.enable && (cfg.modules.core.tmux or true)) {
    # Tmux program configuration
    programs.tmux = {
      enable = true;
      
      # Base configuration
      baseIndex = mkDefault 1;
      clock24 = mkDefault true;
      escapeTime = mkDefault 0;
      historyLimit = mkDefault 50000;
      mouse = mkDefault true;
      terminal = mkDefault "screen-256color";
      
      # Extra configuration based on priority mode
      extraConfig = 
        if priorityMode == "dotfiles" || priorityMode == "override" then
          tmuxConfig
        else if priorityMode == "separate" then
          ''
            # Source dotfiles tmux configuration
            source-file ${tmuxConfFile}
          ''
        else
          # Default to dotfiles config
          tmuxConfig;
      
      # Plugins (if we detect TPM usage in config)
      plugins = mkIf (priorityMode != "nixconf" && (hasInfix "tpm" tmuxConfig)) (with pkgs.tmuxPlugins; [
        sensible
        yank
        pain-control
        sessionist
        continuum
        resurrect
      ]);
    };
    
    # Shell aliases for tmux
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      tmuxAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      tmuxAliases;
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_TMUX_MODULE = "active";
      DOTFILES_TMUX_VERSION = tmuxModuleConfig.version or "unknown";
    };
  };
}