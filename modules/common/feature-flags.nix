{ config, lib, ... }:

let
  cfg = config.nixconf.features;
in
{
  # Feature flag system for modular configuration
  options.nixconf.features = with lib; {
    # Development features
    development = {
      enable = mkEnableOption "development environment";
      rust = mkEnableOption "Rust development tools";
      python = mkEnableOption "Python development tools";
      nodejs = mkEnableOption "Node.js development tools";
      go = mkEnableOption "Go development tools";
      java = mkEnableOption "Java development tools";
      cpp = mkEnableOption "C/C++ development tools";
      docker = mkEnableOption "Docker and containerization";
      kubernetes = mkEnableOption "Kubernetes tools";
    };
    
    # Desktop features (NixOS only)
    desktop = {
      enable = mkEnableOption "desktop environment";
      hyprland = mkEnableOption "Hyprland window manager";
      gaming = mkEnableOption "gaming support";
      multimedia = mkEnableOption "multimedia applications";
      office = mkEnableOption "office applications";
    };
    
    # Server features
    server = {
      enable = mkEnableOption "server configuration";
      web = mkEnableOption "web server capabilities";
      database = mkEnableOption "database services";
      monitoring = mkEnableOption "monitoring and logging";
    };
    
    # Security features
    security = {
      hardening = mkEnableOption "security hardening";
      vpn = mkEnableOption "VPN support";
      tor = mkEnableOption "Tor support";
      yubikey = mkEnableOption "YubiKey support";
    };
    
    # Remote access features
    remote = {
      ssh = mkEnableOption "SSH server" // { default = true; };
      rustdesk = mkEnableOption "RustDesk remote desktop";
      vnc = mkEnableOption "VNC server";
      rdp = mkEnableOption "RDP server";
    };
    
    # Backup and sync features
    backup = {
      enable = mkEnableOption "backup solutions";
      restic = mkEnableOption "Restic backup";
      syncthing = mkEnableOption "Syncthing file sync";
      nextcloud = mkEnableOption "Nextcloud client";
    };
    
    # Virtualization features
    virtualization = {
      docker = mkEnableOption "Docker";
      podman = mkEnableOption "Podman";
      libvirt = mkEnableOption "libvirt/KVM";
      virtualbox = mkEnableOption "VirtualBox";
    };
    
    # Network features
    network = {
      zerotier = mkEnableOption "ZeroTier networking";
      wireguard = mkEnableOption "WireGuard VPN";
      tailscale = mkEnableOption "Tailscale mesh VPN";
    };
  };
  
  # Feature flag implications - automatically enable related features
  config = {
    nixconf.features = {
      # Development implies common development tools
      development.enable = lib.mkDefault (
        cfg.development.rust || 
        cfg.development.python || 
        cfg.development.nodejs || 
        cfg.development.go || 
        cfg.development.java || 
        cfg.development.cpp
      );
      
      # Desktop implies multimedia
      desktop.multimedia = lib.mkDefault cfg.desktop.enable;
      
      # Server implies remote SSH
      remote.ssh = lib.mkDefault cfg.server.enable;
      
      # Security hardening implies specific configurations
      security.hardening = lib.mkDefault (
        cfg.security.vpn || 
        cfg.security.tor || 
        cfg.security.yubikey
      );
      
      # Virtualization implies development
      development.enable = lib.mkDefault (
        cfg.virtualization.docker || 
        cfg.virtualization.podman || 
        cfg.virtualization.libvirt
      );
    };
  };
}