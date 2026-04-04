# Development tools overlays and customizations

final: prev: {
  # Enhanced Neovim with additional plugins and configuration
  neovim-custom = prev.neovim.override {
    configure = {
      customRC = ''
        " Basic configuration
        set number
        set relativenumber
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set autoindent
        set smartindent
        
        " Search settings
        set ignorecase
        set smartcase
        set incsearch
        set hlsearch
        
        " Enable syntax highlighting
        syntax on
        filetype plugin indent on
        
        " Set leader key
        let mapleader = " "
        
        " Basic key mappings
        nnoremap <leader>w :w<CR>
        nnoremap <leader>q :q<CR>
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l
      '';
      
      packages.myVimPackage = with prev.vimPlugins; {
        start = [
          # Essential plugins
          vim-sensible
          vim-surround
          vim-commentary
          vim-fugitive
          
          # Navigation and fuzzy finding
          fzf-vim
          nerdtree
          
          # Language support
          vim-nix
          rust-vim
          vim-go
          typescript-vim
          
          # Completion and LSP
          nvim-lspconfig
          nvim-cmp
          cmp-nvim-lsp
          cmp-buffer
          cmp-path
          
          # Syntax highlighting
          nvim-treesitter
          
          # Status line
          lightline-vim
          
          # Color schemes
          gruvbox
          tokyonight-nvim
        ];
      };
    };
  };

  # Enhanced Git with additional tools and aliases
  git-enhanced = prev.writeShellScriptBin "git-enhanced" ''
    ${prev.git}/bin/git "$@"
  '';

  # Custom development shell with all tools
  dev-shell = prev.mkShell {
    buildInputs = with final; [
      # Core development tools
      git
      gh
      lazygit
      
      # Text editors
      neovim-custom
      emacs
      
      # Language servers and formatters
      nil # Nix LSP
      nixpkgs-fmt
      rnix-lsp
      
      # Build tools
      gnumake
      cmake
      pkg-config
      autoconf
      automake
      
      # Debugging and profiling
      lldb
      
      # Development utilities
      jq
      yq
      httpie
      curl
      wget
      
      # File utilities
      ripgrep
      fd
      bat
      eza
      tree
      fzf
    ];
    
    shellHook = ''
      echo "🚀 Development Environment Ready!"
      echo "Available tools:"
      echo "  - Enhanced Neovim (neovim-custom)"
      echo "  - Git with additional tools"
      echo "  - Language servers for Nix, Rust, etc."
      echo "  - Debugging and profiling tools"
      echo ""
      echo "Useful aliases:"
      echo "  - ll='eza -la'"
      echo "  - cat='bat'"
      echo "  - find='fd'"
      echo "  - grep='rg'"
      
      # Set up aliases
      alias ll='eza -la'
      alias la='eza -la'
      alias cat='bat'
      alias grep='rg'
    '';
  };

  # Docker with additional tools and plugins
  docker-enhanced = prev.docker.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [ final.dive final.lazydocker ];
  });

  # Enhanced Python with commonly used packages
  python3-dev = prev.python3.withPackages (ps: with ps; [
    # Core development tools
    pip
    virtualenv
    poetry-core
    
    # Code quality
    black
    isort
    flake8
    mypy
    pylint
    
    # Testing
    pytest
    pytest-cov
    pytest-mock
    
    # Development utilities
    ipython
    jupyter
    
    # Common libraries
    requests
    click
    pydantic
    
    # Data science basics
    numpy
    pandas
    matplotlib
    
    # Web development
    fastapi
    flask
    django
  ]);

  # Node.js with global packages
  nodejs-dev = prev.nodejs.override {
    enableNpm = true;
  };

  # Rust with additional tools
  rust-dev = prev.rustPlatform.buildRustPackage rec {
    pname = "rust-dev-tools";
    version = "0.1.0";
    
    src = prev.writeTextFile {
      name = "Cargo.toml";
      text = ''
        [package]
        name = "rust-dev-tools"
        version = "0.1.0"
        edition = "2021"
        
        [dependencies]
      '';
    };
    
    cargoSha256 = "0000000000000000000000000000000000000000000000000000";
    
    buildInputs = with final; [
      cargo
      rustc
      rust-analyzer
      cargo-watch
      cargo-edit
      cargo-audit
      cargo-outdated
      cargo-expand
      cargo-flamegraph
    ];
  };

  # Go with additional tools
  go-dev = prev.buildEnv {
    name = "go-dev-environment";
    paths = with final; [
      go
      gopls
      golangci-lint
      delve
      go-tools
      gocode
      godef
      goimports
    ];
  };

  # Java development environment
  java-dev = prev.buildEnv {
    name = "java-dev-environment";
    paths = with final; [
      openjdk17
      maven
      gradle
      visualvm
      jdt-language-server
    ];
  };

  # Database development tools
  db-tools = prev.buildEnv {
    name = "database-tools";
    paths = with final; [
      postgresql
      redis
      sqlite
      
      # Database clients
      pgcli
      redis-cli
      sqlite-interactive
      
      # GUI tools
      dbeaver-bin
    ];
  };

  # Cloud development tools
  cloud-dev = prev.buildEnv {
    name = "cloud-development";
    paths = with final; [
      # AWS
      awscli2
      aws-sam-cli
      
      # Kubernetes
      kubectl
      kubectx
      k9s
      helm
      kustomize
      stern
      
      # Terraform
      terraform
      terragrunt
      
      # Docker and containers
      docker
      docker-compose
      dive
      lazydocker
      
      # Monitoring
      prometheus
      grafana
    ];
  };
}