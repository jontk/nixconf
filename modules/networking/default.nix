# Advanced Networking and VPN Configuration Module
# Provides WireGuard VPN, service discovery, and advanced networking features

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.networking;
  isNixOS = pkgs.stdenv.isLinux;
in

{
  options.modules.networking = {
    enable = mkEnableOption "advanced networking and VPN configuration";
    
    wireguard = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable WireGuard VPN";
      };
      
      server = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WireGuard server mode";
        };
        
        interface = mkOption {
          type = types.str;
          default = "wg0";
          description = "WireGuard interface name";
        };
        
        port = mkOption {
          type = types.int;
          default = 51820;
          description = "WireGuard server port";
        };
        
        privateKeyFile = mkOption {
          type = types.str;
          default = "/etc/wireguard/private";
          description = "Path to private key file";
        };
        
        publicKey = mkOption {
          type = types.str;
          default = "";
          description = "Server public key";
        };
        
        serverIP = mkOption {
          type = types.str;
          default = "10.100.0.1/24";
          description = "Server IP address with subnet";
        };
        
        clientRange = mkOption {
          type = types.str;
          default = "10.100.0.0/24";
          description = "Client IP range";
        };
        
        dns = mkOption {
          type = types.listOf types.str;
          default = [ "1.1.1.1" "8.8.8.8" ];
          description = "DNS servers for clients";
        };
        
        allowedIPs = mkOption {
          type = types.listOf types.str;
          default = [ "0.0.0.0/0" "::/0" ];
          description = "Allowed IPs for routing";
        };
      };
      
      client = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WireGuard client mode";
        };
        
        interface = mkOption {
          type = types.str;
          default = "wg0";
          description = "WireGuard interface name";
        };
        
        privateKeyFile = mkOption {
          type = types.str;
          default = "/etc/wireguard/private";
          description = "Path to client private key file";
        };
        
        serverEndpoint = mkOption {
          type = types.str;
          default = "";
          description = "Server endpoint (host:port)";
        };
        
        serverPublicKey = mkOption {
          type = types.str;
          default = "";
          description = "Server public key";
        };
        
        clientIP = mkOption {
          type = types.str;
          default = "10.100.0.2/24";
          description = "Client IP address";
        };
        
        allowedIPs = mkOption {
          type = types.listOf types.str;
          default = [ "0.0.0.0/0" "::/0" ];
          description = "Allowed IPs through tunnel";
        };
        
        dns = mkOption {
          type = types.listOf types.str;
          default = [ "1.1.1.1" "8.8.8.8" ];
          description = "DNS servers";
        };
        
        persistentKeepalive = mkOption {
          type = types.int;
          default = 25;
          description = "Persistent keepalive interval";
        };
      };
      
      peers = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Peer name";
            };
            
            publicKey = mkOption {
              type = types.str;
              description = "Peer public key";
            };
            
            allowedIPs = mkOption {
              type = types.listOf types.str;
              description = "Allowed IPs for this peer";
            };
            
            endpoint = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Peer endpoint (for clients connecting to server)";
            };
            
            persistentKeepalive = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Persistent keepalive interval";
            };
          };
        });
        default = [];
        description = "WireGuard peers configuration";
      };
    };
    
    serviceDiscovery = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable service discovery with Avahi/mDNS";
      };
      
      avahi = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Avahi daemon";
        };
        
        publish = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable publishing services";
          };
          
          addresses = mkOption {
            type = types.bool;
            default = true;
            description = "Publish addresses";
          };
          
          workstation = mkOption {
            type = types.bool;
            default = true;
            description = "Publish workstation service";
          };
        };
        
        nssmdns = mkOption {
          type = types.bool;
          default = true;
          description = "Enable NSS mDNS support";
        };
      };
      
      services = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Service name";
            };
            
            type = mkOption {
              type = types.str;
              description = "Service type (e.g., _http._tcp)";
            };
            
            port = mkOption {
              type = types.int;
              description = "Service port";
            };
            
            txtRecords = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "TXT records for the service";
            };
          };
        });
        default = [];
        description = "Services to publish via mDNS";
      };
    };
    
    dns = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable advanced DNS configuration";
      };
      
      resolver = mkOption {
        type = types.enum [ "systemd-resolved" "dnsmasq" "unbound" ];
        default = "systemd-resolved";
        description = "DNS resolver to use";
      };
      
      servers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
        description = "DNS servers";
      };
      
      domains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Search domains";
      };
      
      dnssec = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNSSEC validation";
      };
      
      doh = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable DNS over HTTPS";
        };
        
        url = mkOption {
          type = types.str;
          default = "https://cloudflare-dns.com/dns-query";
          description = "DoH server URL";
        };
      };
    };
    
    networkNamespaces = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable network namespace management";
      };
      
      namespaces = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Namespace name";
            };
            
            interfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Network interfaces to move to namespace";
            };
            
            routes = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Routes to add in namespace";
            };
            
            dns = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "DNS servers for namespace";
            };
          };
        });
        default = [];
        description = "Network namespaces configuration";
      };
    };
    
    trafficShaping = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable traffic shaping and QoS";
      };
      
      interfaces = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Interface name";
            };
            
            downloadBandwidth = mkOption {
              type = types.str;
              default = "1gbit";
              description = "Download bandwidth limit";
            };
            
            uploadBandwidth = mkOption {
              type = types.str;
              default = "1gbit";
              description = "Upload bandwidth limit";
            };
            
            classes = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    description = "Traffic class name";
                  };
                  
                  priority = mkOption {
                    type = types.int;
                    description = "Class priority (lower = higher priority)";
                  };
                  
                  rate = mkOption {
                    type = types.str;
                    description = "Guaranteed rate";
                  };
                  
                  ceil = mkOption {
                    type = types.str;
                    description = "Maximum rate";
                  };
                  
                  filters = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Traffic filters for this class";
                  };
                };
              });
              default = [];
              description = "Traffic classes";
            };
          };
        });
        default = [];
        description = "Interface traffic shaping configuration";
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network monitoring";
      };
      
      tools = mkOption {
        type = types.bool;
        default = true;
        description = "Install network monitoring tools";
      };
      
      bandwidthMonitoring = mkOption {
        type = types.bool;
        default = true;
        description = "Enable bandwidth monitoring";
      };
      
      connectionTracking = mkOption {
        type = types.bool;
        default = true;
        description = "Enable connection tracking";
      };
    };
  };

  config = mkIf (cfg.enable && isNixOS) {
    # WireGuard Configuration
    networking.wireguard = mkIf cfg.wireguard.enable {
      enable = true;
      
      interfaces = mkMerge [
        # Server configuration
        (mkIf cfg.wireguard.server.enable {
          ${cfg.wireguard.server.interface} = {
            ips = [ cfg.wireguard.server.serverIP ];
            listenPort = cfg.wireguard.server.port;
            privateKeyFile = cfg.wireguard.server.privateKeyFile;
            
            peers = map (peer: {
              inherit (peer) publicKey allowedIPs;
              persistentKeepalive = peer.persistentKeepalive;
            }) cfg.wireguard.peers;
            
            # Server post-setup commands
            postSetup = ''
              ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.wireguard.server.clientRange} -o eth0 -j MASQUERADE
              ${pkgs.iptables}/bin/iptables -A FORWARD -i ${cfg.wireguard.server.interface} -j ACCEPT
              ${pkgs.iptables}/bin/iptables -A FORWARD -o ${cfg.wireguard.server.interface} -j ACCEPT
            '';
            
            postShutdown = ''
              ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.wireguard.server.clientRange} -o eth0 -j MASQUERADE
              ${pkgs.iptables}/bin/iptables -D FORWARD -i ${cfg.wireguard.server.interface} -j ACCEPT
              ${pkgs.iptables}/bin/iptables -D FORWARD -o ${cfg.wireguard.server.interface} -j ACCEPT
            '';
          };
        })
        
        # Client configuration
        (mkIf cfg.wireguard.client.enable {
          ${cfg.wireguard.client.interface} = {
            ips = [ cfg.wireguard.client.clientIP ];
            privateKeyFile = cfg.wireguard.client.privateKeyFile;
            
            peers = [{
              publicKey = cfg.wireguard.client.serverPublicKey;
              allowedIPs = cfg.wireguard.client.allowedIPs;
              endpoint = cfg.wireguard.client.serverEndpoint;
              persistentKeepalive = cfg.wireguard.client.persistentKeepalive;
            }];
          };
        })
      ];
    };
    
    # Enable IP forwarding for WireGuard server
    boot.kernel.sysctl = mkIf (cfg.wireguard.enable && cfg.wireguard.server.enable) {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    
    # Firewall configuration for WireGuard
    networking.firewall = mkIf cfg.wireguard.enable {
      allowedUDPPorts = mkIf cfg.wireguard.server.enable [ cfg.wireguard.server.port ];
      trustedInterfaces = [ 
        (mkIf cfg.wireguard.server.enable cfg.wireguard.server.interface)
        (mkIf cfg.wireguard.client.enable cfg.wireguard.client.interface)
      ];
    };
    
    # Service Discovery with Avahi
    services.avahi = mkIf cfg.serviceDiscovery.enable {
      enable = cfg.serviceDiscovery.avahi.enable;
      nssmdns = cfg.serviceDiscovery.avahi.nssmdns;
      publish = cfg.serviceDiscovery.avahi.publish;
      
      extraServiceFiles = mkMerge (map (service: {
        "${service.name}" = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">${service.name} on %h</name>
            <service>
              <type>${service.type}</type>
              <port>${toString service.port}</port>
              ${concatMapStrings (txt: "<txt-record>${txt}</txt-record>\n") service.txtRecords}
            </service>
          </service-group>
        '';
      }) cfg.serviceDiscovery.services);
    };
    
    # DNS Configuration
    services.resolved = mkIf (cfg.dns.enable && cfg.dns.resolver == "systemd-resolved") {
      enable = true;
      dnssec = if cfg.dns.dnssec then "true" else "false";
      domains = cfg.dns.domains;
      fallbackDns = cfg.dns.servers;
      extraConfig = ''
        DNS=${concatStringsSep " " cfg.dns.servers}
        ${optionalString cfg.dns.doh.enable "DNS=${cfg.dns.doh.url}"}
        Cache=yes
        CacheFromLocalhost=no
      '';
    };
    
    # DNS over HTTPS with cloudflared
    services.cloudflared = mkIf (cfg.dns.enable && cfg.dns.doh.enable) {
      enable = true;
      tunnels = {
        dns = {
          credentialsFile = "/etc/cloudflared/cert.pem";
          default = "http_status:404";
        };
      };
    };
    
    # Network Namespaces Management
    systemd.services = mkMerge (map (ns: {
      "netns-${ns.name}" = {
        description = "Network namespace ${ns.name}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "netns-${ns.name}-start" ''
            set -euo pipefail
            
            # Create namespace
            ${pkgs.iproute2}/bin/ip netns add ${ns.name} || true
            
            # Move interfaces to namespace
            ${concatMapStrings (iface: ''
              ${pkgs.iproute2}/bin/ip link set ${iface} netns ${ns.name} || true
            '') ns.interfaces}
            
            # Configure routes in namespace
            ${concatMapStrings (route: ''
              ${pkgs.iproute2}/bin/ip netns exec ${ns.name} ip route add ${route} || true
            '') ns.routes}
            
            # Configure DNS in namespace
            ${optionalString (ns.dns != []) ''
              mkdir -p /etc/netns/${ns.name}
              echo "${concatMapStrings (dns: "nameserver ${dns}\n") ns.dns}" > /etc/netns/${ns.name}/resolv.conf
            ''}
          '';
          
          ExecStop = pkgs.writeShellScript "netns-${ns.name}-stop" ''
            ${pkgs.iproute2}/bin/ip netns delete ${ns.name} || true
          '';
        };
      };
    }) cfg.networkNamespaces.namespaces);
    
    # Traffic Shaping with tc
    systemd.services = mkMerge (map (iface: {
      "traffic-shaping-${iface.name}" = mkIf cfg.trafficShaping.enable {
        description = "Traffic shaping for ${iface.name}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "traffic-shaping-${iface.name}-start" ''
            set -euo pipefail
            
            # Clear existing rules
            ${pkgs.iproute2}/bin/tc qdisc del dev ${iface.name} root 2>/dev/null || true
            
            # Create root qdisc
            ${pkgs.iproute2}/bin/tc qdisc add dev ${iface.name} root handle 1: htb default 30
            
            # Create classes
            ${concatMapStringsSep "\n" (class: ''
              ${pkgs.iproute2}/bin/tc class add dev ${iface.name} parent 1: classid 1:${toString class.priority} htb rate ${class.rate} ceil ${class.ceil}
              
              # Add filters for this class
              ${concatMapStringsSep "\n" (filter: ''
                ${pkgs.iproute2}/bin/tc filter add dev ${iface.name} protocol ip parent 1:0 prio ${toString class.priority} ${filter} flowid 1:${toString class.priority}
              '') class.filters}
            '') iface.classes}
          '';
          
          ExecStop = pkgs.writeShellScript "traffic-shaping-${iface.name}-stop" ''
            ${pkgs.iproute2}/bin/tc qdisc del dev ${iface.name} root 2>/dev/null || true
          '';
        };
      };
    }) cfg.trafficShaping.interfaces);
    
    # Network monitoring tools
    environment.systemPackages = mkIf cfg.monitoring.tools (with pkgs; [
      # Basic networking tools
      iproute2
      nettools
      iputils
      dnsutils
      tcpdump
      wireshark-cli
      
      # Network monitoring
      iftop
      nethogs
      nload
      vnstat
      ss
      
      # VPN tools
      wireguard-tools
      
      # Service discovery
      avahi
      
      # Advanced tools
      mtr
      traceroute
      nc
      socat
      nmap
      iperf3
    ]);
    
    # WireGuard key generation helper
    environment.systemPackages = mkIf cfg.wireguard.enable [
      (pkgs.writeShellScriptBin "wg-keygen" ''
        #!/usr/bin/env bash
        # WireGuard key generation helper
        
        set -euo pipefail
        
        show_usage() {
          cat << EOF
        Usage: wg-keygen [OPTIONS] COMMAND
        
        WireGuard key management utility
        
        COMMANDS:
          generate-keys           Generate private/public key pair
          generate-psk           Generate pre-shared key
          show-public <private>  Show public key from private key
          generate-config        Generate client configuration
          
        OPTIONS:
          -o, --output DIR       Output directory (default: current)
          -n, --name NAME        Key name prefix (default: peer)
          -h, --help             Show this help
          
        EXAMPLES:
          wg-keygen generate-keys -n server
          wg-keygen generate-config -n client1
        EOF
        }
        
        output_dir="."
        name_prefix="peer"
        
        while [[ $# -gt 0 ]]; do
          case $1 in
            -o|--output)
              output_dir="$2"
              shift 2
              ;;
            -n|--name)
              name_prefix="$2"
              shift 2
              ;;
            -h|--help)
              show_usage
              exit 0
              ;;
            generate-keys|generate-psk|show-public|generate-config)
              command="$1"
              shift
              break
              ;;
            *)
              echo "Unknown option: $1"
              show_usage
              exit 1
              ;;
          esac
        done
        
        mkdir -p "$output_dir"
        
        case "''${command:-help}" in
          generate-keys)
            echo "Generating WireGuard key pair..."
            private_key=$(${pkgs.wireguard-tools}/bin/wg genkey)
            public_key=$(echo "$private_key" | ${pkgs.wireguard-tools}/bin/wg pubkey)
            
            echo "$private_key" > "$output_dir/$name_prefix.private"
            echo "$public_key" > "$output_dir/$name_prefix.public"
            
            chmod 600 "$output_dir/$name_prefix.private"
            chmod 644 "$output_dir/$name_prefix.public"
            
            echo "Private key: $output_dir/$name_prefix.private"
            echo "Public key: $output_dir/$name_prefix.public"
            echo "Public key: $public_key"
            ;;
          generate-psk)
            echo "Generating pre-shared key..."
            psk=$(${pkgs.wireguard-tools}/bin/wg genpsk)
            echo "$psk" > "$output_dir/$name_prefix.psk"
            chmod 600 "$output_dir/$name_prefix.psk"
            echo "Pre-shared key: $output_dir/$name_prefix.psk"
            ;;
          show-public)
            private_file="''${1:-}"
            if [[ -z "$private_file" ]]; then
              echo "Error: Private key file required"
              exit 1
            fi
            ${pkgs.wireguard-tools}/bin/wg pubkey < "$private_file"
            ;;
          generate-config)
            echo "Generating WireGuard client configuration..."
            echo "This will create a basic client config template."
            echo "You'll need to fill in server details manually."
            
            cat > "$output_dir/$name_prefix.conf" << 'EOL'
        [Interface]
        PrivateKey = <CLIENT_PRIVATE_KEY>
        Address = 10.100.0.2/24
        DNS = 1.1.1.1, 8.8.8.8
        
        [Peer]
        PublicKey = <SERVER_PUBLIC_KEY>
        Endpoint = <SERVER_IP>:51820
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25
        EOL
            
            echo "Client config template: $output_dir/$name_prefix.conf"
            echo "Remember to fill in the actual keys and server details!"
            ;;
          *)
            show_usage
            ;;
        esac
      '')
    ];
    
    # Network monitoring service
    systemd.services.network-monitoring = mkIf cfg.monitoring.enable {
      description = "Network monitoring and statistics";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "network-monitoring" ''
          set -euo pipefail
          
          echo "=== Network Monitoring Report ==="
          echo "Timestamp: $(date)"
          echo ""
          
          echo "=== Interface Statistics ==="
          ${pkgs.iproute2}/bin/ip -s link show
          echo ""
          
          echo "=== Routing Table ==="
          ${pkgs.iproute2}/bin/ip route show
          echo ""
          
          echo "=== Connection Statistics ==="
          ${pkgs.nettools}/bin/netstat -tuln 2>/dev/null || ${pkgs.iproute2}/bin/ss -tuln
          echo ""
          
          ${optionalString cfg.wireguard.enable ''
            echo "=== WireGuard Status ==="
            ${pkgs.wireguard-tools}/bin/wg show || echo "No WireGuard interfaces"
            echo ""
          ''}
          
          ${optionalString cfg.monitoring.bandwidthMonitoring ''
            echo "=== Bandwidth Usage ==="
            ${pkgs.vnstat}/bin/vnstat -i eth0 2>/dev/null || echo "vnstat not configured"
            echo ""
          ''}
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Network monitoring timer
    systemd.timers.network-monitoring = mkIf cfg.monitoring.enable {
      description = "Network monitoring timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
    
    # Bandwidth monitoring with vnstat
    services.vnstat = mkIf (cfg.monitoring.enable && cfg.monitoring.bandwidthMonitoring) {
      enable = true;
    };
  };
}