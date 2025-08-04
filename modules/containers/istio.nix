# Istio Service Mesh Module
# Provides comprehensive service mesh capabilities with Istio

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers.kubernetes.istio;
  k8sCfg = config.modules.containers.kubernetes;
  
  # Istio installation values
  istioValues = ''
    pilot:
      env:
        EXTERNAL_ISTIOD: false
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY: true
      
    global:
      meshID: mesh1
      multiCluster:
        clusterName: k3s-cluster
      network: network1
      
      # Proxy settings
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        
        # Enable automatic sidecar injection
        autoInject: enabled
        
        # Tracing configuration
        tracer: jaeger
        
    # Istiod (control plane) configuration
    istiod:
      env:
        PILOT_ENABLE_VALIDATION: true
        PILOT_ENABLE_STATUS: true
        
    # Security
    security:
      enableNamespacesByDefault: true
      
    # Telemetry v2
    telemetry:
      v2:
        enabled: true
        prometheus:
          service:
            - providers:
                prometheus: {}
  '';
  
  # Gateway configuration for ingress
  istioGatewayManifest = ''
    apiVersion: networking.istio.io/v1alpha3
    kind: Gateway
    metadata:
      name: default-gateway
      namespace: istio-system
    spec:
      selector:
        istio: ingressgateway
      servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
        - "*.k3s.local"
        tls:
          httpsRedirect: true
      - port:
          number: 443
          name: https
          protocol: HTTPS
        tls:
          mode: SIMPLE
          credentialName: default-tls-secret
        hosts:
        - "*.k3s.local"
    ---
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: default-vs
      namespace: istio-system
    spec:
      hosts:
      - "*.k3s.local"
      gateways:
      - default-gateway
      http:
      - match:
        - headers:
            host:
              exact: grafana.k3s.local
        route:
        - destination:
            host: prometheus-grafana.monitoring.svc.cluster.local
            port:
              number: 80
      - match:
        - headers:
            host:
              exact: prometheus.k3s.local
        route:
        - destination:
            host: prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local
            port:
              number: 9090
      - match:
        - headers:
            host:
              exact: argocd.k3s.local
        route:
        - destination:
            host: argocd-server.argocd.svc.cluster.local
            port:
              number: 80
      - match:
        - headers:
            host:
              exact: jaeger.k3s.local
        route:
        - destination:
            host: jaeger-query.istio-system.svc.cluster.local
            port:
              number: 16686
      - match:
        - headers:
            host:
              exact: kiali.k3s.local
        route:
        - destination:
            host: kiali.istio-system.svc.cluster.local
            port:
              number: 20001
  '';
  
  # Default policies for security
  defaultPeerAuthentication = ''
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: default
      namespace: istio-system
    spec:
      mtls:
        mode: ${cfg.security.mtls.mode}
  '';
  
  # Authorization policies
  defaultAuthorizationPolicy = ''
    apiVersion: security.istio.io/v1beta1
    kind: AuthorizationPolicy
    metadata:
      name: deny-all
      namespace: istio-system
    spec:
      selector:
        matchLabels:
          app: httpbin
      action: DENY
      rules:
      - from:
        - source:
            notPrincipals: ["cluster.local/ns/default/sa/sleep"]
  '';

in

