{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  dotfilesPath = cfg.dotfilesPath;
  
  # Claude command definitions from dotfiles
  claudeCommands = {
    # Development commands
    "dev-setup" = {
      description = "Setup development environment";
      command = "echo 'Setting up development environment...'";
      dependencies = [ "git" "curl" "wget" ];
    };
    
    "project-init" = {
      description = "Initialize new project";
      command = "echo 'Initializing new project...'";
      dependencies = [ "git" ];
    };
    
    # Git workflow commands
    "git-sync" = {
      description = "Sync git repository";
      command = "git pull --rebase && git push";
      dependencies = [ "git" ];
    };
    
    "git-cleanup" = {
      description = "Clean up local git branches";
      command = "git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d";
      dependencies = [ "git" ];
    };
    
    # Docker commands
    "docker-cleanup" = {
      description = "Clean up Docker resources";
      command = "docker system prune -af";
      dependencies = [ "docker" ];
    };
    
    # System maintenance
    "system-update" = {
      description = "Update system packages";
      command = if pkgs.stdenv.isDarwin then
        "brew update && brew upgrade"
      else
        "sudo nix flake update && sudo nixos-rebuild switch";
      dependencies = [];
    };
    
    # Utility commands
    "serve" = {
      description = "Start HTTP server in current directory";
      command = "${pkgs.python3}/bin/python -m http.server 8000";
      dependencies = [];
    };
    
    "json-pretty" = {
      description = "Pretty print JSON";
      command = "${pkgs.jq}/bin/jq '.'";
      dependencies = [];
    };
  };
  
  # Helper to create command aliases
  createCommandAlias = name: cmd: {
    name = "claude-${name}";
    value = cmd.command;
  };
  
  # Helper to create command functions
  createCommandFunction = name: cmd: ''
    claude-${name}() {
      echo "Claude Command: ${cmd.description}"
      ${cmd.command}
    }
  '';
in
{
  config = mkIf (cfg.enable && config ? home) {
    # Add Claude commands as shell aliases
    programs.bash.shellAliases = mkIf (config.programs.bash.enable or false) 
      (listToAttrs (mapAttrsToList createCommandAlias claudeCommands));
    
    programs.zsh.shellAliases = mkIf (config.programs.zsh.enable or false)
      (listToAttrs (mapAttrsToList createCommandAlias claudeCommands));
    
    # Add Claude command functions to shell init
    programs.bash.initExtra = mkIf (config.programs.bash.enable or false) ''
      # Claude Commands
      ${concatStringsSep "\n" (mapAttrsToList createCommandFunction claudeCommands)}
    '';
    
    programs.zsh.initExtra = mkIf (config.programs.zsh.enable or false) ''
      # Claude Commands
      ${concatStringsSep "\n" (mapAttrsToList createCommandFunction claudeCommands)}
    '';
    
    # Ensure command dependencies are installed
    home.packages = with pkgs; unique (flatten (mapAttrsToList 
      (name: cmd: map (dep: getAttr dep pkgs) (filter (dep: hasAttr dep pkgs) cmd.dependencies))
      claudeCommands));
  };
}