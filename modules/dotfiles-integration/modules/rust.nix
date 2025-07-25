{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for rust module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.rust or "merge"
    else
      "merge";
  
  # Read rust module configuration from module.yml
  rustModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/rust/module.yml";
  
  # Use default settings for now
  profileSettings = rustModuleConfig.settings;
  
  # Rust configuration files from dotfiles
  rustAliasesFile = "${dotfilesPath}/modules/rust/rust-aliases";
  cargoConfigFile = "${dotfilesPath}/modules/rust/cargo-config.toml";
  
  # Parse rust aliases
  parseRustAliases = content:
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
  
  # Read and parse rust aliases
  rustAliases = 
    if builtins.pathExists rustAliasesFile then
      parseRustAliases (builtins.readFile rustAliasesFile)
    else
      {};
  
  # Essential Rust packages and tools
  rustPackages = with pkgs; [
    rustc                    # Rust compiler
    cargo                    # Package manager
    rustfmt                  # Code formatter
    clippy                   # Linter
    rust-analyzer            # Language server
    cargo-watch              # Watch for changes
    cargo-edit               # Add/remove dependencies
    cargo-outdated           # Check for outdated dependencies
    cargo-audit              # Security audit
    cargo-expand             # Show macro expansions
    cargo-bloat              # Find what takes space in executable
    mdbook                   # Documentation generator
  ];
  
  # Default cargo config
  defaultCargoConfig = ''
    [build]
    jobs = "auto"
    incremental = true
    
    [term]
    color = "auto"
    progress.when = "auto"
    progress.width = 80
    
    [net]
    retry = 3
    git-fetch-with-cli = false
    
    [profile.dev]
    opt-level = 0
    debug = true
    split-debuginfo = "unpacked"
    
    [profile.release]
    opt-level = 3
    lto = true
    codegen-units = 1
    
    [registries]
    crates-io = { index = "sparse+https://index.crates.io/" }
    
    [env]
    RUST_BACKTRACE = "1"
  '';
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "rust" enabledModules)) {
    # Shell aliases for Rust development
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      rustAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      rustAliases;
    
    # Rust environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_RUST_MODULE = "active";
      DOTFILES_RUST_VERSION = rustModuleConfig.version or "unknown";
      RUST_BACKTRACE = "1";
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
    };
    
    # Add Cargo bin to PATH
    home.sessionPath = mkIf (priorityMode != "nixconf") [
      "$HOME/.cargo/bin"
    ];
    
    # Install Rust and essential development tools
    home.packages = mkIf (priorityMode != "nixconf") rustPackages;
    
    # Cargo configuration
    home.file.".cargo/config.toml" = mkIf (priorityMode != "nixconf") {
      text = if builtins.pathExists cargoConfigFile then
        builtins.readFile cargoConfigFile
      else
        defaultCargoConfig;
    };
    
    # Rust-specific shell functions (embedded directly)
    programs.bash.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create new Rust project with common setup
      rnew() {
        local project_name="$1"
        local project_type="''${2:-bin}"  # bin or lib
        
        if [[ -z "$project_name" ]]; then
          echo "Usage: rnew <project-name> [bin|lib]"
          return 1
        fi
        
        cargo new "$project_name" --$project_type
        cd "$project_name"
        
        # Create initial directory structure
        mkdir -p src/bin tests benches examples docs
        
        echo "Created new Rust project: $project_name"
      }
      
      # Run all checks before commit
      rcheck() {
        echo "Running full check suite..."
        
        echo "1. Checking code..."
        cargo check --all-features || return 1
        
        echo "2. Running tests..."
        cargo test --all-features || return 1
        
        echo "3. Checking formatting..."
        cargo fmt --check || return 1
        
        echo "4. Running clippy..."
        cargo clippy --all-features -- -D warnings || return 1
        
        echo "5. Building documentation..."
        cargo doc --no-deps --all-features || return 1
        
        echo "✅ All checks passed!"
      }
      
      # Clean build and rebuild
      rrebuild() {
        local profile="''${1:-dev}"
        
        echo "Cleaning build artifacts..."
        cargo clean
        
        echo "Rebuilding in $profile mode..."
        if [[ "$profile" == "release" ]]; then
          cargo build --release
        else
          cargo build
        fi
      }
      
      # Install common Rust tools
      rtools() {
        echo "Installing common Rust development tools..."
        
        # Development tools
        cargo install cargo-watch
        cargo install cargo-edit
        cargo install cargo-outdated
        cargo install cargo-audit
        cargo install cargo-expand
        cargo install cargo-bloat
        cargo install mdbook
        
        echo "✅ Rust tools installed!"
      }
      
      # Generate and open documentation
      rdoc() {
        local open="''${1:-true}"
        
        cargo doc --no-deps --all-features
        
        if [[ "$open" == "true" ]]; then
          cargo doc --open --no-deps --all-features
        fi
      }
      
      # Quick test runner with pattern matching
      rtest() {
        local pattern="$1"
        
        if [[ -z "$pattern" ]]; then
          cargo test
        else
          cargo test "$pattern"
        fi
      }
    '';
    
    # Same functions for zsh
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create new Rust project with common setup
      rnew() {
        local project_name="$1"
        local project_type="''${2:-bin}"  # bin or lib
        
        if [[ -z "$project_name" ]]; then
          echo "Usage: rnew <project-name> [bin|lib]"
          return 1
        fi
        
        cargo new "$project_name" --$project_type
        cd "$project_name"
        
        # Create initial directory structure
        mkdir -p src/bin tests benches examples docs
        
        echo "Created new Rust project: $project_name"
      }
      
      # Run all checks before commit
      rcheck() {
        echo "Running full check suite..."
        
        echo "1. Checking code..."
        cargo check --all-features || return 1
        
        echo "2. Running tests..."
        cargo test --all-features || return 1
        
        echo "3. Checking formatting..."
        cargo fmt --check || return 1
        
        echo "4. Running clippy..."
        cargo clippy --all-features -- -D warnings || return 1
        
        echo "5. Building documentation..."
        cargo doc --no-deps --all-features || return 1
        
        echo "✅ All checks passed!"
      }
      
      # Clean build and rebuild
      rrebuild() {
        local profile="''${1:-dev}"
        
        echo "Cleaning build artifacts..."
        cargo clean
        
        echo "Rebuilding in $profile mode..."
        if [[ "$profile" == "release" ]]; then
          cargo build --release
        else
          cargo build
        fi
      }
      
      # Install common Rust tools
      rtools() {
        echo "Installing common Rust development tools..."
        
        # Development tools
        cargo install cargo-watch
        cargo install cargo-edit
        cargo install cargo-outdated
        cargo install cargo-audit
        cargo install cargo-expand
        cargo install cargo-bloat
        cargo install mdbook
        
        echo "✅ Rust tools installed!"
      }
      
      # Generate and open documentation
      rdoc() {
        local open="''${1:-true}"
        
        cargo doc --no-deps --all-features
        
        if [[ "$open" == "true" ]]; then
          cargo doc --open --no-deps --all-features
        fi
      }
      
      # Quick test runner with pattern matching
      rtest() {
        local pattern="$1"
        
        if [[ -z "$pattern" ]]; then
          cargo test
        else
          cargo test "$pattern"
        fi
      }
    '';
  };
}