{
  options.modules.containers.kubernetes.istio = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Istio service mesh";
    };
    
    profile = mkOption {
      type = types.enum [ "minimal" "default" "demo" "ambient" ];
      default = "demo";
      description = "Istio installation profile";
    };
    
    version = mkOption {
      type = types.str;
      default = "1.20.0";
      description = "Istio version";
    };
    
    security = {
      mtls = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable automatic mutual TLS";
        };
        
        mode = mkOption {
          type = types.enum [ "STRICT" "PERMISSIVE" ];
          default = "PERMISSIVE";
          description = "mTLS mode";
        };
      };
      
      authz = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable authorization policies";
        };
        
        defaultDeny = mkOption {
          type = types.bool;
          default = false;
          description = "Default deny all traffic";
        };
      };
    };
    
    observability = {
      tracing = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable distributed tracing";
        };
        
        jaeger = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Install Jaeger for tracing";
          };
          
          sampling = mkOption {
            type = types.int;
            default = 1;
            description = "Tracing sampling rate (0-100)";
          };
        };
      };
      
      kiali = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Kiali service mesh dashboard";
        };
      };
      
      prometheus = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Prometheus metrics collection";
        };
      };
    };
    
    gateway = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Istio ingress gateway";
      };
      
      replicas = mkOption {
        type = types.int;
        default = 1;
        description = "Number of gateway replicas";
      };
      
      loadBalancer = mkOption {
        type = types.bool;
        default = false;
        description = "Use LoadBalancer service type";
      };
    };
    
    trafficManagement = {
      canary = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable canary deployment support";
        };
      };
      
      circuitBreaker = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable circuit breaker patterns";
        };
      };
      
      retries = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable automatic retries";
        };
        
        attempts = mkOption {
          type = types.int;
          default = 3;
          description = "Default retry attempts";
        };
      };
    };
    
    namespaces = mkOption {
      type = types.listOf types.str;
      default = [ "development" "staging" "production" ];
      description = "Namespaces to enable sidecar injection";
    };
  };

  config = mkIf (k8sCfg.enable && cfg.enable) {
    # Istio installation and configuration
    systemd.services.istio-setup = {
      description = "Install and configure Istio service mesh";
      after = [ "k3s.service" "k3s-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "istio-setup" ''
          set -euo pipefail
          
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          # Wait for cluster
          echo "Waiting for k3s cluster..."
          kubectl wait --for=condition=Ready nodes --all --timeout=120s
          
          # Download and install istioctl
          ISTIO_VERSION="${cfg.version}"
          if [[ ! -f /usr/local/bin/istioctl ]]; then
            echo "Installing istioctl $ISTIO_VERSION..."
            cd /tmp
            curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
            sudo mv istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/
            sudo chmod +x /usr/local/bin/istioctl
          fi
          
          # Install Istio
          echo "Installing Istio with ${cfg.profile} profile..."
          istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false \
            --set values.global.meshID=mesh1 \
            --set values.global.multiCluster.clusterName=k3s-cluster \
            --set values.global.network=network1 \
            -y
          
          # Wait for Istio to be ready
          kubectl wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=300s
          
          # Label namespaces for sidecar injection
          ${concatMapStrings (ns: ''
            kubectl create namespace ${ns} --dry-run=client -o yaml | kubectl apply -f -
            kubectl label namespace ${ns} istio-injection=enabled --overwrite
          '') cfg.namespaces}
          
          # Install Jaeger if enabled
          ${optionalString cfg.observability.tracing.jaeger.enable ''
            echo "Installing Jaeger..."
            kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/addons/jaeger.yaml
            kubectl wait --for=condition=Ready pod -l app=jaeger -n istio-system --timeout=300s
          ''}
          
          # Install Kiali if enabled
          ${optionalString cfg.observability.kiali.enable ''
            echo "Installing Kiali..."
            kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/addons/kiali.yaml
            kubectl wait --for=condition=Ready pod -l app=kiali -n istio-system --timeout=300s
          ''}
          
          # Install Prometheus addon if enabled
          ${optionalString cfg.observability.prometheus.enable ''
            echo "Installing Istio Prometheus..."
            kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/addons/prometheus.yaml
          ''}
          
          # Configure default gateway
          ${optionalString cfg.gateway.enable ''
            echo "Creating default gateway..."
            cat << 'EOF' | kubectl apply -f -
            ${istioGatewayManifest}
            EOF
          ''}
          
          # Apply security policies
          ${optionalString cfg.security.mtls.enable ''
            echo "Configuring mTLS..."
            cat << 'EOF' | kubectl apply -f -
            ${defaultPeerAuthentication}
            EOF
          ''}
          
          # Create sample applications for testing
          echo "Creating sample applications..."
          
          # Bookinfo sample
          kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/bookinfo/platform/kube/bookinfo.yaml -n development
          kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/bookinfo/networking/bookinfo-gateway.yaml -n development
          
          # HTTPBin for testing
          kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/httpbin/httpbin.yaml -n development
          
          # Sleep pod for testing
          kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${versions.major cfg.version}.${versions.minor cfg.version}/samples/sleep/sleep.yaml -n development
          
          echo ""
          echo "Istio installation completed!"
          echo ""
          echo "Access points:"
          echo "  Kiali: http://kiali.k3s.local (admin/admin)"
          echo "  Jaeger: http://jaeger.k3s.local"
          echo "  Bookinfo: http://bookinfo.k3s.local/productpage"
          echo ""
          echo "Verify installation:"
          echo "  istioctl version"
          echo "  istioctl proxy-status"
          echo "  kubectl get pods -n istio-system"
        '';
      };
    };
    
    # Install istioctl and related tools
    environment.systemPackages = with pkgs; [
      # Helper scripts
      (pkgs.writeShellScriptBin "istio-inject" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        NAMESPACE="''${1:-development}"
        
        echo "Enabling Istio sidecar injection for namespace: $NAMESPACE"
        kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
        
        echo "Restarting deployments to inject sidecars..."
        kubectl rollout restart deployment -n "$NAMESPACE"
        
        echo "Waiting for rollout to complete..."
        kubectl rollout status deployment -n "$NAMESPACE"
        
        echo "Sidecar injection enabled for namespace: $NAMESPACE"
      '')
      
      (pkgs.writeShellScriptBin "istio-status" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        echo "=== Istio Control Plane Status ==="
        kubectl get pods -n istio-system
        echo ""
        
        echo "=== Istio Proxy Status ==="
        istioctl proxy-status
        echo ""
        
        echo "=== Istio Configuration ==="
        istioctl analyze
        echo ""
        
        echo "=== mTLS Status ==="
        for ns in development staging production; do
          if kubectl get namespace "$ns" 2>/dev/null; then
            echo "Namespace: $ns"
            istioctl authn tls-check -n "$ns" || true
          fi
        done
      '')
      
      (pkgs.writeShellScriptBin "istio-traffic-split" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        SERVICE="''${1:-}"
        V1_WEIGHT="''${2:-90}"
        V2_WEIGHT="''${3:-10}"
        NAMESPACE="''${4:-development}"
        
        if [[ -z "$SERVICE" ]]; then
          echo "Usage: istio-traffic-split <service> [v1-weight] [v2-weight] [namespace]"
          echo "Example: istio-traffic-split productpage 90 10 development"
          exit 1
        fi
        
        cat << EOF | kubectl apply -f -
        apiVersion: networking.istio.io/v1alpha3
        kind: VirtualService
        metadata:
          name: $SERVICE
          namespace: $NAMESPACE
        spec:
          hosts:
          - $SERVICE
          http:
          - match:
            - headers:
                end-user:
                  exact: jason
            route:
            - destination:
                host: $SERVICE
                subset: v2
          - route:
            - destination:
                host: $SERVICE
                subset: v1
              weight: $V1_WEIGHT
            - destination:
                host: $SERVICE
                subset: v2
              weight: $V2_WEIGHT
        EOF
        
        echo "Traffic split configured: $SERVICE (v1: $V1_WEIGHT%, v2: $V2_WEIGHT%)"
      '')
      
      (pkgs.writeShellScriptBin "istio-circuit-breaker" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        SERVICE="''${1:-}"
        NAMESPACE="''${2:-development}"
        
        if [[ -z "$SERVICE" ]]; then
          echo "Usage: istio-circuit-breaker <service> [namespace]"
          exit 1
        fi
        
        cat << EOF | kubectl apply -f -
        apiVersion: networking.istio.io/v1alpha3
        kind: DestinationRule
        metadata:
          name: $SERVICE-circuit-breaker
          namespace: $NAMESPACE
        spec:
          host: $SERVICE
          trafficPolicy:
            outlierDetection:
              consecutiveErrors: 3
              interval: 30s
              baseEjectionTime: 30s
              maxEjectionPercent: 50
            connectionPool:
              tcp:
                maxConnections: 10
              http:
                http1MaxPendingRequests: 10
                maxRequestsPerConnection: 2
                maxRetries: 3
                consecutiveGatewayErrors: 3
                interval: 30s
                baseEjectionTime: 30s
        EOF
        
        echo "Circuit breaker configured for service: $SERVICE"
      '')
      
      (pkgs.writeShellScriptBin "istio-canary-deploy" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        APP="''${1:-}"
        VERSION="''${2:-}"
        TRAFFIC_PERCENT="''${3:-10}"
        NAMESPACE="''${4:-development}"
        
        if [[ -z "$APP" || -z "$VERSION" ]]; then
          echo "Usage: istio-canary-deploy <app> <version> [traffic-percent] [namespace]"
          echo "Example: istio-canary-deploy productpage v2 10 development"
          exit 1
        fi
        
        echo "Deploying canary version $VERSION for $APP..."
        
        # Create destination rule with subsets
        cat << EOF | kubectl apply -f -
        apiVersion: networking.istio.io/v1alpha3
        kind: DestinationRule
        metadata:
          name: $APP
          namespace: $NAMESPACE
        spec:
          host: $APP
          subsets:
          - name: v1
            labels:
              version: v1
          - name: $VERSION
            labels:
              version: $VERSION
        EOF
        
        # Create virtual service for traffic splitting
        cat << EOF | kubectl apply -f -
        apiVersion: networking.istio.io/v1alpha3
        kind: VirtualService
        metadata:
          name: $APP
          namespace: $NAMESPACE
        spec:
          hosts:
          - $APP
          http:
          - route:
            - destination:
                host: $APP
                subset: v1
              weight: $((100 - TRAFFIC_PERCENT))
            - destination:
                host: $APP
                subset: $VERSION
              weight: $TRAFFIC_PERCENT
        EOF
        
        echo "Canary deployment configured:"
        echo "  v1: $((100 - TRAFFIC_PERCENT))% traffic"
        echo "  $VERSION: $TRAFFIC_PERCENT% traffic"
        echo ""
        echo "Monitor with: kubectl logs -f deployment/$APP-$VERSION -n $NAMESPACE"
        echo "Promote with: istio-traffic-split $APP 0 100 $NAMESPACE"
      '')
    ];
    
    # Add Istio hosts
    networking.hosts = {
      "127.0.0.1" = [ 
        "kiali.k3s.local" 
        "jaeger.k3s.local" 
        "bookinfo.k3s.local"
      ];
    };
    
    # Shell aliases for Istio
    environment.shellAliases = {
      # Istio CLI shortcuts
      istio = "istioctl";
      istio-status = "istio-status";
      istio-inject = "istio-inject";
      
      # Traffic management
      canary = "istio-canary-deploy";
      traffic-split = "istio-traffic-split";
      circuit-breaker = "istio-circuit-breaker";
      
      # Observability
      kiali = "open http://kiali.k3s.local";
      jaeger = "open http://jaeger.k3s.local";
      
      # Testing
      istio-test = "kubectl exec -n development -c sleep \$(kubectl get pod -n development -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.development:8000/ip";
    };
  };
}