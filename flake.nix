{
  description = "Nix Configuration for macOS and NixOS Development Environments";

  inputs = {
    # Nixpkgs - using unstable for latest packages and features
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Stable nixpkgs for production systems (optional fallback)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";

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
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, home-manager, hyprland, nixos-hardware, flake-utils, flake-parts, rust-overlay, nix-vscode-extensions, firefox-addons, sops-nix }:
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
              inputs = { inherit rust-overlay nix-vscode-extensions firefox-addons sops-nix; };
            };
          }
        else
          nixpkgs.lib.nixosSystem {
            inherit system modules;
            specialArgs = specialArgs // { 
              inherit self nixpkgs nixpkgs-stable nixos-hardware pkgs;
              inputs = { inherit hyprland rust-overlay nix-vscode-extensions firefox-addons sops-nix; };
            };
          };
      
      # Common configuration shared across systems
      commonModules = [
        ./modules/common
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

      # Host-specific configurations
      hostConfigs = {
        # NixOS configurations
        nixos-dev = {
          system = "x86_64-linux";
          modules = [
            ./hosts/nixos-dev
            home-manager.nixosModules.home-manager
            hyprland.nixosModules.default
          ] ++ commonModules ++ developmentModules ++ desktopModules ++ remoteAccessModules;
          specialArgs = { inherit hyprland; };
        };

        devbox = {
          system = "x86_64-linux";
          modules = [
            ./hosts/devbox
            home-manager.nixosModules.home-manager
            hyprland.nixosModules.default
          ] ++ commonModules ++ developmentModules ++ desktopModules ++ remoteAccessModules;
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
        } // (import ./packages { inherit pkgs; }));

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
    };
}