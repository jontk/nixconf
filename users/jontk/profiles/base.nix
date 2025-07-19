# Base user profile - core packages and settings
{ config, pkgs, lib, ... }:

{
  # Essential packages only
  home.packages = with pkgs; [
    # Core CLI tools
    curl wget tree htop btop
    git ripgrep fd bat eza fzf
    jq yq unzip zip rsync
    
    # Development essentials
    tmux git gh delta
    docker-compose kubectl
  ];

  # Basic shell configuration
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
    };
    
    git = {
      enable = true;
      userName = "Jon Thor Kristinsson";
      userEmail = "git@jontk.com";
      
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
    
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}