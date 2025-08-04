# K3s Monitoring Integration Module
# Provides comprehensive monitoring for Kubernetes with Prometheus, Grafana, and other tools

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.containers.kubernetes.monitoring;
  k8sCfg = config.modules.containers.kubernetes;
  
  # Prometheus configuration for k3s
  prometheusValues = ''
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: local-path
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 50Gi
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
        ruleSelectorNilUsesHelmValues: false
        
        # Additional scrape configs for k3s components
        additionalScrapeConfigs:
          - job_name: 'k3s'
            kubernetes_sd_configs:
              - role: node
            scheme: https
            tls_config:
              ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              insecure_skip_verify: true
            bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
            relabel_configs:
              - source_labels: [__address__]
                regex: '(.*):10250'
                replacement: '${1}:10249'
                target_label: __address__
                
    alertmanager:
      alertmanagerSpec:
        storage:
          volumeClaimTemplate:
            spec:
              storageClassName: local-path
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 10Gi
                  
    grafana:
      enabled: true
      adminPassword: admin
      persistence:
        enabled: true
        storageClassName: local-path
        size: 10Gi
      
      # Pre-configured dashboards
      sidecar:
        dashboards:
          enabled: true
          searchNamespace: ALL
          
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: "1"
          providers:
            - name: 'k3s'
              orgId: "1"
              folder: 'Kubernetes'
              type: file
              disableDeletion: false
              updateIntervalSeconds: "10"
              allowUiUpdates: false
              options:
                path: /var/lib/grafana/dashboards/k3s
                
      dashboards:
        k3s:
          k3s-cluster-dashboard:
            gnetId: "15282"
            revision: "1"
            datasource: Prometheus
          k3s-node-dashboard:
            gnetId: "15283"
            revision: "1"
            datasource: Prometheus
          kubernetes-cluster-monitoring:
            gnetId: "8588"
            revision: "1"
            datasource: Prometheus
  '';
  
  # Loki configuration for log aggregation
  lokiValues = ''
    loki:
      persistence:
        enabled: true
        storageClassName: local-path
        size: 50Gi
      config:
        auth_enabled: false
        ingester:
          chunk_idle_period: 3m
          chunk_retain_period: 1m
          lifecycler:
            ring:
              kvstore:
                store: inmemory
              replication_factor: "1"
        limits_config:
          enforce_metric_name: false
          reject_old_samples: true
          reject_old_samples_max_age: 168h
        schema_config:
          configs:
            - from: 2020-10-24
              store: boltdb-shipper
              object_store: filesystem
              schema: v11
              index:
                prefix: index_
                period: 24h
        server:
          http_listen_port: "3100"
        storage_config:
          boltdb_shipper:
            active_index_directory: /loki/boltdb-shipper-active
            cache_location: /loki/boltdb-shipper-cache
            cache_ttl: 24h
            shared_store: filesystem
          filesystem:
            directory: /loki/chunks
        chunk_store_config:
          max_look_back_period: 0s
        table_manager:
          retention_deletes_enabled: false
          retention_period: 0s
          
    promtail:
      config:
        clients:
          - url: http://loki:3100/loki/api/v1/push
        positions:
          filename: /tmp/positions.yaml
        scrape_configs:
          - job_name: kubernetes-pods
            kubernetes_sd_configs:
              - role: pod
            pipeline_stages:
              - cri: {}
            relabel_configs:
              - source_labels:
                  - __meta_kubernetes_pod_controller_name
                regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
                action: replace
                target_label: __tmp_controller_name
              - source_labels:
                  - __meta_kubernetes_pod_label_app_kubernetes_io_name
                  - __meta_kubernetes_pod_label_app
                  - __tmp_controller_name
                  - __meta_kubernetes_pod_name
                regex: ^;*([^;]+)(;.*)?$
                action: replace
                target_label: app
              - source_labels:
                  - __meta_kubernetes_pod_label_app_kubernetes_io_component
                  - __meta_kubernetes_pod_label_component
                regex: ^;*([^;]+)(;.*)?$
                action: replace
                target_label: component
  '';

in

