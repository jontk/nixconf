# Services configuration for nixos-dev host
{ config, lib, pkgs, ... }:

{
  # Enable nixconf services
  nixconf.services = {
    enable = true;
    
    # Database services
    databases = {
      enable = true;
      
      postgresql = {
        enable = true;
        databases = [ "development" "test" "myapp" ];
        # Extensions will be available for all databases
        extensions = with pkgs.postgresql16Packages; [
          postgis  # Spatial database
          pg_cron  # Job scheduling
          # timescaledb  # Time-series data - disabled due to build issues
        ];
      };
      
      redis = {
        enable = true;
        maxMemory = "512mb";  # Increase for development
        persistence = true;   # Keep data between restarts
      };
      
      # Uncomment to enable other databases
      # mysql.enable = true;
      # mongodb.enable = true;
    };
    
    # Web server services
    webServers = {
      enable = true;
      
      nginx = {
        enable = true;
        
        # Define upstreams for load balancing
        upstreams = {
          app = {
            servers = {
              "127.0.0.1:3001" = {};
              "127.0.0.1:3002" = {};
              "127.0.0.1:3003" = {};
            };
            extraConfig = ''
              least_conn;
              keepalive 32;
            '';
          };
        };
        
        virtualHosts = {
          # Static file server
          "static.local" = {
            port = 8090;
            root = "/var/www/static";
            extraConfig = ''
              autoindex on;
            '';
          };
          
          # API proxy
          "api.local" = {
            port = 8081;
            locations = {
              "/" = {
                proxyPass = "http://app";
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection 'upgrade';
                  proxy_set_header Host $host;
                  proxy_cache_bypass $http_upgrade;
                '';
              };
            };
          };
          
          # Development server with hot reload support
          "dev.local" = {
            port = 8082;
            locations = {
              "/" = {
                proxyPass = "http://localhost:3000";
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection 'upgrade';
                  proxy_set_header Host $host;
                  proxy_cache_bypass $http_upgrade;
                  
                  # WebSocket support for hot reload
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_read_timeout 86400;
                '';
              };
            };
          };
        };
      };
      
      # Uncomment to use Caddy instead of Nginx
      # caddy = {
      #   enable = true;
      #   virtualHosts = {
      #     "app.local" = {
      #       port = 8080;
      #       reverseProxy = "localhost:3000";
      #     };
      #   };
      # };
    };
    
    # Monitoring services
    monitoring = {
      enable = true;
      
      prometheus = {
        enable = true;
        retentionTime = "7d";  # Keep metrics for a week in dev
        exporters = {
          node = true;      # System metrics
          postgres = true;  # PostgreSQL metrics
          redis = true;     # Redis metrics
          nginx = true;     # Nginx metrics
        };
      };
      
      grafana = {
        enable = true;
        adminPassword = "change-me"; # Override in /etc/nixos/secrets or via sops
        theme = "dark";
      };
      
      # Enable log aggregation
      loki = {
        enable = true;
      };
      
      # Enable alerting (optional)
      # alertmanager = {
      #   enable = true;
      #   slackWebhookUrl = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL";
      # };
    };
  };
  
  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/www/static 0755 nginx nginx -"
  ];
  
  # Add entries to /etc/hosts for local development
  networking.hosts = {
    "127.0.0.1" = [ "static.local" "api.local" "dev.local" ];
  };
}