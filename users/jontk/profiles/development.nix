# Development profile - programming languages and tools
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Language servers and tools
    rust-analyzer
    gopls
    pyright
    typescript-language-server
    
    # Programming languages
    rustc cargo
    go
    python3 poetry
    nodejs_20 yarn
    
    # Database tools
    postgresql redis sqlite
    
    # Cloud and infrastructure
    terraform ansible
    awscli2 kubectl helm
    
    # Code quality
    shellcheck hadolint yamllint
    pre-commit
  ];

  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      
      plugins = with pkgs.vimPlugins; [
        # Essential plugins only
        vim-sensible
        fzf-vim
        vim-airline
        nerdtree
        vim-gitgutter
      ];
      
      extraConfig = ''
        set number relativenumber
        set tabstop=2 shiftwidth=2 expandtab
        set ignorecase smartcase
        set hlsearch incsearch
      '';
    };
    
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        rust-lang.rust-analyzer
        golang.go
        bradlc.vscode-tailwindcss
      ];
    };
  };
}