{
  options.modules.containers.kubernetes.monitoring = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Kubernetes monitoring stack";
    };
    
    prometheus = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Prometheus monitoring";
      };
      
      retention = mkOption {
        type = types.str;
        default = "30d";
        description = "Metrics retention period";
      };
      
      storage = mkOption {
        type = types.str;
        default = "50Gi";
        description = "Storage size for Prometheus";
      };
    };
    
    grafana = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Grafana dashboards";
      };
      
      adminPassword = mkOption {
        type = types.str;
        default = "admin";
        description = "Grafana admin password";
      };
      
      dashboards = mkOption {
        type = types.listOf types.str;
        default = [
          "k3s-cluster"
          "k3s-nodes"
          "kubernetes-overview"
          "container-metrics"
        ];
        description = "Pre-configured dashboards to install";
      };
    };
    
    loki = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Loki log aggregation";
      };
      
      storage = mkOption {
        type = types.str;
        default = "50Gi";
        description = "Storage size for Loki";
      };
    };
    
    alerts = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable alerting rules";
      };
      
      slack = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Slack notifications";
        };
        
        webhookUrl = mkOption {
          type = types.str;
          default = "";
          description = "Slack webhook URL";
        };
      };
    };
  };

  config = mkIf (k8sCfg.enable && cfg.enable) {
    # Monitoring manifests to apply
    systemd.services.k3s-monitoring-setup = {
      description = "Deploy k3s monitoring stack";
      after = [ "k3s.service" "k3s-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "k3s-monitoring-setup" ''
          set -euo pipefail
          
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          # Wait for cluster to be ready
          echo "Waiting for k3s cluster to be ready..."
          timeout 120 bash -c 'until kubectl get nodes; do sleep 2; done'
          
          # Create monitoring namespace
          kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
          
          # Add Prometheus Helm repository
          helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
          helm repo add grafana https://grafana.github.io/helm-charts
          helm repo update
          
          # Install kube-prometheus-stack
          echo "Installing kube-prometheus-stack..."
          cat << 'EOF' > /tmp/prometheus-values.yaml
          ${prometheusValues}
          EOF
          
          helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --values /tmp/prometheus-values.yaml \
            --wait \
            --timeout 10m
          
          # Install Loki stack if enabled
          ${optionalString cfg.loki.enable ''
            echo "Installing Loki stack..."
            cat << 'EOF' > /tmp/loki-values.yaml
            ${lokiValues}
            EOF
            
            helm upgrade --install loki grafana/loki-stack \
              --namespace monitoring \
              --values /tmp/loki-values.yaml \
              --wait \
              --timeout 10m
          ''}
          
          # Create ServiceMonitors for k3s components
          cat << 'EOF' | kubectl apply -f -
          apiVersion: monitoring.coreos.com/v1
          kind: ServiceMonitor
          metadata:
            name: k3s-metrics
            namespace: monitoring
          spec:
            endpoints:
            - interval: 30s
              path: /metrics
              port: https-metrics
              scheme: https
              tlsConfig:
                insecureSkipVerify: true
            namespaceSelector:
              matchNames:
              - kube-system
            selector:
              matchLabels:
                k8s-app: metrics-server
          ---
          apiVersion: monitoring.coreos.com/v1
          kind: ServiceMonitor
          metadata:
            name: traefik
            namespace: monitoring
          spec:
            endpoints:
            - interval: 30s
              path: /metrics
              port: metrics
            namespaceSelector:
              matchNames:
              - kube-system
            selector:
              matchLabels:
                app.kubernetes.io/name: traefik
          EOF
          
          # Create Ingress for Grafana
          cat << 'EOF' | kubectl apply -f -
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: grafana
            namespace: monitoring
            annotations:
              traefik.ingress.kubernetes.io/router.tls: "true"
          spec:
            ingressClassName: traefik
            rules:
            - host: grafana.k3s.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: prometheus-grafana
                      port:
                        number: "80"
          EOF
          
          # Create Ingress for Prometheus
          cat << 'EOF' | kubectl apply -f -
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: prometheus
            namespace: monitoring
            annotations:
              traefik.ingress.kubernetes.io/router.tls: "true"
          spec:
            ingressClassName: traefik
            rules:
            - host: prometheus.k3s.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: prometheus-kube-prometheus-prometheus
                      port:
                        number: "9090"
          EOF
          
          # Create custom dashboards ConfigMap
          kubectl create configmap k3s-dashboards \
            --from-literal=k3s-overview.json='${builtins.toJSON {
              dashboard = {
                title = "K3s Cluster Overview";
                panels = [
                  {
                    title = "Cluster CPU Usage";
                    targets = [{
                      expr = "sum(rate(container_cpu_usage_seconds_total[5m]))";
                    }];
                  }
                  {
                    title = "Cluster Memory Usage";
                    targets = [{
                      expr = "sum(container_memory_usage_bytes)";
                    }];
                  }
                ];
              };
            }}' \
            --namespace monitoring \
            --dry-run=client -o yaml | kubectl apply -f -
          
          echo "Monitoring stack deployed successfully!"
          echo ""
          echo "Access points:"
          echo "  Grafana: http://grafana.k3s.local (admin/${cfg.grafana.adminPassword})"
          echo "  Prometheus: http://prometheus.k3s.local"
          echo ""
          echo "To access locally, add to /etc/hosts:"
          echo "  127.0.0.1 grafana.k3s.local prometheus.k3s.local"
        '';
      };
    };
    
    # Add monitoring hosts to local DNS
    networking.hosts = {
      "127.0.0.1" = [ "grafana.k3s.local" "prometheus.k3s.local" ];
    };
    
    # Ensure helm is available
    environment.systemPackages = with pkgs; [
      kubernetes-helm
    ];
  };
}