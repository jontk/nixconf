{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.remoteAccess;
in
{
  options.modules.remoteAccess = {
    enable = mkEnableOption "remote access tools and services";

    ssh = {
      enable = mkEnableOption "SSH server" // { default = true; };
      port = mkOption {
        type = types.int;
        default = 22;
        description = "SSH server port";
      };
      passwordAuthentication = mkOption {
        type = types.bool;
        default = false;
        description = "Allow password authentication (not recommended)";
      };
      permitRootLogin = mkOption {
        type = types.str;
        default = "prohibit-password";
        description = "Permit root login via SSH";
      };
    };

    rustdesk = {
      enable = mkEnableOption "RustDesk remote desktop";
      server = {
        enable = mkEnableOption "RustDesk server";
        relayPort = mkOption {
          type = types.int;
          default = 21117;
          description = "RustDesk relay server port";
        };
        wsPort = mkOption {
          type = types.int;
          default = 21118;
          description = "RustDesk WebSocket port";
        };
        tcpPort = mkOption {
          type = types.int;
          default = 21119;
          description = "RustDesk TCP port";
        };
      };
    };

    fail2ban = {
      enable = mkEnableOption "fail2ban intrusion prevention";
      maxRetries = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum number of retries before ban";
      };
      banTime = mkOption {
        type = types.str;
        default = "10m";
        description = "Ban duration";
      };
    };

    firewall = {
      allowedTCPPorts = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "Additional TCP ports to open";
      };
      allowedUDPPorts = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "Additional UDP ports to open";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # SSH Configuration
    (mkIf cfg.ssh.enable {
      services.openssh = {
        enable = true;
        ports = [ cfg.ssh.port ];
        settings = {
          PasswordAuthentication = cfg.ssh.passwordAuthentication;
          PermitRootLogin = cfg.ssh.permitRootLogin;
          KbdInteractiveAuthentication = false;
          ChallengeResponseAuthentication = false;
          X11Forwarding = false;
          PermitEmptyPasswords = false;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;
          UsePAM = true;
          PrintMotd = false;
        };
        extraConfig = ''
          # Security hardening
          Protocol 2
          StrictModes yes
          MaxAuthTries 3
          MaxSessions 10
          
          # Ciphers and algorithms
          Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
          MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
          KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
          
          # Logging
          LogLevel VERBOSE
          SyslogFacility AUTH
        '';
      };

      # SSH host keys
      services.openssh.hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
    })

    # RustDesk Configuration
    (mkIf cfg.rustdesk.enable {
      environment.systemPackages = with pkgs; [
        rustdesk
      ];

      # RustDesk client service
      systemd.user.services.rustdesk = {
        description = "RustDesk remote desktop client";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.rustdesk}/bin/rustdesk --service";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    })

    # RustDesk Server Configuration
    (mkIf (cfg.rustdesk.enable && cfg.rustdesk.server.enable) {
      environment.systemPackages = with pkgs; [
        rustdesk-server
      ];

      # RustDesk relay server
      systemd.services.rustdesk-relay = {
        description = "RustDesk relay server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.rustdesk-server}/bin/hbbs -r 127.0.0.1:${toString cfg.rustdesk.server.relayPort} -p ${toString cfg.rustdesk.server.tcpPort}";
          Restart = "always";
          RestartSec = 10;
          User = "rustdesk";
          Group = "rustdesk";
          WorkingDirectory = "/var/lib/rustdesk";
          StateDirectory = "rustdesk";
        };
      };

      # RustDesk signal server
      systemd.services.rustdesk-signal = {
        description = "RustDesk signal server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.rustdesk-server}/bin/hbbr -p ${toString cfg.rustdesk.server.relayPort}";
          Restart = "always";
          RestartSec = 10;
          User = "rustdesk";
          Group = "rustdesk";
          WorkingDirectory = "/var/lib/rustdesk";
          StateDirectory = "rustdesk";
        };
      };

      # Create rustdesk user and group
      users.users.rustdesk = {
        isSystemUser = true;
        group = "rustdesk";
        home = "/var/lib/rustdesk";
        createHome = true;
      };
      users.groups.rustdesk = {};

      # Open firewall ports for RustDesk server
      networking.firewall.allowedTCPPorts = [
        cfg.rustdesk.server.relayPort
        cfg.rustdesk.server.wsPort
        cfg.rustdesk.server.tcpPort
        21115 # NAT type test
        21116 # TCP hole punch
      ];
      networking.firewall.allowedUDPPorts = [
        cfg.rustdesk.server.relayPort
      ];
    })

    # Fail2ban Configuration
    (mkIf cfg.fail2ban.enable {
      services.fail2ban = {
        enable = true;
        maxretry = cfg.fail2ban.maxRetries;
        bantime = cfg.fail2ban.banTime;
        bantime-increment = {
          enable = true;
          rndtime = "5m";
          maxtime = "10h";
          factor = "1";
        };
        jails = {
          # SSH jail
          sshd = {
            settings = {
              enabled = true;
              port = toString cfg.ssh.port;
              filter = "sshd";
              maxretry = cfg.fail2ban.maxRetries;
              findtime = "10m";
              bantime = cfg.fail2ban.banTime;
            };
          };
        };
      };
    })

    # Firewall Configuration
    {
      networking.firewall = {
        enable = true;
        allowPing = true;
        
        # SSH port
        allowedTCPPorts = lib.optional cfg.ssh.enable cfg.ssh.port
          ++ cfg.firewall.allowedTCPPorts;
        
        allowedUDPPorts = cfg.firewall.allowedUDPPorts;
        
        # Log dropped packets
        logRefusedConnections = true;
        logRefusedPackets = true;
        logRefusedUnicastsOnly = false;
        
        # Extra firewall rules
        extraCommands = ''
          # Drop invalid packets
          iptables -A INPUT -m state --state INVALID -j DROP
          
          # Limit new SSH connections
          iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m state --state NEW -m recent --set
          iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j DROP
        '';
      };
    }

    # Common packages for remote access
    {
      environment.systemPackages = with pkgs; [
        # SSH tools
        openssh
        sshfs
        sshpass
        autossh
        
        # Network security tools
        nmap
        tcpdump
        wireshark
        iftop
        nethogs
        
        # VPN tools (optional, can be enabled separately)
        wireguard-tools
        openvpn
      ];
    }
  ]);
}