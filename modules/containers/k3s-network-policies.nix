# K3s Network Policies Module
# Provides network policy configurations for system namespaces

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers.kubernetes.networkPolicies;
  k8sCfg = config.modules.containers.kubernetes;
  
  # Network policy manifest for system namespaces
  systemNetworkPoliciesManifest = ''
    # Cert-manager namespace - needs egress for ACME challenges
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: cert-manager-allow-egress
      namespace: cert-manager
    spec:
      podSelector: {}
      policyTypes:
      - Egress
      - Ingress
      egress:
      - {}  # Allow all egress for Let's Encrypt and other CA communications
      ingress:
      - from:
        - namespaceSelector: {}  # Allow ingress from all namespaces for webhook
    ---
    # Harbor namespace - needs egress for pulling images
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: harbor-allow-traffic
      namespace: harbor
    spec:
      podSelector: {}
      policyTypes:
      - Egress
      - Ingress
      egress:
      - {}  # Allow all egress for pulling upstream images
      ingress:
      - {}  # Allow all ingress for registry access
    ---
    # ArgoCD namespace - needs egress for Git repositories
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: argocd-allow-egress
      namespace: argocd
    spec:
      podSelector: {}
      policyTypes:
      - Egress
      egress:
      - {}  # Allow all egress for Git repository access
    ---
    # Monitoring namespaces - Prometheus, Grafana, etc.
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: monitoring-allow-traffic
      namespace: monitoring
    spec:
      podSelector: {}
      policyTypes:
      - Egress
      - Ingress
      egress:
      - {}  # Allow egress for scraping metrics
      ingress:
      - {}  # Allow ingress for UI access
  '';

in

{
  options.modules.containers.kubernetes.networkPolicies = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable network policies for system namespaces";
    };
    
    systemNamespaces = mkOption {
      type = types.listOf types.str;
      default = [ "cert-manager" "harbor" "argocd" "monitoring" ];
      description = "System namespaces that need network policies";
    };
    
    allowEgress = mkOption {
      type = types.listOf types.str;
      default = [ "cert-manager" "harbor" "argocd" ];
      description = "Namespaces that need unrestricted egress";
    };
  };

  config = mkIf (k8sCfg.enable && cfg.enable) {
    # Deploy network policies for system namespaces
    systemd.services.k3s-network-policies = {
      description = "Configure k3s network policies for system namespaces";
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "k3s-network-policies-apply" ''
          set -euo pipefail

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

          # Skip if network policies already applied
          if ${pkgs.kubectl}/bin/kubectl get networkpolicies -n kube-system 2>/dev/null | grep -q .; then
            echo "Network policies already applied, skipping"
            exit 0
          fi

          # Wait for cluster to be ready
          echo "Waiting for k3s cluster to be ready..."
          for i in {1..60}; do
            if ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done
          
          # Ensure namespaces exist before applying policies
          echo "Creating system namespaces if they don't exist..."
          ${concatMapStrings (ns: ''
            ${pkgs.kubectl}/bin/kubectl create namespace ${ns} --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f - || true
          '') cfg.systemNamespaces}
          
          # Apply network policies
          echo "Applying network policies for system namespaces..."
          ${pkgs.kubectl}/bin/kubectl apply -f - <<EOF
          ${systemNetworkPoliciesManifest}
          EOF
          
          echo "Network policies configured successfully"
        '';
        
        # Clean up on stop
        ExecStop = pkgs.writeShellScript "k3s-network-policies-remove" ''
          set -euo pipefail
          
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          echo "Removing network policies..."
          ${concatMapStrings (ns: ''
            ${pkgs.kubectl}/bin/kubectl delete networkpolicy --all -n ${ns} --ignore-not-found=true || true
          '') cfg.systemNamespaces}
        '';
      };
    };
    
    # Helper script to check network policy status
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "k3s-netpol-status" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        echo "Network Policy Status for System Namespaces:"
        echo "==========================================="
        
        for ns in ${concatStringsSep " " cfg.systemNamespaces}; do
          echo ""
          echo "Namespace: $ns"
          ${pkgs.kubectl}/bin/kubectl get networkpolicies -n "$ns" 2>/dev/null || echo "  No network policies found"
        done
      '')
      
      (pkgs.writeShellScriptBin "k3s-netpol-test" ''
        #!/usr/bin/env bash
        # Test egress connectivity from a namespace
        set -euo pipefail
        
        NAMESPACE="''${1:-cert-manager}"
        TARGET="''${2:-https://www.google.com}"
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        echo "Testing egress from namespace: $NAMESPACE to $TARGET"
        
        # Create test pod
        ${pkgs.kubectl}/bin/kubectl run test-egress-$RANDOM \
          --namespace="$NAMESPACE" \
          --image=curlimages/curl:latest \
          --rm -it --restart=Never \
          -- curl -I "$TARGET"
      '')
    ];
  };
}