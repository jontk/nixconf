# Secrets Management Module
{ config, lib, pkgs, inputs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  cfg = config.modules.secrets;
in
{
  imports = lib.optionals (inputs ? sops-nix) [ inputs.sops-nix.nixosModules.sops ];

  options.modules.secrets = with lib; {
    enable = mkEnableOption "secrets management with sops-nix";
    
    defaultSopsFile = mkOption {
      type = types.path;
      default = ../../secrets/secrets.yaml;
      description = "Default sops file location";
    };
    
    secrets = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          sopsFile = mkOption {
            type = types.path;
            default = cfg.defaultSopsFile;
            description = "Sops file containing the secret";
          };
          
          owner = mkOption {
            type = types.str;
            default = "root";
            description = "Owner of the secret file";
          };
          
          group = mkOption {
            type = types.str;
            default = "root";
            description = "Group of the secret file";
          };
          
          mode = mkOption {
            type = types.str;
            default = "0400";
            description = "Permissions of the secret file";
          };
        };
      });
      default = {};
      description = "Secrets to decrypt and make available";
    };
  };

  config = lib.mkIf cfg.enable {
    # Only configure if sops-nix is available
    sops = lib.mkIf (inputs ? sops-nix && isNixOS) {
      defaultSopsFile = cfg.defaultSopsFile;
      
      # Age key file location
      age.keyFile = "/var/lib/sops-nix/key.txt";
      
      # Secrets configuration
      secrets = cfg.secrets;
    };

    # Alternative: simple file-based secrets for development
    systemd.tmpfiles.rules = lib.mkIf (!(inputs ? sops-nix) && isNixOS) (
      lib.mapAttrsToList (name: secret: 
        "d /run/secrets 0755 root root -"
      ) cfg.secrets
    );

    # Secrets directory structure and tools
    environment.systemPackages = with pkgs; lib.optionals isNixOS ([
      sops  # For manual secret management
      age   # For encryption
    ] ++ [
      (pkgs.writeShellScriptBin "secrets-init" ''
        #!/bin/bash
        # Initialize secrets management
        
        if [ ! -d "/var/lib/sops-nix" ]; then
          sudo mkdir -p /var/lib/sops-nix
          sudo chmod 700 /var/lib/sops-nix
        fi
        
        if [ ! -f "/var/lib/sops-nix/key.txt" ]; then
          echo "Generating age key..."
          ${pkgs.age}/bin/age-keygen -o /tmp/age-key.txt
          sudo mv /tmp/age-key.txt /var/lib/sops-nix/key.txt
          sudo chmod 600 /var/lib/sops-nix/key.txt
          echo "Age key generated at /var/lib/sops-nix/key.txt"
          echo "Public key:"
          grep "public key:" /var/lib/sops-nix/key.txt
        fi
      '')
    ]);
  };
}