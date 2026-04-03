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
      ignoreIP = mkOption {
        type = types.listOf types.str;
        default = [
          "127.0.0.1/8"      # Localhost
          "::1"              # IPv6 localhost
          "192.168.0.0/16"   # Private network (includes 192.168.1.x)
          "10.0.0.0/8"       # Private network
          "172.16.0.0/12"    # Private network
          "fc00::/7"         # IPv6 private network
        ];
        description = "IP addresses or CIDR masks to ignore (never ban)";
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

    vpn = {
      wireguard = {
        enable = mkEnableOption "WireGuard VPN";
        interfaces = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              privateKeyFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Path to the private key file";
              };
              listenPort = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Port to listen on (null for client mode)";
              };
              ips = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "IP addresses for this interface";
              };
              peers = mkOption {
                type = types.listOf (types.submodule {
                  options = {
                    publicKey = mkOption {
                      type = types.str;
                      description = "Public key of the peer";
                    };
                    allowedIPs = mkOption {
                      type = types.listOf types.str;
                      description = "IP ranges that can be routed to this peer";
                    };
                    endpoint = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Endpoint address (for client mode)";
                    };
                    persistentKeepalive = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "Keepalive interval in seconds";
                    };
                  };
                });
                default = [ ];
                description = "WireGuard peers";
              };
            };
          });
          default = { };
          description = "WireGuard interface configurations";
        };
      };
      
      tailscale = {
        enable = mkEnableOption "Tailscale VPN";
        authKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to Tailscale auth key file";
        };
        useRoutingFeatures = mkOption {
          type = types.enum [ "none" "client" "server" "both" ];
          default = "client";
          description = "Routing features to enable";
        };
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
        ignoreIP = cfg.fail2ban.ignoreIP;
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
              ignoreip = lib.concatStringsSep " " cfg.fail2ban.ignoreIP;
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

          # Limit new SSH connections (exempt local network)
          iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -s 192.168.1.0/24 -m state --state NEW -j ACCEPT
          iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m state --state NEW -m recent --set
          iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j DROP
        '';
      };
    }

    # WireGuard VPN Configuration
    (mkIf cfg.vpn.wireguard.enable {
      networking.wireguard.interfaces = cfg.vpn.wireguard.interfaces;
      
      # Open firewall ports for WireGuard interfaces
      networking.firewall.allowedUDPPorts = lib.flatten (
        lib.mapAttrsToList (name: cfg: 
          lib.optional (cfg.listenPort != null) cfg.listenPort
        ) cfg.vpn.wireguard.interfaces
      );
      
      # Enable IP forwarding if acting as a VPN server
      boot.kernel.sysctl = mkIf (lib.any (cfg: cfg.listenPort != null) 
        (lib.attrValues cfg.vpn.wireguard.interfaces)) {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
    })

    # Tailscale VPN Configuration
    (mkIf cfg.vpn.tailscale.enable {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = cfg.vpn.tailscale.useRoutingFeatures;
        authKeyFile = cfg.vpn.tailscale.authKeyFile;
      };
      
      # Ensure tailscale is started after network
      systemd.services.tailscaled.after = [ "network-online.target" ];
      systemd.services.tailscaled.wants = [ "network-online.target" ];
    })

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
        
        # VPN tools
        wireguard-tools
        openvpn
      ] ++ lib.optional cfg.vpn.tailscale.enable tailscale;
    }
  ]);
}