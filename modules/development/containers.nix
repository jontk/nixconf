# Container Development Workflows Module
# Provides comprehensive container development with Docker, Podman, and development containers

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.development.containers;
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = pkgs.stdenv.isLinux;

  # Devcontainer configuration generator
  generateDevcontainerJson = { name, image, features ? {}, customizations ? {}, extensions ? [], settings ? {}, forwardPorts ? [], postCreateCommand ? "" }: ''
    {
      "name": "${name}",
      "image": "${image}",
      "features": ${builtins.toJSON features},
      "customizations": {
        "vscode": {
          "extensions": ${builtins.toJSON extensions},
          "settings": ${builtins.toJSON settings}
        }
      },
      "forwardPorts": ${builtins.toJSON forwardPorts},
      "postCreateCommand": "${postCreateCommand}",
      "remoteUser": "vscode"
    }
  '';

  # Docker compose file generator for development stacks
  generateComposeFile = { version ? "3.8", services, volumes ? {}, networks ? {} }: ''
    version: '${version}'
    services:
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: service: ''
      ${name}:
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: 
          if key == "environment" then
            "    environment:\n${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "      ${k}: ${toString v}") value)}"
          else if key == "ports" then
            "    ports:\n${lib.concatStringsSep "\n" (map (p: "      - \"${toString p}\"") value)}"
          else if key == "volumes" then
            "    volumes:\n${lib.concatStringsSep "\n" (map (v: "      - ${v}") value)}"
          else
            "    ${key}: ${if builtins.isList value then lib.concatStringsSep ", " (map toString value) else toString value}"
        ) service)}
    '') services)}
    ${if volumes != {} then ''
    volumes:
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: vol: "  ${name}: ${if vol == {} then "{}" else builtins.toJSON vol}") volumes)}
    '' else ""}
    ${if networks != {} then ''
    networks:
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: net: "  ${name}: ${if net == {} then "{}" else builtins.toJSON net}") networks)}
    '' else ""}
  '';

in

