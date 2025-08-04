# Container Orchestration and Virtualization Module
# Provides Podman, Docker compatibility, and Kubernetes support

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers;
  isNixOS = pkgs.stdenv.isLinux;
in

{
  imports = [
    # ./k3s-monitoring.nix  # Temporarily disabled to fix build
    ./k3s-dev.nix
    ./argocd.nix
    ./istio.nix
  ];
  
  options.modules.containers = {
    enable = mkEnableOption "container orchestration and virtualization";
    
    podman = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Podman container runtime";
      };
      
      dockerCompat = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Docker CLI compatibility";
      };
      
      rootless = mkOption {
        type = types.bool;
        default = true;
        description = "Enable rootless container support";
      };
      
      compose = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Podman Compose support";
      };
      
      networking = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable advanced container networking";
        };
        
        cni = mkOption {
          type = types.bool;
          default = true;
          description = "Enable CNI networking";
        };
        
        bridge = mkOption {
          type = types.str;
          default = "cni-podman0";
          description = "Default bridge network name";
        };
      };
      
      storage = {
        driver = mkOption {
          type = types.enum [ "overlay" "vfs" "btrfs" "zfs" ];
          default = "overlay";
          description = "Storage driver for containers";
        };
        
        runRoot = mkOption {
          type = types.str;
          default = "/run/containers/storage";
          description = "Runtime storage root";
        };
        
        graphRoot = mkOption {
          type = types.str;
          default = "/var/lib/containers/storage";
          description = "Persistent storage root";
        };
      };
    };
    
    docker = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Docker daemon (alternative to Podman)";
      };
      
      rootless = mkOption {
        type = types.bool;
        default = false;
        description = "Enable rootless Docker daemon";
      };
      
      autoPrune = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic pruning of unused resources";
      };
    };
    
    kubernetes = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Kubernetes cluster";
      };
      
      distribution = mkOption {
        type = types.enum [ "k3s" "k0s" "microk8s" ];
        default = "k3s";
        description = "Kubernetes distribution to use";
      };
      
      role = mkOption {
        type = types.enum [ "server" "agent" "single" ];
        default = "single";
        description = "Kubernetes node role";
      };
      
      networking = {
        serviceCIDR = mkOption {
          type = types.str;
          default = "10.43.0.0/16";
          description = "Service network CIDR";
        };
        
        clusterCIDR = mkOption {
          type = types.str;
          default = "10.42.0.0/16";
          description = "Cluster network CIDR";
        };
        
        cni = mkOption {
          type = types.enum [ "flannel" "calico" "cilium" ];
          default = "flannel";
          description = "CNI plugin to use";
        };
      };
      
      features = {
        traefik = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Traefik ingress controller";
        };
        
        servicelb = mkOption {
          type = types.bool;
          default = true;
          description = "Enable ServiceLB load balancer";
        };
        
        localStorage = mkOption {
          type = types.bool;
          default = true;
          description = "Enable local storage provisioner";
        };
        
        metrics = mkOption {
          type = types.bool;
          default = false;
          description = "Enable metrics server";
        };
      };
    };
    
    registry = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable local container registry";
      };
      
      port = mkOption {
        type = types.int;
        default = 5000;
        description = "Registry port";
      };
      
      storage = mkOption {
        type = types.str;
        default = "/var/lib/registry";
        description = "Registry storage directory";
      };
    };
    
    tools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable container management tools";
      };
      
      buildah = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Buildah for building containers";
      };
      
      skopeo = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Skopeo for container image operations";
      };
      
      dive = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Dive for exploring container images";
      };
      
      helm = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Helm package manager for Kubernetes";
      };
      
      kubectl = mkOption {
        type = types.bool;
        default = true;
        description = "Enable kubectl Kubernetes client";
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable container monitoring";
      };
      
      cadvisor = mkOption {
        type = types.bool;
        default = true;
        description = "Enable cAdvisor for container metrics";
      };
      
      prometheus = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Prometheus monitoring integration";
      };
    };
  };

  config = mkIf (cfg.enable && isNixOS) {
    # Podman Configuration
    virtualisation.podman = mkIf cfg.podman.enable {
      enable = true;
      
      # Docker compatibility - only enable if Docker is disabled
      dockerCompat = cfg.podman.dockerCompat && !cfg.docker.enable;
      dockerSocket.enable = cfg.podman.dockerCompat && !cfg.docker.enable;
      
      # Default network settings
      defaultNetwork.settings.dns_enabled = true;
      
      # Rootless support
      extraPackages = mkIf cfg.podman.rootless (with pkgs; [
        runc
        conmon
        slirp4netns
        fuse-overlayfs
      ]);
    };
    
    # Skip storage.conf as it conflicts with system-wide containers module
    
    # Skip registries.conf as it conflicts with system-wide containers module
    
    # Skip policy.json as it conflicts with system-wide containers module
    
    # Docker configuration (alternative to Podman)
    virtualisation.docker = mkIf cfg.docker.enable {
      enable = true;
      rootless = mkIf cfg.docker.rootless {
        enable = true;
        setSocketVariable = true;
      };
      autoPrune = mkIf cfg.docker.autoPrune {
        enable = true;
        dates = "weekly";
      };
    };
    
    # K3s Kubernetes configuration
    services.k3s = mkIf (cfg.kubernetes.enable && cfg.kubernetes.distribution == "k3s") {
      enable = true;
      role = if cfg.kubernetes.role == "single" then "server" else cfg.kubernetes.role;
      
      extraFlags = concatStringsSep " " ([
        "--cluster-cidr=${cfg.kubernetes.networking.clusterCIDR}"
        "--service-cidr=${cfg.kubernetes.networking.serviceCIDR}"
        "--flannel-backend=vxlan"
        "--write-kubeconfig-mode=644"
      ] ++ optional (!cfg.kubernetes.features.traefik) "--disable=traefik"
        ++ optional (!cfg.kubernetes.features.servicelb) "--disable=servicelb"
        ++ optional (!cfg.kubernetes.features.localStorage) "--disable=local-storage"
        ++ optional (!cfg.kubernetes.features.metrics) "--disable=metrics-server"
        ++ optional (cfg.kubernetes.networking.cni != "flannel") "--flannel-backend=none --disable-network-policy");
    };
    
    # K3s additional configuration
    environment.etc."rancher/k3s/registries.yaml" = mkIf (cfg.kubernetes.enable && cfg.registry.enable) {
      text = ''
        mirrors:
          "localhost:${toString cfg.registry.port}":
            endpoint:
              - "http://localhost:${toString cfg.registry.port}"
      '';
    };
    
    # Kubernetes namespace and resource management
    systemd.services.k3s-setup = mkIf cfg.kubernetes.enable {
      description = "K3s cluster setup and configuration";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "k3s-setup" ''
          set -euo pipefail
          
          # Wait for k3s to be ready
          timeout=60
          while [ $timeout -gt 0 ]; do
            if ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1; then
              break
            fi
            sleep 2
            ((timeout--))
          done
          
          if [ $timeout -eq 0 ]; then
            echo "Timeout waiting for k3s to be ready"
            exit 1
          fi
          
          echo "K3s cluster is ready"
          
          # Create development namespace
          ${pkgs.kubectl}/bin/kubectl create namespace development || true
          
          # Create monitoring namespace if monitoring is enabled
          ${optionalString cfg.monitoring.enable ''
            ${pkgs.kubectl}/bin/kubectl create namespace monitoring || true
          ''}
          
          # Apply any additional configurations
          echo "K3s setup completed"
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Container Registry
    services.dockerRegistry = mkIf cfg.registry.enable {
      enable = true;
      port = cfg.registry.port;
      listenAddress = "0.0.0.0";
      storagePath = cfg.registry.storage;
      extraConfig = {
        storage = {
          delete = {
            enabled = true;
          };
        };
        http = {
          addr = ":${toString cfg.registry.port}";
          headers = {
            "X-Content-Type-Options" = ["nosniff"];
          };
        };
      };
    };
    
    # Container monitoring with cAdvisor
    services.cadvisor = mkIf (cfg.monitoring.enable && cfg.monitoring.cadvisor) {
      enable = true;
      port = 8080;
      extraOptions = [
        "--docker_only=false"
        "--housekeeping_interval=30s"
        "--max_housekeeping_interval=35s"
      ];
    };
    
    # Merged networking configuration
    networking.firewall = mkIf cfg.enable {
      # Allowed TCP ports from both definitions
      allowedTCPPorts = 
        optional cfg.registry.enable cfg.registry.port
        ++ optional (cfg.monitoring.enable && cfg.monitoring.cadvisor) 8080
        ++ optional (cfg.kubernetes.enable && cfg.kubernetes.role != "agent") 6443;
      
      # Trusted interfaces from second definition
      trustedInterfaces = mkMerge [
        (mkIf cfg.podman.enable [ "cni-podman0" "podman0" ])
        (mkIf cfg.docker.enable [ "docker0" ])
      ];
    };
    
    # Merged container tools and packages
    environment.systemPackages = with pkgs; mkMerge [
      # Base container tools
      (mkIf cfg.podman.enable [
        podman
        conmon
        runc
        slirp4netns
        fuse-overlayfs
        # containers-common  # Package not available
      ])
      
      # Podman Compose
      (mkIf (cfg.podman.enable && cfg.podman.compose) [
        podman-compose
      ])
      
      # Docker tools
      (mkIf cfg.docker.enable [
        docker
        docker-compose
      ])
      
      # Container build and management tools
      (mkIf (cfg.tools.enable && cfg.tools.buildah) [ buildah ])
      (mkIf (cfg.tools.enable && cfg.tools.skopeo) [ skopeo ])
      (mkIf (cfg.tools.enable && cfg.tools.dive) [ dive ])
      
      # Kubernetes tools
      (mkIf (cfg.kubernetes.enable || cfg.tools.kubectl) [ kubectl ])
      (mkIf (cfg.tools.enable && cfg.tools.helm) [ kubernetes-helm ])
      
      # Additional container tools
      (mkIf cfg.tools.enable [
        ctop          # Container monitoring
        lazydocker    # Docker TUI
        cosign        # Container signing
      ])
      
      # Development environment container helper script
      (mkIf cfg.enable [
        (pkgs.writeShellScriptBin "container-dev-env" ''
          #!/usr/bin/env bash
          # Container Development Environment Helper
          
          set -euo pipefail
          
          show_usage() {
            cat << EOF
          Usage: container-dev-env [COMMAND] [OPTIONS]
          
          Container development environment management
          
          COMMANDS:
            create <name> <image>    Create development container
            start <name>             Start development container
            stop <name>              Stop development container
            exec <name> [cmd]        Execute command in container
            list                     List development containers
            remove <name>            Remove development container
            
          EXAMPLES:
            container-dev-env create node-dev node:18-alpine
            container-dev-env start node-dev
            container-dev-env exec node-dev bash
          EOF
          }
          
          container_cmd="${if cfg.podman.enable then "${pkgs.podman}/bin/podman" else "${pkgs.docker}/bin/docker"}"
          
          case "''${1:-help}" in
            create)
              name="''${2:-}"
              image="''${3:-}"
              if [[ -z "$name" || -z "$image" ]]; then
                echo "Error: Name and image required"
                show_usage
                exit 1
              fi
              
              echo "Creating development container: $name"
              $container_cmd create \
                --name "$name" \
                --interactive \
                --tty \
                --volume "$(pwd):/workspace:Z" \
                --workdir "/workspace" \
                --network bridge \
                "$image" \
                /bin/sh
              ;;
            start)
              name="''${2:-}"
              if [[ -z "$name" ]]; then
                echo "Error: Container name required"
                exit 1
              fi
              $container_cmd start "$name"
              ;;
            stop)
              name="''${2:-}"
              if [[ -z "$name" ]]; then
                echo "Error: Container name required"
                exit 1
              fi
              $container_cmd stop "$name"
              ;;
            exec)
              name="''${2:-}"
              cmd="''${3:-bash}"
              if [[ -z "$name" ]]; then
                echo "Error: Container name required"
                exit 1
              fi
              $container_cmd exec -it "$name" "$cmd"
              ;;
            list)
              echo "Development containers:"
              $container_cmd ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
              ;;
            remove)
              name="''${2:-}"
              if [[ -z "$name" ]]; then
                echo "Error: Container name required"
                exit 1
              fi
              $container_cmd rm -f "$name"
              ;;
            *)
              show_usage
              ;;
          esac
        '')
      ])
    ];
    
    # User groups for container access
    users.groups.podman = mkIf cfg.podman.enable {};
    users.groups.docker = mkIf cfg.docker.enable {};
    
    # Rootless container configuration
    security.unprivilegedUsernsClone = mkIf (cfg.podman.enable && cfg.podman.rootless) true;
    
    # Configure subuid and subgid for rootless containers
    users.users.root = mkIf cfg.enable {
      extraGroups = 
        optional cfg.podman.enable "podman" 
        ++ optional cfg.docker.enable "docker";
    };
    
    # Skip containers.conf as it conflicts with system-wide containers module
    
    
    # Systemd services for container management
    systemd.services.container-cleanup = {
      description = "Cleanup unused container resources";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "container-cleanup" ''
          set -euo pipefail
          
          ${optionalString cfg.podman.enable ''
            echo "Cleaning up Podman resources..."
            ${pkgs.podman}/bin/podman system prune -af --volumes || true
            ${pkgs.podman}/bin/podman image prune -af || true
          ''}
          
          ${optionalString cfg.docker.enable ''
            echo "Cleaning up Docker resources..."
            ${pkgs.docker}/bin/docker system prune -af --volumes || true
          ''}
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Cleanup timer
    systemd.timers.container-cleanup = {
      description = "Container cleanup timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    # Container health check service
    systemd.services.container-health-check = mkIf cfg.monitoring.enable {
      description = "Container health monitoring";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "container-health-check" ''
          set -euo pipefail
          
          echo "=== Container Health Check Report ===" 
          echo "Timestamp: $(date)"
          echo ""
          
          ${optionalString cfg.podman.enable ''
            echo "=== Podman Status ==="
            ${pkgs.podman}/bin/podman info --format "{{.Host.RemoteSocket.Exists}}" || echo "Podman not running"
            ${pkgs.podman}/bin/podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || true
            echo ""
            
            echo "=== Podman System Info ==="
            ${pkgs.podman}/bin/podman system df || true
            echo ""
          ''}
          
          ${optionalString cfg.docker.enable ''
            echo "=== Docker Status ==="
            ${pkgs.docker}/bin/docker info --format "{{.ServerVersion}}" || echo "Docker not running"
            ${pkgs.docker}/bin/docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || true
            echo ""
          ''}
          
          ${optionalString cfg.kubernetes.enable ''
            echo "=== Kubernetes Status ==="
            ${pkgs.kubectl}/bin/kubectl get nodes || echo "Kubernetes not available"
            ${pkgs.kubectl}/bin/kubectl get pods --all-namespaces || true
            echo ""
          ''}
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    # Health check timer
    systemd.timers.container-health-check = mkIf cfg.monitoring.enable {
      description = "Container health check timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
    
    # Enable container networking
    networking.nat = mkIf (cfg.podman.enable && cfg.podman.networking.enable) {
      enable = true;
      internalInterfaces = [ "cni-podman0" ];
    };
  };
}