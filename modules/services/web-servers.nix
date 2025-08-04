# Web Server Services Configuration
{ config, lib, pkgs, ... }:

let
  cfg = config.nixconf.services.webServers;
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
in
{
  options.nixconf.services.webServers = with lib; {
    enable = mkEnableOption "web server services" // { default = false; };
    
    nginx = {
      enable = mkEnableOption "Nginx web server" // { default = true; };
      
      virtualHosts = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            port = mkOption {
              type = types.port;
              default = 80;
              description = "Port to listen on";
            };
            
            root = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Document root for static files";
            };
            
            locations = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  proxyPass = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Proxy pass URL";
                  };
                  
                  tryFiles = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Try files directive";
                  };
                  
                  extraConfig = mkOption {
                    type = types.lines;
                    default = "";
                    description = "Extra nginx configuration";
                  };
                };
              });
              default = {};
              description = "Location blocks";
            };
            
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra nginx configuration for this virtual host";
            };
          };
        });
        default = {};
        description = "Virtual hosts configuration";
      };
      
      upstreams = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            servers = mkOption {
              type = types.attrsOf (types.attrs);
              default = {};
              description = "Upstream servers";
            };
            
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra upstream configuration";
            };
          };
        });
        default = {};
        description = "Upstream configurations";
      };
    };
    
    caddy = {
      enable = mkEnableOption "Caddy web server" // { default = false; };
      
      virtualHosts = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            port = mkOption {
              type = types.port;
              default = 80;
              description = "Port to listen on";
            };
            
            root = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Document root for static files";
            };
            
            reverseProxy = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Reverse proxy target";
            };
            
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra Caddy configuration";
            };
          };
        });
        default = {};
        description = "Virtual hosts configuration";
      };
    };
    
    apache = {
      enable = mkEnableOption "Apache HTTP Server" // { default = false; };
      
      virtualHosts = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            port = mkOption {
              type = types.port;
              default = 80;
              description = "Port to listen on";
            };
            
            documentRoot = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Document root for static files";
            };
            
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra Apache configuration";
            };
          };
        });
        default = {};
        description = "Virtual hosts configuration";
      };
    };
  };
  
  config = lib.mkIf (cfg.enable && isNixOS) {
    # Nginx configuration
    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      
      clientMaxBodySize = "100m";
      
      commonHttpConfig = ''
        # Real IP settings for proxied requests
        real_ip_header X-Real-IP;
        real_ip_recursive on;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        
        # Additional performance settings
        
        # Logging
        log_format json_combined escape=json
          '{'
            '"time_local":"$time_local",'
            '"remote_addr":"$remote_addr",'
            '"request":"$request",'
            '"status": "$status",'
            '"body_bytes_sent":"$body_bytes_sent",'
            '"request_time":"$request_time",'
            '"http_referrer":"$http_referer",'
            '"http_user_agent":"$http_user_agent"'
          '}';
      '';
      
      # Configure upstreams
      upstreams = cfg.nginx.upstreams;
      
      # Configure virtual hosts
      virtualHosts = lib.mapAttrs (name: vhostCfg: {
        listen = [
          {
            addr = "0.0.0.0";
            port = vhostCfg.port;
          }
        ];
        
        root = vhostCfg.root;
        
        locations = lib.mapAttrs (path: locCfg: {
          proxyPass = locCfg.proxyPass;
          tryFiles = locCfg.tryFiles;
          extraConfig = locCfg.extraConfig;
        }) vhostCfg.locations;
        
        extraConfig = vhostCfg.extraConfig;
      }) cfg.nginx.virtualHosts;
    };
    
    # Caddy configuration
    services.caddy = lib.mkIf cfg.caddy.enable {
      enable = true;
      
      globalConfig = ''
        # Enable debug logging
        debug
        
        # Performance settings
        servers {
          timeouts {
            read_body   30s
            read_header 10s
            write       30s
            idle        2m
          }
          max_header_size 16384
        }
      '';
      
      virtualHosts = lib.mapAttrs (name: vhostCfg: {
        listenAddresses = [ ":${toString vhostCfg.port}" ];
        
        extraConfig = ''
          ${lib.optionalString (vhostCfg.root != null) "root * ${vhostCfg.root}"}
          ${lib.optionalString (vhostCfg.root != null) "file_server"}
          
          ${lib.optionalString (vhostCfg.reverseProxy != null) "reverse_proxy ${vhostCfg.reverseProxy}"}
          
          ${vhostCfg.extraConfig}
        '';
      }) cfg.caddy.virtualHosts;
    };
    
    # Apache configuration
    services.httpd = lib.mkIf cfg.apache.enable {
      enable = true;
      
      extraModules = [
        "proxy"
        "proxy_http"
        "rewrite"
        "headers"
      ];
      
      virtualHosts = lib.mapAttrs (name: vhostCfg: {
        listen = [{
          ip = "*";
          port = vhostCfg.port;
        }];
        
        documentRoot = vhostCfg.documentRoot;
        
        extraConfig = ''
          <Directory "${vhostCfg.documentRoot or "/var/empty"}">
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
          </Directory>
          
          ${vhostCfg.extraConfig}
        '';
      }) cfg.apache.virtualHosts;
    };
    
    # Firewall rules for web servers
    networking.firewall.allowedTCPPorts = 
      lib.unique (
        lib.flatten (
          lib.mapAttrsToList (_: vhost: vhost.port) cfg.nginx.virtualHosts
          ++ lib.mapAttrsToList (_: vhost: vhost.port) cfg.caddy.virtualHosts
          ++ lib.mapAttrsToList (_: vhost: vhost.port) cfg.apache.virtualHosts
        )
      );
    
    # System packages for web development
    environment.systemPackages = with pkgs; 
      lib.optionals cfg.nginx.enable [
        nginx
      ] ++ lib.optionals cfg.caddy.enable [
        caddy
      ] ++ lib.optionals cfg.apache.enable [
        apacheHttpd
      ] ++ [
        # Common web development tools
        curl
        wget
        httpie
        wrk  # HTTP benchmarking tool
        siege  # Load testing tool
        vegeta  # HTTP load testing tool
      ];
    
    # Shell aliases for web servers
    environment.shellAliases = {
      # Nginx
      nginx-test = lib.mkIf cfg.nginx.enable "sudo nginx -t";
      nginx-reload = lib.mkIf cfg.nginx.enable "sudo systemctl reload nginx";
      nginx-logs = lib.mkIf cfg.nginx.enable "sudo journalctl -u nginx -f";
      
      # Caddy
      caddy-reload = lib.mkIf cfg.caddy.enable "sudo systemctl reload caddy";
      caddy-logs = lib.mkIf cfg.caddy.enable "sudo journalctl -u caddy -f";
      
      # Apache
      apache-test = lib.mkIf cfg.apache.enable "sudo apachectl configtest";
      apache-reload = lib.mkIf cfg.apache.enable "sudo systemctl reload httpd";
      apache-logs = lib.mkIf cfg.apache.enable "sudo journalctl -u httpd -f";
      
      # General web testing
      http-test = "curl -I";
      http-bench = "wrk -t12 -c400 -d30s";
    };
  };
}