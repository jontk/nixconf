# K3s Development Environment Module
# Provides development-focused features including local registry, dev tools, and sample applications

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers.kubernetes.development;
  k8sCfg = config.modules.containers.kubernetes;
  
  # Registry mirror configuration
  registryConfig = ''
    mirrors:
      docker.io:
        endpoint:
          - "http://localhost:5000"
      localhost:5000:
        endpoint:
          - "http://localhost:5000"
  '';
  
  # Development namespace setup
  devNamespaceManifest = ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: dev
      labels:
        name: dev
        purpose: development
    ---
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: dev-quota
      namespace: dev
    spec:
      hard:
        requests.cpu: "10"
        requests.memory: 20Gi
        persistentvolumeclaims: "10"
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-all
      namespace: dev
    spec:
      podSelector: {}
      policyTypes:
      - Ingress
      - Egress
      ingress:
      - {}
      egress:
      - {}
  '';

in

{
  options.modules.containers.kubernetes.development = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable k3s development features";
    };
    
    registry = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable local Docker registry";
      };
      
      port = mkOption {
        type = types.int;
        default = 5000;
        description = "Registry port";
      };
      
      ui = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable registry UI";
        };
        
        port = mkOption {
          type = types.int;
          default = 5001;
          description = "Registry UI port";
        };
      };
    };
    
    tools = {
      telepresence = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Telepresence for local development";
      };
      
      skaffold = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Skaffold for continuous development";
      };
      
      tilt = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Tilt for local k8s development";
      };
      
      devspace = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DevSpace for k8s development";
      };
    };
    
    samples = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy sample applications";
      };
      
      apps = mkOption {
        type = types.listOf types.str;
        default = [ "hello-world" "postgres" ];
        description = "Sample applications to deploy";
      };
    };
  };

  config = mkIf (k8sCfg.enable && cfg.enable) {
    # Development tools packages
    environment.systemPackages = with pkgs; [
      # Container tools
      skopeo
      buildah
      
      # Development tools
      (mkIf cfg.tools.telepresence telepresence2)
      (mkIf cfg.tools.skaffold skaffold)
      (mkIf cfg.tools.tilt tilt)
      (mkIf cfg.tools.devspace devspace)
      
      # Additional k8s dev tools
      kubectl-tree
      kubectl-neat
      kubectl-images
      kube-capacity
      kubespy
      kubeval
      kube-score

      # Debugging tools
      # kubectl-debug  # Package might not be available
      # kubectl-trace  # Package might not be available
      # kubectl-flame  # Package might not be available
      
      # Helper scripts
      (pkgs.writeShellScriptBin "k3s-dev-setup" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        echo "Setting up k3s development environment..."
        
        # Create development namespace
        ${pkgs.kubectl}/bin/kubectl apply -f - <<EOF
        ${devNamespaceManifest}
        EOF
        
        # Set default namespace to dev
        ${pkgs.kubectl}/bin/kubectl config set-context --current --namespace=dev
        
        echo "Development environment ready!"
        echo ""
        echo "Default namespace set to: dev"
        echo "Local registry available at: localhost:5000"
        ${optionalString cfg.registry.ui.enable ''
          echo "Registry UI available at: http://localhost:${toString cfg.registry.ui.port}"
        ''}
      '')
      
      (pkgs.writeShellScriptBin "k3s-push" ''
        #!/usr/bin/env bash
        # Push image to local k3s registry
        set -euo pipefail
        
        IMAGE="''${1:-}"
        if [[ -z "$IMAGE" ]]; then
          echo "Usage: k3s-push <image-name>"
          exit 1
        fi
        
        # Tag and push to local registry
        docker tag "$IMAGE" "localhost:5000/$IMAGE"
        docker push "localhost:5000/$IMAGE"
        
        echo "Image pushed to local registry: localhost:5000/$IMAGE"
        echo "Use in k8s with: localhost:5000/$IMAGE"
      '')
      
      (pkgs.writeShellScriptBin "k3s-build-push" ''
        #!/usr/bin/env bash
        # Build and push image to local k3s registry
        set -euo pipefail
        
        NAME="''${1:-app}"
        TAG="''${2:-latest}"
        DOCKERFILE="''${3:-Dockerfile}"
        
        IMAGE="$NAME:$TAG"
        REGISTRY_IMAGE="localhost:5000/$IMAGE"
        
        echo "Building image: $IMAGE"
        docker build -t "$IMAGE" -t "$REGISTRY_IMAGE" -f "$DOCKERFILE" .
        
        echo "Pushing to local registry..."
        docker push "$REGISTRY_IMAGE"
        
        echo "Image available as: $REGISTRY_IMAGE"
      '')
      
      (pkgs.writeShellScriptBin "k3s-dev-app" ''
        #!/usr/bin/env bash
        # Deploy a development application
        set -euo pipefail
        
        APP_NAME="''${1:-myapp}"
        IMAGE="''${2:-harbor.dev.ar.jontk.com/dockerhub-proxy/nginx:latest}"
        PORT="''${3:-80}"
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        cat <<EOF | ${pkgs.kubectl}/bin/kubectl apply -f -
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: $APP_NAME
          namespace: dev
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: $APP_NAME
          template:
            metadata:
              labels:
                app: $APP_NAME
            spec:
              containers:
              - name: $APP_NAME
                image: $IMAGE
                ports:
                - containerPort: $PORT
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: $APP_NAME
          namespace: dev
        spec:
          selector:
            app: $APP_NAME
          ports:
          - port: $PORT
            targetPort: $PORT
          type: LoadBalancer
        EOF
        
        echo "Application deployed: $APP_NAME"
        echo "Getting service info..."
        ${pkgs.kubectl}/bin/kubectl get svc $APP_NAME -n dev
      '')
      
      (pkgs.writeShellScriptBin "k3s-dev-forward" ''
        #!/usr/bin/env bash
        # Port forward a service for development
        set -euo pipefail
        
        SERVICE="''${1:-}"
        LOCAL_PORT="''${2:-8080}"
        REMOTE_PORT="''${3:-80}"
        
        if [[ -z "$SERVICE" ]]; then
          echo "Usage: k3s-dev-forward <service> [local-port] [remote-port]"
          echo ""
          echo "Available services in dev namespace:"
          ${pkgs.kubectl}/bin/kubectl get svc -n dev
          exit 1
        fi
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        echo "Forwarding $SERVICE:$REMOTE_PORT to localhost:$LOCAL_PORT"
        ${pkgs.kubectl}/bin/kubectl port-forward -n dev "svc/$SERVICE" "$LOCAL_PORT:$REMOTE_PORT"
      '')
    ];
    
    # Local Docker registry deployment
    systemd.services.k3s-registry = mkIf cfg.registry.enable {
      description = "Local Docker registry for k3s";
      after = [ "docker.service" "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStartPre = "${pkgs.docker}/bin/docker pull harbor.dev.ar.jontk.com/dockerhub-proxy/registry:2";
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm \
            --name k3s-registry \
            -p ${toString cfg.registry.port}:5000 \
            -v /var/lib/k3s-registry:/var/lib/registry \
            harbor.dev.ar.jontk.com/dockerhub-proxy/registry:2
        '';
        ExecStop = "${pkgs.docker}/bin/docker stop k3s-registry";
      };
    };
    
    # Registry UI
    systemd.services.k3s-registry-ui = mkIf (cfg.registry.enable && cfg.registry.ui.enable) {
      description = "Docker registry UI for k3s";
      after = [ "docker.service" "k3s-registry.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStartPre = "${pkgs.docker}/bin/docker pull harbor.dev.ar.jontk.com/dockerhub-proxy/joxit/docker-registry-ui:latest";
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm \
            --name k3s-registry-ui \
            -p ${toString cfg.registry.ui.port}:80 \
            -e REGISTRY_URL=http://localhost:${toString cfg.registry.port} \
            -e DELETE_IMAGES=true \
            -e REGISTRY_TITLE="K3s Local Registry" \
            harbor.dev.ar.jontk.com/dockerhub-proxy/joxit/docker-registry-ui:latest
        '';
        ExecStop = "${pkgs.docker}/bin/docker stop k3s-registry-ui";
      };
    };
    
    # Deploy sample applications
    systemd.services.k3s-samples = mkIf cfg.samples.enable {
      description = "Deploy k3s sample applications";
      after = [ "k3s.service" "k3s-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "k3s-samples-deploy" ''
          set -euo pipefail
          
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          # Wait for cluster
          ${pkgs.kubectl}/bin/kubectl wait --for=condition=Ready nodes --all --timeout=60s
          
          # Deploy samples
          ${optionalString (elem "hello-world" cfg.samples.apps) ''
            echo "Deploying hello-world..."
            ${pkgs.kubectl}/bin/kubectl create deployment hello-world \
              --image=gcr.io/google-samples/hello-app:1.0 \
              --namespace=dev \
              --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
            ${pkgs.kubectl}/bin/kubectl expose deployment hello-world \
              --port=8080 \
              --namespace=dev \
              --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
          ''}
          
          ${optionalString (elem "redis" cfg.samples.apps) ''
            echo "Deploying Redis..."
            ${pkgs.kubectl}/bin/kubectl apply -n dev -f - <<EOF
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: redis
            spec:
              replicas: 1
              selector:
                matchLabels:
                  app: redis
              template:
                metadata:
                  labels:
                    app: redis
                spec:
                  containers:
                  - name: redis
                    image: harbor.dev.ar.jontk.com/dockerhub-proxy/redis:7-alpine
                    ports:
                    - containerPort: 6379
            ---
            apiVersion: v1
            kind: Service
            metadata:
              name: redis
            spec:
              selector:
                app: redis
              ports:
              - port: 6379
                targetPort: 6379
            EOF
          ''}
          
          ${optionalString (elem "postgres" cfg.samples.apps) ''
            echo "Deploying PostgreSQL..."
            ${pkgs.kubectl}/bin/kubectl apply -n dev -f - <<EOF
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: postgres
            spec:
              replicas: 1
              selector:
                matchLabels:
                  app: postgres
              template:
                metadata:
                  labels:
                    app: postgres
                spec:
                  containers:
                  - name: postgres
                    image: harbor.dev.ar.jontk.com/dockerhub-proxy/postgres:15-alpine
                    env:
                    - name: POSTGRES_PASSWORD
                      value: postgres
                    - name: POSTGRES_USER
                      value: postgres
                    - name: POSTGRES_DB
                      value: development
                    ports:
                    - containerPort: 5432
            ---
            apiVersion: v1
            kind: Service
            metadata:
              name: postgres
            spec:
              selector:
                app: postgres
              ports:
              - port: 5432
                targetPort: 5432
            EOF
          ''}
          
          echo "Sample applications deployed to 'dev' namespace"
          ${pkgs.kubectl}/bin/kubectl get all -n dev
        '';
      };
    };
    
    # Configure k3s to use local registry
    environment.etc."rancher/k3s/registries.yaml" = mkIf cfg.registry.enable {
      text = registryConfig;
    };
    
    # Shell aliases for k8s development
    environment.shellAliases = {
      # Kubernetes shortcuts
      k = "kubectl";
      kdev = "kubectl -n dev";
      kpods = "kubectl get pods -n dev";
      klogs = "kubectl logs -n dev";
      kdesc = "kubectl describe -n dev";
      
      # Development shortcuts
      k3s-push = "k3s-push";
      k3s-build = "k3s-build-push";
      k3s-app = "k3s-dev-app";
      k3s-forward = "k3s-dev-forward";
      
      # Registry shortcuts
      reg-list = "curl -s http://localhost:5000/v2/_catalog | jq";
      reg-tags = "curl -s http://localhost:5000/v2/$1/tags/list | jq";
      
      # k9s with dev namespace
      k9s-dev = "k9s -n dev";
    };
    
    # Firewall rules for development
    networking.firewall.allowedTCPPorts = mkIf cfg.registry.enable [
      cfg.registry.port
      cfg.registry.ui.port
    ];
  };
}