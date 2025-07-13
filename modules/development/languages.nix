{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
in
{
  # Language-specific development environments
  environment.systemPackages = with pkgs; [
    # Rust
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    cargo-edit
    cargo-watch
    cargo-expand
    cargo-outdated
    cargo-audit
    sccache # Shared compilation cache
    
    # Python
    python311
    python311Packages.pip
    python311Packages.virtualenv
    python311Packages.black
    python311Packages.flake8
    python311Packages.mypy
    python311Packages.pytest
    python311Packages.ipython
    python311Packages.jupyter
    python311Packages.pandas
    python311Packages.numpy
    poetry
    pipenv
    pyright # Python LSP
    ruff # Fast Python linter
    
    # Node.js / JavaScript / TypeScript
    nodejs_20
    nodePackages.npm
    nodePackages.yarn
    nodePackages.pnpm
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.eslint
    nodePackages.prettier
    nodePackages.nodemon
    nodePackages.pm2
    nodePackages.webpack
    nodePackages.webpack-cli
    nodePackages."@angular/cli"
    nodePackages."@vue/cli"
    nodePackages.create-react-app
    nodePackages.vercel
    nodePackages.netlify-cli
    deno
    bun
    
    # Go
    go_1_21
    gopls
    golangci-lint
    go-tools
    gomodifytags
    gotests
    gocode-gomod
    delve # Go debugger
    go-task # Task runner
    air # Live reload for Go apps
    
    # Java / JVM
    jdk17
    gradle
    maven
    sbt # Scala build tool
    kotlin
    groovy
    clojure
    leiningen # Clojure build tool
    
    # C/C++
    gcc
    clang_16
    llvmPackages_16.clang-unwrapped
    cmake
    ninja
    ccache
    gdb
    lldb
    valgrind
    clang-tools # clang-format, clang-tidy
    bear # Build EAR for compile_commands.json
    
    # .NET
    dotnet-sdk_8
    omnisharp-roslyn
    mono
    msbuild
    
    # Ruby
    ruby_3_2
    rubyPackages_3_2.solargraph # Ruby LSP
    rubyPackages_3_2.rubocop
    rubyPackages_3_2.rake
    bundler
    
    # PHP
    php82
    php82Packages.composer
    php82Packages.psalm
    php82Packages.phpstan
    php82Packages.php-cs-fixer
    
    # Haskell
    ghc
    cabal-install
    stack
    haskell-language-server
    hlint
    ormolu # Haskell formatter
    
    # Elixir/Erlang
    elixir_1_15
    erlang
    rebar3
    elixir-ls # Elixir LSP
    
    # Swift (macOS only)
  ] ++ lib.optionals isDarwin [
    # Swift is included with Xcode on macOS
    swiftformat
    swiftlint
    sourcery # Swift code generation
    
  ] ++ lib.optionals isNixOS [
    # Linux-specific language tools
    swift
    swiftPackages.swift
    swiftPackages.swiftpm
  ] ++ [
    # Other languages
    lua5_4
    lua54Packages.luarocks
    lua-language-server
    
    nim
    nimble
    nimlsp
    
    zig
    zls # Zig language server
    
    crystal
    crystalline # Crystal language server
    
    julia-bin
    
    # Language-agnostic tools
    tree-sitter # Parser generator
    ctags # Code indexing
    global # Source code tag system
  ];
  
  # Language-specific environment variables
  environment.variables = {
    # Python
    PYTHONDONTWRITEBYTECODE = "1";
    PYTHONUNBUFFERED = "1";
    
    # Node.js
    NODE_OPTIONS = "--max-old-space-size=4096";
    
    # Rust
    RUST_BACKTRACE = "1";
    RUSTFLAGS = "-C target-cpu=native";
    
    # Go
    GO111MODULE = "on";
    GOPRIVATE = "github.com/jontk/*";
    
    # Java
    JAVA_HOME = "${pkgs.jdk17}";
    
    # .NET
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";
  } // lib.optionalAttrs isDarwin {
    # macOS specific
    # Use Xcode's Swift
    DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
  };
  
  # Language-specific shell aliases
  environment.shellAliases = {
    # Python
    py = "python3";
    ipy = "ipython";
    pip = "pip3";
    venv = "python3 -m venv";
    activate = "source venv/bin/activate";
    
    # Node.js
    ni = "npm install";
    nr = "npm run";
    nt = "npm test";
    nb = "npm run build";
    
    # Rust
    cb = "cargo build";
    cr = "cargo run";
    ct = "cargo test";
    cc = "cargo check";
    cf = "cargo fmt";
    cl = "cargo clippy";
    
    # Go
    gb = "go build";
    gr = "go run";
    gt = "go test";
    gm = "go mod";
    gmt = "go mod tidy";
    gmv = "go mod vendor";
    
    # Docker for different languages
    dpy = "docker run -it --rm -v \${PWD}:/app -w /app python:3.11";
    dnode = "docker run -it --rm -v \${PWD}:/app -w /app node:20";
    dgo = "docker run -it --rm -v \${PWD}:/app -w /app golang:1.21";
  };
  
  # macOS specific configuration for languages
} // lib.optionalAttrs isDarwin {
  system = {
    defaults.CustomUserPreferences = {
      # Xcode language-specific settings
      "com.apple.dt.Xcode" = {
        # Swift
        IDESwiftPackageAddingMode = 1;
        IDESwiftPackageRepositoryAuthenticationMode = 0;
        
        # Indentation for different languages
        DVTSourceTextIndentWidth = 2;
        DVTSourceTextTabWidth = 2;
        DVTSourceTextIndentUsingSpaces = true;
        
        # Language-specific formatting
        IDECppCodeFormatterOptions = {
          BasedOnStyle = "Google";
          IndentWidth = 2;
        };
        
        IDESwiftFormatOptions = {
          IndentWidth = 2;
          UseTabs = false;
        };
      };
    };
  };
  
  # Homebrew language-specific packages (macOS only) - disabled temporarily
} // lib.optionalAttrs false {
  homebrew = {
    brews = [
      # Ruby version management
      "rbenv"
      "ruby-build"
      
      # Python version management
      "pyenv"
      "pyenv-virtualenv"
      
      # Node version management
      "nvm"
      "fnm" # Fast Node Manager
      
      # JVM version management
      "jenv"
      
      # Mobile development
      "flutter"
      "dart"
      
      # Additional language tools
      "luarocks"
      "opam" # OCaml package manager
    ];
    
    casks = [
      # Language-specific IDEs
      "rubymine"
      "clion"
      "rider" # .NET IDE
      
      # Mobile development
      "flutter"
      "react-native-debugger"
      
      # Language-specific tools
      "julia"
      "racket"
    ];
  };
}