{
  options.modules.development.containers = {
    enable = mkEnableOption "container development workflows";
    
    docker = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Docker for container development";
      };
      
      buildkit = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Docker BuildKit for improved builds";
      };
      
      compose = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Docker Compose";
        };
        
        version = mkOption {
          type = types.str;
          default = "2.32.1";
          description = "Docker Compose version";
        };
      };
      
      registry = {
        mirrors = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "https://mirror.gcr.io" ];
          description = "Docker registry mirrors";
        };
        
        insecureRegistries = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Insecure registries to allow";
        };
      };
    };
    
    podman = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Podman as Docker alternative";
      };
      
      dockerCompat = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Docker compatibility aliases";
      };
    };
    
    devcontainers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable development container support";
      };
      
      templates = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            image = mkOption {
              type = types.str;
              description = "Base container image";
            };
            
            features = mkOption {
              type = types.attrsOf types.anything;
              default = {};
              description = "Devcontainer features to enable";
            };
            
            extensions = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "VS Code extensions to install";
            };
            
            settings = mkOption {
              type = types.attrsOf types.anything;
              default = {};
              description = "VS Code settings";
            };
            
            forwardPorts = mkOption {
              type = types.listOf types.int;
              default = [];
              description = "Ports to forward";
            };
            
            postCreateCommand = mkOption {
              type = types.str;
              default = "";
              description = "Command to run after container creation";
            };
          };
        });
        default = {};
        description = "Devcontainer templates";
      };
    };
    
    tools = {
      dive = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dive for Docker image exploration";
      };
      
      lazydocker = mkOption {
        type = types.bool;
        default = true;
        description = "Enable lazydocker TUI";
      };
      
      ctop = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ctop for container monitoring";
      };
      
      hadolint = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Dockerfile linting";
      };
    };
    
    development = {
      stacks = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            services = mkOption {
              type = types.attrsOf types.anything;
              description = "Docker Compose services";
            };
            
            volumes = mkOption {
              type = types.attrsOf types.anything;
              default = {};
              description = "Named volumes";
            };
            
            networks = mkOption {
              type = types.attrsOf types.anything;
              default = {};
              description = "Networks configuration";
            };
          };
        });
        default = {};
        description = "Pre-configured development stacks";
      };
    };
  };

  config = mkIf cfg.enable {
    # Container tools packages
    environment.systemPackages = with pkgs; [
      # Docker tools
      (mkIf cfg.docker.enable docker)
      (mkIf (cfg.docker.enable && cfg.docker.compose.enable) docker-compose)
      docker-credential-helpers
      
      # Podman tools
      (mkIf cfg.podman.enable podman)
      (mkIf cfg.podman.enable podman-compose)
      (mkIf cfg.podman.enable buildah)
      (mkIf cfg.podman.enable skopeo)
      
      # Container utilities
      (mkIf cfg.tools.dive dive)
      (mkIf cfg.tools.lazydocker lazydocker)
      (mkIf cfg.tools.ctop ctop)
      (mkIf cfg.tools.hadolint hadolint)
      
      # Additional tools
      docker-slim
      dockerfile-language-server-nodejs
      container-diff
      cosign
      crane
      regctl
      
      # Development container tools
      (mkIf cfg.devcontainers.enable (pkgs.writeShellScriptBin "devcontainer-init" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        TEMPLATE="''${1:-node}"
        
        if [[ ! -d .devcontainer ]]; then
          mkdir -p .devcontainer
        fi
        
        case "$TEMPLATE" in
          ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: config: ''
            ${name})
              cat > .devcontainer/devcontainer.json << 'EOF'
              ${generateDevcontainerJson {
                inherit name;
                inherit (config) image features extensions settings forwardPorts postCreateCommand;
                customizations = config.customizations or {};
              }}
              EOF
              echo "Created ${name} devcontainer configuration"
              ;;
          '') cfg.devcontainers.templates)}
          *)
            echo "Unknown template: $TEMPLATE"
            echo "Available templates: ${lib.concatStringsSep ", " (lib.attrNames cfg.devcontainers.templates)}"
            exit 1
            ;;
        esac
      ''))
      
      # Docker compose stack generator
      (mkIf (cfg.development.stacks != {}) (pkgs.writeShellScriptBin "dev-stack" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        STACK="''${1:-}"
        ACTION="''${2:-up}"
        
        case "$STACK" in
          ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: config: ''
            ${name})
              cat > docker-compose.${name}.yml << 'EOF'
              ${generateComposeFile {
                inherit (config) services volumes networks;
              }}
              EOF
              docker-compose -f docker-compose.${name}.yml $ACTION
              ;;
          '') cfg.development.stacks)}
          list)
            echo "Available stacks: ${lib.concatStringsSep ", " (lib.attrNames cfg.development.stacks)}"
            ;;
          *)
            echo "Usage: dev-stack <stack-name> [up|down|logs|ps]"
            echo "Available stacks: ${lib.concatStringsSep ", " (lib.attrNames cfg.development.stacks)}"
            exit 1
            ;;
        esac
      ''))
    ] ++ lib.flatten (builtins.attrValues {
      inherit (pkgs) dive lazydocker ctop hadolint;
    });
    
    # Environment variables
    environment.variables = mkMerge [
      (mkIf cfg.docker.buildkit {
        DOCKER_BUILDKIT = "1";
        COMPOSE_DOCKER_CLI_BUILD = "1";
      })
      {
        # Container development paths
        DOCKER_CONFIG = "$HOME/.docker";
        CONTAINER_HOST = mkIf cfg.podman.enable "unix:///run/user/$UID/podman/podman.sock";
      }
    ];
    
    # Shell aliases
    environment.shellAliases = mkMerge [
      {
        # Docker shortcuts
        d = "docker";
        dc = "docker-compose";
        dps = "docker ps";
        dpsa = "docker ps -a";
        dex = "docker exec -it";
        dlog = "docker logs -f";
        dimg = "docker images";
        dvol = "docker volume ls";
        dnet = "docker network ls";
        
        # Docker cleanup
        dclean = "docker system prune -af --volumes";
        drmi = "docker rmi $(docker images -f 'dangling=true' -q)";
        drmv = "docker volume rm $(docker volume ls -f 'dangling=true' -q)";
        
        # Docker compose shortcuts
        dcu = "docker-compose up -d";
        dcd = "docker-compose down";
        dcl = "docker-compose logs -f";
        dcp = "docker-compose ps";
        dcr = "docker-compose restart";
        
        # Container inspection
        dinspect = "docker inspect";
        dstats = "docker stats";
        dtop = "docker top";
        
        # Build shortcuts
        dbuild = "docker build -t";
        dbuildx = "docker buildx build --platform linux/amd64,linux/arm64 -t";
      }
      
      (mkIf cfg.podman.dockerCompat {
        # Podman Docker compatibility
        docker = "podman";
        docker-compose = "podman-compose";
      })
    ];
    
    # Docker daemon configuration (NixOS)
    virtualisation = mkIf (isNixOS && cfg.docker.enable) {
      docker = {
        enable = true;
        enableOnBoot = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [ "--all" "--volumes" ];
        };
        
        daemon.settings = {
          features = {
            buildkit = cfg.docker.buildkit;
          };
          registry-mirrors = cfg.docker.registry.mirrors;
          insecure-registries = cfg.docker.registry.insecureRegistries;
          log-driver = "json-file";
          log-opts = {
            max-size = "10m";
            max-file = "3";
          };
        };
      };
      
      # Podman configuration
      podman = mkIf cfg.podman.enable {
        enable = true;
        dockerCompat = cfg.podman.dockerCompat;
        defaultNetwork.settings = {
          dns_enabled = true;
        };
      };
    };
    
    # Pre-configured devcontainer templates
    modules.development.containers.devcontainers.templates = {
      node = {
        image = "mcr.microsoft.com/devcontainers/typescript-node:22";
        features = {
          "ghcr.io/devcontainers/features/common-utils:2" = {
            installZsh = true;
            configureZshAsDefaultShell = true;
            installOhMyZsh = true;
            upgradePackages = true;
          };
          "ghcr.io/devcontainers/features/node:1" = {
            version = "lts";
            nodeGypDependencies = true;
          };
        };
        extensions = [
          "dbaeumer.vscode-eslint"
          "esbenp.prettier-vscode"
          "ms-vscode.vscode-typescript-next"
          "streetsidesoftware.code-spell-checker"
        ];
        settings = {
          "terminal.integrated.defaultProfile.linux" = "zsh";
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        forwardPorts = [ 3000 ];
        postCreateCommand = "npm install";
      };
      
      python = {
        image = "mcr.microsoft.com/devcontainers/python:3.11";
        features = {
          "ghcr.io/devcontainers/features/common-utils:2" = {
            installZsh = true;
            configureZshAsDefaultShell = true;
            installOhMyZsh = true;
          };
          "ghcr.io/devcontainers/features/python:1" = {
            version = "3.11";
            installTools = true;
          };
        };
        extensions = [
          "ms-python.python"
          "ms-python.vscode-pylance"
          "ms-python.black-formatter"
          "charliermarsh.ruff"
        ];
        settings = {
          "python.linting.enabled" = true;
          "python.formatting.provider" = "black";
          "editor.formatOnSave" = true;
        };
        forwardPorts = [ 8000 ];
        postCreateCommand = "pip install -r requirements.txt || true";
      };
      
      go = {
        image = "mcr.microsoft.com/devcontainers/go:1.24";
        features = {
          "ghcr.io/devcontainers/features/common-utils:2" = {
            installZsh = true;
            configureZshAsDefaultShell = true;
          };
          "ghcr.io/devcontainers/features/go:1" = {
            version = "1.24";
          };
        };
        extensions = [
          "golang.go"
          "streetsidesoftware.code-spell-checker"
        ];
        settings = {
          "go.toolsManagement.checkForUpdates" = "local";
          "go.useLanguageServer" = true;
        };
        forwardPorts = [ 8080 ];
        postCreateCommand = "go mod download";
      };
      
      rust = {
        image = "mcr.microsoft.com/devcontainers/rust:1";
        features = {
          "ghcr.io/devcontainers/features/common-utils:2" = {
            installZsh = true;
            configureZshAsDefaultShell = true;
          };
          "ghcr.io/devcontainers/features/rust:1" = {
            version = "latest";
            profile = "default";
          };
        };
        extensions = [
          "rust-lang.rust-analyzer"
          "tamasfe.even-better-toml"
          "serayuzgur.crates"
        ];
        settings = {
          "rust-analyzer.checkOnSave.command" = "clippy";
        };
        forwardPorts = [ 8000 ];
        postCreateCommand = "cargo build";
      };
    };
    
    # Pre-configured development stacks
    modules.development.containers.development.stacks = {
      webapp = {
        services = {
          frontend = {
            image = "node:22-alpine";
            working_dir = "/app";
            volumes = [ "./frontend:/app" "frontend_modules:/app/node_modules" ];
            ports = [ "3000:3000" ];
            environment = {
              NODE_ENV = "development";
            };
            command = "npm run dev";
          };
          
          backend = {
            image = "node:22-alpine";
            working_dir = "/app";
            volumes = [ "./backend:/app" "backend_modules:/app/node_modules" ];
            ports = [ "5000:5000" ];
            environment = {
              NODE_ENV = "development";
              DB_HOST = "postgres";
              REDIS_HOST = "redis";
            };
            command = "npm run dev";
            depends_on = [ "postgres" "redis" ];
          };
          
          postgres = {
            image = "postgres:15-alpine";
            environment = {
              POSTGRES_USER = "developer";
              POSTGRES_PASSWORD = "developer";
              POSTGRES_DB = "development";
            };
            volumes = [ "postgres_data:/var/lib/postgresql/data" ];
            ports = [ "5432:5432" ];
          };
          
          redis = {
            image = "redis:7-alpine";
            ports = [ "6379:6379" ];
          };
          
          nginx = {
            image = "nginx:alpine";
            ports = [ "80:80" ];
            volumes = [ "./nginx.conf:/etc/nginx/nginx.conf:ro" ];
            depends_on = [ "frontend" "backend" ];
          };
        };
        
        volumes = {
          postgres_data = {};
          frontend_modules = {};
          backend_modules = {};
        };
        
        networks = {
          default = {
            driver = "bridge";
          };
        };
      };
      
      microservices = {
        services = {
          api-gateway = {
            image = "node:22-alpine";
            ports = [ "8080:8080" ];
            environment = {
              SERVICE_DISCOVERY = "consul:8500";
            };
          };
          
          consul = {
            image = "consul:latest";
            ports = [ "8500:8500" ];
            command = "agent -dev -ui -client=0.0.0.0";
          };
          
          rabbitmq = {
            image = "rabbitmq:3-management-alpine";
            ports = [ "5672:5672" "15672:15672" ];
            environment = {
              RABBITMQ_DEFAULT_USER = "developer";
              RABBITMQ_DEFAULT_PASS = "developer";
            };
          };
          
          jaeger = {
            image = "jaegertracing/all-in-one:latest";
            ports = [ "16686:16686" "14268:14268" ];
            environment = {
              COLLECTOR_ZIPKIN_HOST_PORT = ":9411";
            };
          };
        };
      };
      
      datascience = {
        services = {
          jupyter = {
            image = "jupyter/datascience-notebook:latest";
            ports = [ "8888:8888" ];
            volumes = [ "./notebooks:/home/jovyan/work" ];
            environment = {
              JUPYTER_ENABLE_LAB = "yes";
            };
          };
          
          postgres = {
            image = "postgres:15";
            environment = {
              POSTGRES_USER = "analyst";
              POSTGRES_PASSWORD = "analyst";
              POSTGRES_DB = "analytics";
            };
            volumes = [ "postgres_data:/var/lib/postgresql/data" ];
            ports = [ "5432:5432" ];
          };
          
          metabase = {
            image = "metabase/metabase:latest";
            ports = [ "3000:3000" ];
            environment = {
              MB_DB_TYPE = "postgres";
              MB_DB_DBNAME = "metabase";
              MB_DB_PORT = "5432";
              MB_DB_USER = "analyst";
              MB_DB_PASS = "analyst";
              MB_DB_HOST = "postgres";
            };
            depends_on = [ "postgres" ];
          };
        };
        
        volumes = {
          postgres_data = {};
        };
      };
    };
    
    # User configuration
    users.users = mkIf isNixOS {
      "${config.users.primaryUser.username or "jontk"}" = {
        extraGroups = [ "docker" ] ++ (if cfg.podman.enable then [ "podman" ] else []);
      };
    };
  };
}