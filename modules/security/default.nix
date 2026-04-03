# Enhanced Security Module
{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  cfg = config.modules.security;
in
{
  options.modules.security = with lib; {
    enable = mkEnableOption "enhanced security configuration";
    
    auditd.enable = mkEnableOption "audit daemon for security monitoring";
    apparmor.enable = mkEnableOption "AppArmor mandatory access control";
    hardening.enable = mkEnableOption "kernel and system hardening";
  };

  config = lib.mkIf cfg.enable {
    # System hardening
    boot.kernel.sysctl = lib.mkIf (isNixOS && cfg.hardening.enable) {
      # Network security
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.ip_forward" = 0;
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "net.ipv4.tcp_syncookies" = 1;
      
      # Memory protection
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
      
      # File system
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
      "fs.suid_dumpable" = 0;
    };

    # Security audit configuration
    security.auditd = lib.mkIf (isNixOS && cfg.auditd.enable) {
      enable = true;
    };
    
    # AppArmor configuration
    security.apparmor = lib.mkIf (isNixOS && cfg.apparmor.enable) {
      enable = true;
      killUnconfinedConfinables = true;
    };

    # Enhanced firewall rules
    networking.firewall = lib.mkIf isNixOS {
      extraCommands = ''
        # Rate limiting for SSH (exempt local network)
        iptables -A INPUT -p tcp --dport ssh -s 192.168.1.0/24 -m conntrack --ctstate NEW -j ACCEPT
        iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --set
        iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j REJECT --reject-with tcp-reset
        
        # Drop invalid packets
        iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
      '';
    };

    # Security packages
    environment.systemPackages = with pkgs; lib.optionals isNixOS [
      lynis          # Security auditing
      chkrootkit     # Rootkit checker
      rkhunter       # Rootkit hunter
      aide           # File integrity checker
      tiger          # Security audit tool
    ];
  };
}