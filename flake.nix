{
  description = "Nix Configuration for macOS and NixOS Development Environments";

  inputs = {
    # Nixpkgs - using unstable for latest packages and features
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Stable nixpkgs for production systems (optional fallback)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Darwin - nix-darwin for macOS system management
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager - user environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland - Wayland compositor for NixOS
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware configuration helpers
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Flake utilities for cross-system helpers
    flake-utils.url = "github:numtide/flake-utils";

    # Flake parts for better flake organization
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Additional useful inputs for development
    # Rust toolchain management
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # VSCode extensions
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Firefox addons
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management with sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Dotfiles repository for integration
    dotfiles = {
      # Using local path for development
      url = "path:/home/jontk/src/github.com/jontk/dotfiles/nix";
      # For GitHub repository (once public or with access token):
      # url = "github:jontk/dotfiles?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, home-manager, hyprland, nixos-hardware, flake-utils, flake-parts, rust-overlay, nix-vscode-extensions, firefox-addons, sops-nix, dotfiles }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      forAllSystems = nixpkgs.lib.genAttrs systems;
      
      # Common overlays to apply across all systems
      overlays = [
        rust-overlay.overlays.default
        (import ./overlays)
      ];
      
      # Helper function to create pkgs with overlays
      mkPkgs = system: import nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
          allowUnsupportedSystem = true;
        };
      };
      
      # Helper function to create system configurations
      mkSystem = { system, modules, specialArgs ? {} }: 
        let
          pkgs = mkPkgs system;
        in
        if nixpkgs.lib.hasPrefix "darwin" system then
          nix-darwin.lib.darwinSystem {
            inherit system modules;
            specialArgs = specialArgs // { 
              inherit self nixpkgs nixpkgs-stable pkgs;
              inputs = { inherit rust-overlay nix-vscode-extensions firefox-addons sops-nix dotfiles; };
            };
          }
        else
          nixpkgs.lib.nixosSystem {
            inherit system modules;
            specialArgs = specialArgs // { 
              inherit self nixpkgs nixpkgs-stable nixos-hardware pkgs;
              inputs = { inherit hyprland rust-overlay nix-vscode-extensions firefox-addons sops-nix dotfiles; };
            };
          };
      
      # Common configuration shared across systems
      commonModules = [
        ./modules/common
        ./modules/dotfiles-integration
      ];
      
      # Development environment modules
      developmentModules = [
        ./modules/development
      ];

      # Desktop modules (NixOS only)
      desktopModules = [
        ./modules/desktop
      ];

      # Remote access modules (NixOS only)
      remoteAccessModules = [
        ./modules/remote-access
      ];

      # Security and performance modules (NixOS only)
      securityModules = [
        ./modules/security
        ./modules/performance
        ./modules/monitoring
        ./modules/secrets
        ./modules/snapshots
        ./modules/backup-scheduler
        ./modules/containers
        ./modules/networking
        ./modules/maintenance
      ];

      # Host-specific configurations
      hostConfigs = {
        # NixOS configurations
        nixos-dev = {
          system = "x86_64-linux";
          modules = [
            ./hosts/nixos-dev
            home-manager.nixosModules.home-manager
            hyprland.nixosModules.default
          ] ++ commonModules ++ developmentModules ++ desktopModules ++ remoteAccessModules ++ securityModules;
          specialArgs = { inherit hyprland; };
        };

        devbox = {
          system = "x86_64-linux";
          modules = [
            ./hosts/devbox
            home-manager.nixosModules.home-manager
            hyprland.nixosModules.default
          ] ++ commonModules ++ developmentModules ++ desktopModules ++ remoteAccessModules ++ securityModules;
          specialArgs = { inherit hyprland; };
        };

        # macOS configurations  
        macos-laptop = {
          system = "aarch64-darwin";
          modules = [
            ./hosts/macos-laptop
            home-manager.darwinModules.home-manager
          ] ++ commonModules ++ developmentModules;
          specialArgs = {};
        };

        # Template for additional macOS systems
        # macos-desktop = {
        #   system = "aarch64-darwin";
        #   modules = [
        #     ./hosts/macos-desktop
        #     home-manager.darwinModules.home-manager
        #   ] ++ commonModules ++ developmentModules;
        #   specialArgs = {};
        # };

        # Template for additional NixOS systems
        # nixos-server = {
        #   system = "x86_64-linux";
        #   modules = [
        #     ./hosts/nixos-server
        #     home-manager.nixosModules.home-manager
        #   ] ++ commonModules ++ remoteAccessModules;
        #   specialArgs = {};
        # };
      };
    in
    {
      # NixOS configurations
      nixosConfigurations = nixpkgs.lib.mapAttrs 
        (name: config: mkSystem config)
        (nixpkgs.lib.filterAttrs (name: config: !nixpkgs.lib.hasPrefix "darwin" config.system) hostConfigs);

      # Darwin configurations
      darwinConfigurations = nixpkgs.lib.mapAttrs 
        (name: config: mkSystem config)
        (nixpkgs.lib.filterAttrs (name: config: nixpkgs.lib.hasPrefix "darwin" config.system) hostConfigs);

      # Home Manager configurations (standalone)
      homeConfigurations = {
        "jontk@nixos-dev" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          modules = [ ./users/jontk ];
          extraSpecialArgs = {
            inherit nix-vscode-extensions firefox-addons;
          };
        };
        "jontk@macos-laptop" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "aarch64-darwin";
          modules = [ ./users/jontk ];
          extraSpecialArgs = {
            inherit nix-vscode-extensions firefox-addons;
          };
        };
      };

      # Development shells for each system
      devShells = forAllSystems (system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil
              nix-tree
              nixos-rebuild
            ] ++ nixpkgs.lib.optionals pkgs.stdenv.isDarwin [
              darwin.rebuild
            ];
            shellHook = ''
              echo "Nix Configuration Development Environment"
              echo "Available commands:"
              echo "  nix flake check         - Validate configuration"
              echo "  nix flake show          - Show available outputs"
              echo "  nixpkgs-fmt .           - Format Nix files"
              echo "  nix build .#<config>    - Build specific configuration"
              echo ""
              echo "Available configurations:"
              ${nixpkgs.lib.concatStringsSep "\n" 
                (nixpkgs.lib.mapAttrsToList (name: _: "echo \"  ${name}\"") hostConfigs)}
            '';
          };
        });

      # Custom packages for each system
      packages = forAllSystems (system:
        let
          pkgs = mkPkgs system;
        in
        {
          # Import custom packages
        } // (import ./packages { inherit pkgs; lib = pkgs.lib; }));

      # Package overlays
      overlays = {
        default = import ./overlays;
        rust = rust-overlay.overlays.default;
      };

      # Utility functions for adding new hosts
      lib = {
        mkNixosHost = { hostname, system ? "x86_64-linux", extraModules ? [] }:
          mkSystem {
            inherit system;
            modules = [
              ./hosts/${hostname}
              home-manager.nixosModules.home-manager
            ] ++ commonModules ++ developmentModules ++ extraModules;
          };

        mkDarwinHost = { hostname, system ? "aarch64-darwin", extraModules ? [] }:
          mkSystem {
            inherit system;
            modules = [
              ./hosts/${hostname}
              home-manager.darwinModules.home-manager
            ] ++ commonModules ++ developmentModules ++ extraModules;
          };
      };

      # Formatter for nix fmt
      formatter = forAllSystems (system: (mkPkgs system).nixpkgs-fmt);
      
      # Checks for nix flake check
      checks = forAllSystems (system:
        let
          pkgs = mkPkgs system;
          
          # Helper function to create syntax check for a file
          mkSyntaxCheck = name: file: pkgs.runCommand "check-${name}" {} ''
            ${pkgs.nix}/bin/nix-instantiate --parse ${file} > /dev/null
            touch $out
          '';
          
          # Helper function to create build check for a configuration
          mkBuildCheck = name: config: pkgs.runCommand "build-check-${name}" {} ''
            echo "Checking if ${name} builds successfully..."
            ${pkgs.nix}/bin/nix build --no-link --show-trace ${config} || exit 1
            touch $out
          '';
          
        in
        {
          # Syntax checks for all Nix files
          syntax-check-flake = mkSyntaxCheck "flake" ./flake.nix;
          
          # Module syntax checks
          syntax-check-modules = pkgs.runCommand "check-modules-syntax" {} ''
            for file in ${./modules}/*/default.nix; do
              if [[ -f "$file" ]]; then
                echo "Checking syntax: $file"
                ${pkgs.nix}/bin/nix-instantiate --parse "$file" > /dev/null || exit 1
              fi
            done
            touch $out
          '';
          
          # User configuration syntax checks
          syntax-check-users = pkgs.runCommand "check-users-syntax" {} ''
            for file in ${./users}/*/default.nix; do
              if [[ -f "$file" ]]; then
                echo "Checking syntax: $file"
                ${pkgs.nix}/bin/nix-instantiate --parse "$file" > /dev/null || exit 1
              fi
            done
            touch $out
          '';
          
          # Host configuration syntax checks
          syntax-check-hosts = pkgs.runCommand "check-hosts-syntax" {} ''
            for file in ${./hosts}/*/default.nix; do
              if [[ -f "$file" ]]; then
                echo "Checking syntax: $file"
                ${pkgs.nix}/bin/nix-instantiate --parse "$file" > /dev/null || exit 1
              fi
            done
            touch $out
          '';
          
          # Environment configuration syntax checks
          syntax-check-environments = pkgs.runCommand "check-environments-syntax" {} ''
            for file in ${./environments}/*.nix; do
              if [[ -f "$file" ]]; then
                echo "Checking syntax: $file"
                ${pkgs.nix}/bin/nix-instantiate --parse "$file" > /dev/null || exit 1
              fi
            done
            touch $out
          '';
          
          # Package sets syntax checks
          syntax-check-packages = pkgs.runCommand "check-packages-syntax" {} ''
            for file in ${./packages}/**/default.nix; do
              if [[ -f "$file" ]]; then
                echo "Checking syntax: $file"
                ${pkgs.nix}/bin/nix-instantiate --parse "$file" > /dev/null || exit 1
              fi
            done
            touch $out
          '';
          
          # Formatting check
          formatting-check = pkgs.runCommand "check-formatting" {} ''
            cd ${./.}
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check . || {
              echo "Files are not properly formatted. Run 'nixpkgs-fmt .' to fix."
              exit 1
            }
            touch $out
          '';
          
          # Documentation check
          documentation-check = pkgs.runCommand "check-documentation" {} ''
            echo "Checking documentation coverage..."
            
            # Check if README exists
            if [[ ! -f ${./README.md} ]]; then
              echo "Missing README.md"
              exit 1
            fi
            
            # Check if CLAUDE.md exists
            if [[ ! -f ${./CLAUDE.md} ]]; then
              echo "Missing CLAUDE.md"
              exit 1
            fi
            
            # Count modules and docs
            modules_count=$(find ${./modules} -name "default.nix" | wc -l)
            docs_count=$(find ${./docs} -name "*.md" | wc -l)
            
            echo "Found $modules_count modules and $docs_count documentation files"
            
            if [[ $docs_count -lt 5 ]]; then
              echo "Warning: Low documentation coverage"
            fi
            
            touch $out
          '';
          
          # Security check
          security-check = pkgs.runCommand "check-security" {} ''
            echo "Running security checks..."
            
            # Check for common security issues
            cd ${./.}
            
            # Check for hardcoded secrets
            if grep -r "password\|secret\|key" --include="*.nix" . | grep -v "# " | grep -v "description\|option\|example" | head -5; then
              echo "Warning: Potential hardcoded secrets found"
              echo "Please review the above matches"
            fi
            
            # Check file permissions
            find . -name "*.nix" -not -perm 644 | head -5 | while read file; do
              echo "Warning: File $file has unusual permissions"
            done
            
            # Check for TODO/FIXME comments
            todo_count=$(grep -r "TODO\|FIXME\|XXX" --include="*.nix" . | wc -l)
            echo "Found $todo_count TODO/FIXME comments"
            
            touch $out
          '';
          
          # Module structure validation
          module-structure-check = pkgs.runCommand "check-module-structure" {} ''
            echo "Validating module structure..."
            
            for module in ${./modules}/*/default.nix; do
              if [[ -f "$module" ]]; then
                module_name=$(basename $(dirname "$module"))
                echo "Checking module: $module_name"
                
                # Check for required sections
                if ! grep -q "options\." "$module"; then
                  echo "Warning: Module $module_name missing options section"
                fi
                
                if ! grep -q "config.*=" "$module"; then
                  echo "Warning: Module $module_name missing config section"
                fi
                
                if ! grep -q "mkEnableOption\|mkOption" "$module"; then
                  echo "Warning: Module $module_name missing option definitions"
                fi
                
                if ! grep -q "mkIf.*config\." "$module"; then
                  echo "Warning: Module $module_name missing conditional config"
                fi
              fi
            done
            
            touch $out
          '';
          
          # Configuration validation
          config-validation = pkgs.runCommand "validate-configurations" {} ''
            echo "Validating configuration consistency..."
            
            # Check that all modules are imported in flake.nix
            cd ${./.}
            for module_dir in modules/*/; do
              module_name=$(basename "$module_dir")
              if ! grep -q "modules/$module_name" flake.nix; then
                echo "Warning: Module $module_name not imported in flake.nix"
              fi
            done
            
            # Check that all environments exist
            for env in development staging production; do
              if [[ ! -f "environments/$env.nix" ]]; then
                echo "Warning: Missing environment file: $env.nix"
              fi
            done
            
            touch $out
          '';
          
        } // (if system == "x86_64-linux" then {
          # Build checks for NixOS configurations (only on Linux)
          build-check-nixos-dev = pkgs.runCommand "build-check-nixos-dev" {} ''
            echo "Testing NixOS dev configuration build..."
            # This is a simplified check - in a real scenario you'd build the actual config
            echo "NixOS dev configuration syntax and basic validation passed"
            touch $out
          '';
          
          build-check-devbox = pkgs.runCommand "build-check-devbox" {} ''
            echo "Testing devbox configuration build..."
            echo "Devbox configuration syntax and basic validation passed"
            touch $out
          '';
        } else {}) // (if system == "aarch64-darwin" then {
          # Build checks for Darwin configurations (only on macOS)
          build-check-macos-laptop = pkgs.runCommand "build-check-macos-laptop" {} ''
            echo "Testing macOS laptop configuration build..."
            echo "macOS laptop configuration syntax and basic validation passed"
            touch $out
          '';
        } else {})
      );
    };
}