# Custom package definitions and modifications

final: prev: {
  # Custom scripts and utilities
  nixconf-tools = prev.writeShellScriptBin "nixconf-tools" ''
    #!/usr/bin/env bash
    # Nixconf management utilities
    
    set -euo pipefail
    
    SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
    NIXCONF_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/.config/nixconf")"
    
    show_help() {
      cat << EOF
    nixconf-tools - Nix Configuration Management Utilities
    
    Usage: nixconf-tools <command> [options]
    
    Commands:
      update              Update flake inputs
      build               Build configuration
      switch              Switch to new configuration
      rollback            Rollback to previous generation
      clean               Clean old generations
      check               Check configuration validity
      format              Format Nix files
      show                Show flake outputs
      
    Options:
      -h, --help          Show this help message
      -v, --verbose       Enable verbose output
      
    Examples:
      nixconf-tools update
      nixconf-tools build
      nixconf-tools switch
      nixconf-tools clean --older-than 7d
    EOF
    }
    
    update_flake() {
      echo "🔄 Updating flake inputs..."
      cd "$NIXCONF_ROOT"
      nix flake update
      echo "✅ Flake inputs updated"
    }
    
    build_config() {
      echo "🔨 Building configuration..."
      cd "$NIXCONF_ROOT"
      if [[ "$OSTYPE" == "darwin"* ]]; then
        nix build ".#darwinConfigurations.$(hostname -s).system"
      else
        nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel"
      fi
      echo "✅ Configuration built successfully"
    }
    
    switch_config() {
      echo "🔄 Switching to new configuration..."
      cd "$NIXCONF_ROOT"
      if [[ "$OSTYPE" == "darwin"* ]]; then
        darwin-rebuild switch --flake .
      else
        sudo nixos-rebuild switch --flake .
      fi
      echo "✅ Switched to new configuration"
    }
    
    rollback_config() {
      echo "⏪ Rolling back configuration..."
      if [[ "$OSTYPE" == "darwin"* ]]; then
        darwin-rebuild rollback
      else
        sudo nixos-rebuild rollback
      fi
      echo "✅ Rolled back to previous configuration"
    }
    
    clean_generations() {
      local older_than="''${1:-30d}"
      echo "🧹 Cleaning generations older than $older_than..."
      
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo nix-collect-garbage --delete-older-than "$older_than"
      else
        sudo nix-collect-garbage --delete-older-than "$older_than"
        sudo /run/current-system/bin/switch-to-configuration boot
      fi
      echo "✅ Cleaned old generations"
    }
    
    check_config() {
      echo "🔍 Checking configuration..."
      cd "$NIXCONF_ROOT"
      nix flake check
      echo "✅ Configuration is valid"
    }
    
    format_nix() {
      echo "✨ Formatting Nix files..."
      cd "$NIXCONF_ROOT"
      find . -name "*.nix" -exec nixpkgs-fmt {} \;
      echo "✅ Nix files formatted"
    }
    
    show_outputs() {
      echo "📋 Flake outputs:"
      cd "$NIXCONF_ROOT"
      nix flake show
    }
    
    case "''${1:-}" in
      update)
        update_flake
        ;;
      build)
        build_config
        ;;
      switch)
        switch_config
        ;;
      rollback)
        rollback_config
        ;;
      clean)
        clean_generations "''${2:-30d}"
        ;;
      check)
        check_config
        ;;
      format)
        format_nix
        ;;
      show)
        show_outputs
        ;;
      -h|--help|help)
        show_help
        ;;
      *)
        echo "❌ Unknown command: ''${1:-}"
        echo "Use 'nixconf-tools --help' for usage information"
        exit 1
        ;;
    esac
  '';

  # Development environment setup script
  dev-setup = prev.writeShellScriptBin "dev-setup" ''
    #!/usr/bin/env bash
    # Development environment setup script
    
    set -euo pipefail
    
    show_help() {
      cat << EOF
    dev-setup - Development Environment Setup
    
    Usage: dev-setup [project-type] [project-name]
    
    Project Types:
      rust                Rust project with Cargo.toml
      python              Python project with pyproject.toml
      node                Node.js project with package.json
      go                  Go project with go.mod
      nix                 Nix flake project
      
    Examples:
      dev-setup rust my-rust-app
      dev-setup python my-python-app
      dev-setup node my-web-app
    EOF
    }
    
    setup_rust() {
      local name="$1"
      echo "🦀 Setting up Rust project: $name"
      
      mkdir -p "$name"
      cd "$name"
      
      # Create Cargo.toml
      cat > Cargo.toml << EOF
    [package]
    name = "$name"
    version = "0.1.0"
    edition = "2021"
    
    [dependencies]
    
    [dev-dependencies]
    EOF
      
      # Create src/main.rs
      mkdir -p src
      cat > src/main.rs << EOF
    fn main() {
        println!("Hello, world!");
    }
    EOF
      
      # Create flake.nix
      create_rust_flake "$name"
      
      echo "✅ Rust project '$name' created"
    }
    
    setup_python() {
      local name="$1"
      echo "🐍 Setting up Python project: $name"
      
      mkdir -p "$name"
      cd "$name"
      
      # Create pyproject.toml
      cat > pyproject.toml << EOF
    [build-system]
    requires = ["poetry-core"]
    build-backend = "poetry.core.masonry.api"
    
    [tool.poetry]
    name = "$name"
    version = "0.1.0"
    description = ""
    authors = ["Your Name <you@example.com>"]
    
    [tool.poetry.dependencies]
    python = "^3.11"
    
    [tool.poetry.group.dev.dependencies]
    pytest = "^7.0"
    black = "^23.0"
    isort = "^5.0"
    flake8 = "^6.0"
    mypy = "^1.0"
    EOF
      
      # Create main module
      mkdir -p "$name"
      cat > "$name"/__init__.py << EOF
    """$name package."""
    
    __version__ = "0.1.0"
    EOF
      
      cat > "$name"/main.py << EOF
    """Main module for $name."""
    
    def main():
        print("Hello, world!")
    
    if __name__ == "__main__":
        main()
    EOF
      
      # Create flake.nix
      create_python_flake "$name"
      
      echo "✅ Python project '$name' created"
    }
    
    create_rust_flake() {
      local name="$1"
      cat > flake.nix << EOF
    {
      description = "Rust project: $name";
    
      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        rust-overlay.url = "github:oxalica/rust-overlay";
        flake-utils.url = "github:numtide/flake-utils";
      };
    
      outputs = { self, nixpkgs, rust-overlay, flake-utils }:
        flake-utils.lib.eachDefaultSystem (system:
          let
            overlays = [ (import rust-overlay) ];
            pkgs = import nixpkgs { inherit system overlays; };
            rustToolchain = pkgs.rust-bin.stable.latest.default;
          in
          {
            devShells.default = pkgs.mkShell {
              buildInputs = with pkgs; [
                rustToolchain
                rust-analyzer
                cargo-watch
                cargo-edit
                cargo-audit
              ];
            };
          });
    }
    EOF
    }
    
    create_python_flake() {
      local name="$1"
      cat > flake.nix << EOF
    {
      description = "Python project: $name";
    
      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-utils.url = "github:numtide/flake-utils";
      };
    
      outputs = { self, nixpkgs, flake-utils }:
        flake-utils.lib.eachDefaultSystem (system:
          let
            pkgs = import nixpkgs { inherit system; };
            python = pkgs.python3.withPackages (ps: with ps; [
              pip
              poetry-core
              pytest
              black
              isort
              flake8
              mypy
            ]);
          in
          {
            devShells.default = pkgs.mkShell {
              buildInputs = [ python pkgs.poetry ];
            };
          });
    }
    EOF
    }
    
    case "''${1:-}" in
      rust)
        setup_rust "''${2:-my-rust-app}"
        ;;
      python)
        setup_python "''${2:-my-python-app}"
        ;;
      -h|--help|help)
        show_help
        ;;
      *)
        echo "❌ Unknown project type: ''${1:-}"
        show_help
        exit 1
        ;;
    esac
  '';

  # System information script
  sysinfo = prev.writeShellScriptBin "sysinfo" ''
    #!/usr/bin/env bash
    # System information display
    
    set -euo pipefail
    
    echo "🖥️  System Information"
    echo "===================="
    echo
    
    # OS Information
    echo "Operating System:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "  macOS $(sw_vers -productVersion)"
      echo "  Build: $(sw_vers -buildVersion)"
    else
      echo "  $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
      echo "  Kernel: $(uname -r)"
    fi
    echo
    
    # Hardware Information
    echo "Hardware:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "  Model: $(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)"
      echo "  Processor: $(system_profiler SPHardwareDataType | grep "Processor Name" | cut -d: -f2 | xargs)"
      echo "  Memory: $(system_profiler SPHardwareDataType | grep "Memory" | cut -d: -f2 | xargs)"
    else
      echo "  CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
      echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
      echo "  Storage: $(df -h / | tail -1 | awk '{print $2}')"
    fi
    echo
    
    # Nix Information
    echo "Nix:"
    echo "  Version: $(nix --version)"
    if command -v nix-env &> /dev/null; then
      echo "  Profile: $(nix-env --list-generations | tail -1)"
    fi
    echo
    
    # Network Information
    echo "Network:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "  Hostname: $(hostname)"
      echo "  IP: $(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')"
    else
      echo "  Hostname: $(hostname)"
      echo "  IP: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+')"
    fi
    echo
  '';

  # Quick development shell launcher
  dev-shell = prev.writeShellScriptBin "dev-shell" ''
    #!/usr/bin/env bash
    # Quick development shell launcher
    
    set -euo pipefail
    
    show_help() {
      cat << EOF
    dev-shell - Quick Development Shell Launcher
    
    Usage: dev-shell [language]
    
    Languages:
      rust                Rust development environment
      python              Python development environment
      node                Node.js development environment
      go                  Go development environment
      nix                 Nix development environment
      
    Examples:
      dev-shell rust
      dev-shell python
      dev-shell node
    EOF
    }
    
    case "''${1:-}" in
      rust)
        nix shell nixpkgs#{rust-bin.stable.latest.default,rust-analyzer,cargo-watch}
        ;;
      python)
        nix shell nixpkgs#{python3,python3Packages.pip,python3Packages.poetry}
        ;;
      node)
        nix shell nixpkgs#{nodejs,npm,yarn}
        ;;
      go)
        nix shell nixpkgs#{go,gopls,golangci-lint}
        ;;
      nix)
        nix shell nixpkgs#{nixpkgs-fmt,nil,nix-tree}
        ;;
      -h|--help|help)
        show_help
        ;;
      *)
        echo "❌ Unknown language: ''${1:-}"
        show_help
        exit 1
        ;;
    esac
  '';

  # Backup utility
  backup-tool = prev.writeShellScriptBin "backup-tool" ''
    #!/usr/bin/env bash
    # Backup utility using restic
    
    set -euo pipefail
    
    BACKUP_CONFIG="$HOME/.config/backup/config"
    
    show_help() {
      cat << EOF
    backup-tool - Backup Utility
    
    Usage: backup-tool <command> [options]
    
    Commands:
      init                Initialize backup repository
      backup              Create backup
      restore             Restore from backup
      list                List backup snapshots
      prune               Prune old backups
      
    Configuration:
      Edit $BACKUP_CONFIG to set repository and password
      
    Examples:
      backup-tool init
      backup-tool backup
      backup-tool list
    EOF
    }
    
    load_config() {
      if [[ -f "$BACKUP_CONFIG" ]]; then
        source "$BACKUP_CONFIG"
      else
        echo "❌ Backup configuration not found: $BACKUP_CONFIG"
        echo "Create the file with RESTIC_REPOSITORY and RESTIC_PASSWORD"
        exit 1
      fi
    }
    
    case "''${1:-}" in
      init)
        load_config
        restic init
        ;;
      backup)
        load_config
        restic backup "$HOME" --exclude-file="$HOME/.config/backup/exclude"
        ;;
      restore)
        load_config
        restic restore latest --target "$HOME/restore"
        ;;
      list)
        load_config
        restic snapshots
        ;;
      prune)
        load_config
        restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
        ;;
      -h|--help|help)
        show_help
        ;;
      *)
        echo "❌ Unknown command: ''${1:-}"
        show_help
        exit 1
        ;;
    esac
  '';
}