{ config, pkgs, lib, nixpkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

{
  # Advanced Nix configuration settings
  nix = {
    # Package management settings
    package = pkgs.nixVersions.stable;
    
    # Registry for flake shortcuts
    registry = {
      nixpkgs.flake = nixpkgs;
    };
    
    # NIX_PATH for legacy commands
    nixPath = [ 
      "nixpkgs=${nixpkgs}"
    ];
    
    # Build settings for better performance
    settings = {
      # Sandbox builds for security (relaxed on Darwin due to macOS limitations)
      sandbox = if pkgs.stdenv.isDarwin then "relaxed" else true;
      
      # Build users for parallel builds
      build-users-group = if pkgs.stdenv.isDarwin then "nixbld" else "nixbld";
      
      # Optimize storage (on Darwin, use nix.optimise.automatic instead)
      auto-optimise-store = lib.mkIf (!pkgs.stdenv.isDarwin) true;
      
      # Build configuration
      builders-use-substitutes = true;
      
      # Network timeout settings
      connect-timeout = 5;
      stalled-download-timeout = 90;
      
      # Download buffer size (default is 64MB, increase to 256MB)
      download-buffer-size = 268435456; # 256 * 1024 * 1024
      
      # Allow building for other architectures
      extra-platforms = lib.mkIf (pkgs.system == "x86_64-linux") [ "i686-linux" ];
      
      # System features (kvm and nixos-test are Linux-only)
      system-features = [ "benchmark" "big-parallel" ]
        ++ lib.optionals (!pkgs.stdenv.isDarwin) [ "nixos-test" "kvm" ];
    };
    
    # Distributed builds configuration (can be extended per-host)
    distributedBuilds = false;
    
    # Build machines (empty by default, can be overridden)
    buildMachines = [ ];
    
    # Extra configuration
    extraOptions = ''
      # Keep build dependencies for debugging
      keep-failed = true
      
      # Show more detailed build logs
      log-lines = 50
      
      # Warn about dirty git trees
      warn-dirty = true
      
      # Enable content-addressed derivations (experimental)
      experimental-features = ca-derivations
    '';
  };
}