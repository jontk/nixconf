# ArgoCD GitOps Module
# Provides ArgoCD installation and configuration for GitOps workflows

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers.kubernetes.argocd;
  k8sCfg = config.modules.containers.kubernetes;
  
  # ArgoCD values for Helm installation
  argoCDValues = ''
    server:
      service:
        type: LoadBalancer
      
      ingress:
        enabled: true
        ingressClassName: traefik
        hosts:
          - argocd.k3s.local
        paths:
          - /
        tls:
          - hosts:
            - argocd.k3s.local
      
      config:
        url: https://argocd.k3s.local
        
        # RBAC configuration
        policy.default: role:readonly
        policy.csv: |
          p, role:admin, applications, *, */*, allow
          p, role:admin, clusters, *, *, allow
          p, role:admin, repositories, *, *, allow
          p, role:admin, gpgkeys, *, *, allow
          g, argocd-admins, role:admin
        
        # Repository credentials
        repositories: |
          - url: https://github.com/jontk/nixconf
            name: nixconf
            type: git
        
        # Resource customizations
        resource.customizations: |
          argoproj.io/Application:
            health.lua: |
              hs = {}
              hs.status = "Healthy"
              hs.message = ""
              if obj.status ~= nil then
                if obj.status.health ~= nil then
                  hs.status = obj.status.health.status
                  hs.message = obj.status.health.message
                end
              end
              return hs
      
      # Metrics
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          namespace: monitoring
      
      # Resource tracking
      application:
        instanceLabelKey: argocd.argoproj.io/instance
      
    redis:
      enabled: true
      
    dex:
      enabled: false  # Disable for now, can enable OAuth later
      
    notifications:
      enabled: true
      argocdUrl: https://argocd.k3s.local
      
      # Notification templates
      templates:
        app-deployed: |
          message: |
            {{if eq .serviceType "slack"}}:white_check_mark:{{end}} Application {{.app.metadata.name}} is now running new version.
        app-health-degraded: |
          message: |
            {{if eq .serviceType "slack"}}:exclamation:{{end}} Application {{.app.metadata.name}} has degraded.
        app-sync-failed: |
          message: |
            {{if eq .serviceType "slack"}}:exclamation:{{end}} Application {{.app.metadata.name}} sync is failed.
      
      # Triggers
      triggers:
        on-deployed:
          - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
            send: [app-deployed]
        on-health-degraded:
          - when: app.status.health.status == 'Degraded'
            send: [app-health-degraded]
        on-sync-failed:
          - when: app.status.operationState.phase in ['Error', 'Failed']
            send: [app-sync-failed]
    
    # Controller settings
    controller:
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          namespace: monitoring
  '';
  
  # App of Apps pattern configuration
  appOfAppsManifest = ''
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/jontk/nixconf
        targetRevision: HEAD
        path: k8s/apps
      destination:
        server: https://kubernetes.default.svc
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: "5"
          backoff:
            duration: 5s
            factor: "2"
            maxDuration: 3m
  '';
  
  # Sample application manifests
  sampleAppManifest = name: ''
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${name}
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/jontk/nixconf
        targetRevision: HEAD
        path: k8s/apps/${name}
      destination:
        server: https://kubernetes.default.svc
        namespace: ${name}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  '';

in

{
  options.modules.containers.kubernetes.argocd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable ArgoCD for GitOps";
    };
    
    adminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = "ArgoCD admin password (change in production!)";
    };
    
    repos = mkOption {
      type = types.listOf (types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            description = "Repository URL";
          };
          
          name = mkOption {
            type = types.str;
            description = "Repository name";
          };
          
          type = mkOption {
            type = types.enum [ "git" "helm" ];
            default = "git";
            description = "Repository type";
          };
          
          credentialsSecret = mkOption {
            type = types.str;
            default = "";
            description = "Secret name for credentials";
          };
        };
      });
      default = [
        {
          url = "https://github.com/jontk/nixconf";
          name = "nixconf";
          type = "git";
        }
      ];
      description = "Git repositories to configure";
    };
    
    applications = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "frontend" "backend" "database" ];
      description = "Applications to auto-create";
    };
    
    notifications = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable notifications";
      };
      
      slack = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Slack notifications";
        };
        
        webhook = mkOption {
          type = types.str;
          default = "";
          description = "Slack webhook URL";
        };
        
        channel = mkOption {
          type = types.str;
          default = "#deployments";
          description = "Slack channel";
        };
      };
    };
    
    metrics = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable metrics export";
      };
    };
    
    sealedSecrets = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Sealed Secrets controller";
      };
      
      namespace = mkOption {
        type = types.str;
        default = "kube-system";
        description = "Namespace for sealed-secrets controller";
      };
    };
  };

  config = mkIf (k8sCfg.enable && cfg.enable) {
    # ArgoCD deployment script
    systemd.services.argocd-setup = {
      description = "Deploy ArgoCD GitOps";
      after = [ "k3s.service" "k3s-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "argocd-setup" ''
          set -euo pipefail
          
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          # Wait for cluster
          echo "Waiting for k3s cluster..."
          kubectl wait --for=condition=Ready nodes --all --timeout=120s
          
          # Create ArgoCD namespace
          kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
          
          # Add ArgoCD Helm repository
          helm repo add argo https://argoproj.github.io/argo-helm
          helm repo update
          
          # Generate bcrypt password hash for admin
          ADMIN_PASSWORD_HASH=$(${pkgs.python3}/bin/python3 -c "import bcrypt; print(bcrypt.hashpw('${cfg.adminPassword}'.encode('utf-8'), bcrypt.gensalt()).decode('utf-8'))")
          
          # Install ArgoCD
          echo "Installing ArgoCD..."
          cat > /tmp/argocd-values.yaml << 'EOF'
          ${argoCDValues}
          configs:
            secret:
              argocdServerAdminPassword: "$ADMIN_PASSWORD_HASH"
          EOF
          
          # Substitute the password hash
          sed -i "s|\$ADMIN_PASSWORD_HASH|$ADMIN_PASSWORD_HASH|g" /tmp/argocd-values.yaml
          
          helm upgrade --install argocd argo/argo-cd \
            --namespace argocd \
            --values /tmp/argocd-values.yaml \
            --wait \
            --timeout 10m
          
          # Install Sealed Secrets if enabled
          ${optionalString cfg.sealedSecrets.enable ''
            echo "Installing Sealed Secrets..."
            helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
            helm repo update
            
            helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
              --namespace ${cfg.sealedSecrets.namespace} \
              --set-string fullnameOverride=sealed-secrets-controller \
              --wait
            
            # Wait for sealed secrets controller
            kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=sealed-secrets -n ${cfg.sealedSecrets.namespace} --timeout=120s
          ''}
          
          # Create App of Apps if configured
          ${optionalString (cfg.applications != []) ''
            echo "Creating App of Apps..."
            cat > /tmp/app-of-apps.yaml << 'EOF'
            ${appOfAppsManifest}
            EOF
            kubectl apply -f /tmp/app-of-apps.yaml
          ''}
          
          # Create individual application manifests
          ${concatMapStrings (app: ''
            echo "Creating application: ${app}"
            cat > /tmp/app-${app}.yaml << 'EOF'
            ${sampleAppManifest app}
            EOF
            kubectl apply -f /tmp/app-${app}.yaml
          '') cfg.applications}
          
          # Configure notifications if enabled
          ${optionalString (cfg.notifications.enable && cfg.notifications.slack.enable) ''
            kubectl create secret generic argocd-notifications-secret \
              --from-literal=slack-webhook='${cfg.notifications.slack.webhook}' \
              -n argocd --dry-run=client -o yaml | kubectl apply -f -
          ''}
          
          echo ""
          echo "ArgoCD installed successfully!"
          echo ""
          echo "Access ArgoCD:"
          echo "  URL: https://argocd.k3s.local"
          echo "  Username: admin"
          echo "  Password: ${cfg.adminPassword}"
          echo ""
          echo "CLI access:"
          echo "  argocd login argocd.k3s.local --grpc-web"
          echo ""
          ${optionalString cfg.sealedSecrets.enable ''
            echo "Sealed Secrets:"
            echo "  Create: kubeseal --format yaml < secret.yaml > sealed-secret.yaml"
            echo "  Controller is running in namespace: ${cfg.sealedSecrets.namespace}"
            echo ""
          ''}
        '';
      };
    };
    
    # Install ArgoCD CLI
    environment.systemPackages = with pkgs; [
      argocd
      kubeseal
      
      # Helper scripts
      (pkgs.writeShellScriptBin "argocd-sync" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        APP="''${1:-}"
        if [[ -z "$APP" ]]; then
          echo "Usage: argocd-sync <app-name>"
          echo ""
          echo "Available apps:"
          argocd app list
          exit 1
        fi
        
        echo "Syncing application: $APP"
        argocd app sync "$APP"
        argocd app wait "$APP" --health
      '')
      
      (pkgs.writeShellScriptBin "argocd-create-app" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        NAME="''${1:-}"
        PATH="''${2:-k8s/apps/$NAME}"
        REPO="''${3:-https://github.com/jontk/nixconf}"
        
        if [[ -z "$NAME" ]]; then
          echo "Usage: argocd-create-app <name> [path] [repo]"
          exit 1
        fi
        
        cat << EOF | kubectl apply -f -
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: $NAME
          namespace: argocd
        spec:
          project: default
          source:
            repoURL: $REPO
            targetRevision: HEAD
            path: $PATH
          destination:
            server: https://kubernetes.default.svc
            namespace: $NAME
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
        EOF
        
        echo "Application $NAME created!"
      '')
      
      (pkgs.writeShellScriptBin "seal-secret" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        SECRET_FILE="''${1:-}"
        OUTPUT_FILE="''${2:-}"
        
        if [[ -z "$SECRET_FILE" ]]; then
          echo "Usage: seal-secret <secret.yaml> [output.yaml]"
          echo ""
          echo "Example:"
          echo "  # Create a secret"
          echo "  kubectl create secret generic mysecret --from-literal=password=secret --dry-run=client -o yaml > secret.yaml"
          echo "  # Seal it"
          echo "  seal-secret secret.yaml sealed-secret.yaml"
          echo "  # Apply sealed secret"
          echo "  kubectl apply -f sealed-secret.yaml"
          exit 1
        fi
        
        if [[ -z "$OUTPUT_FILE" ]]; then
          OUTPUT_FILE="''${SECRET_FILE%.yaml}-sealed.yaml"
        fi
        
        echo "Sealing secret: $SECRET_FILE -> $OUTPUT_FILE"
        kubeseal --format yaml < "$SECRET_FILE" > "$OUTPUT_FILE"
        echo "Sealed secret created: $OUTPUT_FILE"
      '')
    ];
    
    # Add ArgoCD host
    networking.hosts = {
      "127.0.0.1" = [ "argocd.k3s.local" ];
    };
    
    # Shell aliases
    environment.shellAliases = {
      argo = "argocd";
      argosync = "argocd-sync";
      argoapps = "argocd app list";
      argologs = "argocd app logs";
      seal = "seal-secret";
    };
  };
}