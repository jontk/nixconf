{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for editors module
  priorityMode = cfg.priorityMode.editors or cfg.mode;
  
  # Read editors module configuration from module.yml
  editorsModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/editors/module.yml";
  
  # Use default settings for now
  profileSettings = editorsModuleConfig.settings;
  
  # Editor configuration files from dotfiles
  vimrcFile = "${dotfilesPath}/modules/editors/vimrc";
  nvimDir = "${dotfilesPath}/modules/editors/nvim";
  
  # Read vim configuration
  vimConfig = 
    if builtins.pathExists vimrcFile then
      builtins.readFile vimrcFile
    else
      "";
in
{
  config = mkIf (cfg.enable && (cfg.modules.core.editors or true)) {
    # Vim configuration
    programs.vim = {
      enable = true;
      
      # Extra configuration based on priority mode
      extraConfig = 
        if priorityMode == "dotfiles" || priorityMode == "override" then
          vimConfig
        else if priorityMode == "separate" then
          ''
            " Source dotfiles vimrc
            source ${vimrcFile}
          ''
        else
          # Default to dotfiles config
          vimConfig;
      
      # Common vim settings
      settings = mkIf (priorityMode != "nixconf") {
        background = mkDefault "dark";
        expandtab = mkDefault true;
        history = mkDefault 1000;
        ignorecase = mkDefault true;
        mouse = mkDefault "a";
        number = mkDefault true;
        relativenumber = mkDefault true;
        shiftwidth = mkDefault 2;
        smartcase = mkDefault true;
        tabstop = mkDefault 2;
      };
    };
    
    # Neovim configuration
    programs.neovim = {
      enable = mkDefault true;
      
      # Use vim configuration as base
      vimAlias = mkDefault true;
      viAlias = mkDefault true;
      
      # Extra configuration based on priority mode
      extraConfig = 
        if priorityMode == "dotfiles" || priorityMode == "override" then
          # Use vim config as base, plus any neovim-specific config
          ''
            " Base vim configuration
            ${vimConfig}
            
            " Neovim-specific configuration
            ${if builtins.pathExists "${nvimDir}/init.vim" then
                builtins.readFile "${nvimDir}/init.vim"
              else
                ""}
          ''
        else if priorityMode == "separate" then
          ''
            " Source dotfiles configurations
            source ${vimrcFile}
            ${if builtins.pathExists "${nvimDir}/init.vim" then
                "source ${nvimDir}/init.vim"
              else
                ""}
          ''
        else
          # Default to dotfiles config
          vimConfig;
      
      # Plugins (basic set, can be extended)
      plugins = mkIf (priorityMode != "nixconf") (with pkgs.vimPlugins; [
        # Essential plugins
        vim-sensible
        vim-surround
        vim-commentary
        vim-fugitive
        vim-gitgutter
        
        # File navigation
        nerdtree
        fzf-vim
        
        # Syntax and completion
        vim-polyglot
        coc-nvim
        
        # UI enhancements
        vim-airline
        vim-airline-themes
        gruvbox
      ]);
    };
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_EDITORS_MODULE = "active";
      DOTFILES_EDITORS_VERSION = editorsModuleConfig.version or "unknown";
      EDITOR = mkDefault (profileSettings.default_editor or "nvim");
      VISUAL = mkDefault (profileSettings.default_visual or "nvim");
    };
  };
}