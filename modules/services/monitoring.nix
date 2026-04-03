# Monitoring Services Configuration
{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  cfg = config.nixconf.services.monitoring;
in
{
  options.nixconf.services.monitoring = with lib; {
    enable = mkEnableOption "monitoring services" // { default = false; };
    
    prometheus = {
      enable = mkEnableOption "Prometheus metrics collection" // { default = true; };
      
      port = mkOption {
        type = types.port;
        default = 9090;
        description = "Port for Prometheus web interface";
      };
      
      retentionTime = mkOption {
        type = types.str;
        default = "30d";
        description = "How long to retain metrics data";
      };
      
      scrapeInterval = mkOption {
        type = types.str;
        default = "15s";
        description = "Default scrape interval";
      };
      
      exporters = {
        node = mkOption {
          type = types.bool;
          default = true;
          description = "Enable node exporter for system metrics";
        };
        
        postgres = mkOption {
          type = types.bool;
          default = config.nixconf.services.databases.postgresql.enable or false;
          description = "Enable PostgreSQL exporter";
        };
        
        redis = mkOption {
          type = types.bool;
          default = config.nixconf.services.databases.redis.enable or false;
          description = "Enable Redis exporter";
        };
        
        nginx = mkOption {
          type = types.bool;
          default = config.nixconf.services.webServers.nginx.enable or false;
          description = "Enable Nginx exporter";
        };
      };
    };
    
    grafana = {
      enable = mkEnableOption "Grafana visualization" // { default = true; };
      
      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for Grafana web interface";
      };
      
      adminPassword = mkOption {
        type = types.str;
        default = "admin";
        description = "Initial admin password (change after first login)";
      };
      
      theme = mkOption {
        type = types.enum [ "dark" "light" ];
        default = "dark";
        description = "Default UI theme";
      };
    };
    
    loki = {
      enable = mkEnableOption "Loki log aggregation" // { default = false; };
      
      port = mkOption {
        type = types.port;
        default = 3100;
        description = "Port for Loki API";
      };
    };
    
    alertmanager = {
      enable = mkEnableOption "Prometheus Alertmanager" // { default = false; };
      
      port = mkOption {
        type = types.port;
        default = 9093;
        description = "Port for Alertmanager web interface";
      };
      
      slackWebhookUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Slack webhook URL for notifications";
      };
    };
  };
  
  config = lib.mkIf (cfg.enable && isNixOS) {
    # Prometheus configuration
    services.prometheus = lib.mkIf cfg.prometheus.enable {
      enable = true;
      port = cfg.prometheus.port;
      retentionTime = cfg.prometheus.retentionTime;
      
      globalConfig = {
        scrape_interval = cfg.prometheus.scrapeInterval;
        evaluation_interval = cfg.prometheus.scrapeInterval;
      };
      
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:${toString cfg.prometheus.port}" ];
          }];
        }
      ] ++ lib.optional cfg.prometheus.exporters.node {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      } ++ lib.optional cfg.prometheus.exporters.postgres {
        job_name = "postgres";
        static_configs = [{
          targets = [ "localhost:9187" ];
        }];
      } ++ lib.optional cfg.prometheus.exporters.redis {
        job_name = "redis";
        static_configs = [{
          targets = [ "localhost:9121" ];
        }];
      } ++ lib.optional cfg.prometheus.exporters.nginx {
        job_name = "nginx";
        static_configs = [{
          targets = [ "localhost:9113" ];
        }];
      } ++ lib.optional cfg.grafana.enable {
        job_name = "grafana";
        static_configs = [{
          targets = [ "localhost:${toString cfg.grafana.port}" ];
        }];
      };
      
      rules = [
        ''
          groups:
          - name: system
            interval: 30s
            rules:
            - alert: HighCPUUsage
              expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU usage detected"
                description: "CPU usage is above 80% (current value: {{ $value }})"
            
            - alert: HighMemoryUsage
              expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High memory usage detected"
                description: "Memory usage is above 80% (current value: {{ $value }})"
            
            - alert: DiskSpaceLow
              expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} / node_filesystem_size_bytes) * 100 < 20
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Low disk space"
                description: "Disk space is below 20% (current value: {{ $value }})"
        ''
      ];
      
      # Prometheus exporters
      exporters = {
      node = lib.mkIf cfg.prometheus.exporters.node {
        enable = true;
        port = 9100;
        enabledCollectors = [
          "systemd"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "time"
          "uname"
        ];
      };
      
      postgres = lib.mkIf cfg.prometheus.exporters.postgres {
        enable = true;
        port = 9187;
        runAsLocalSuperUser = true;
      };
      
      redis = lib.mkIf cfg.prometheus.exporters.redis {
        enable = true;
        port = 9121;
      };
      
      nginx = lib.mkIf cfg.prometheus.exporters.nginx {
        enable = true;
        port = 9113;
        scrapeUri = "http://localhost/nginx_status";
      };
      };
      
      # Alertmanager configuration
      alertmanager = lib.mkIf cfg.alertmanager.enable {
        enable = true;
        port = cfg.alertmanager.port;
        
        configuration = {
          route = {
            group_by = [ "alertname" "cluster" "service" ];
            group_wait = "10s";
            group_interval = "10s";
            repeat_interval = "1h";
            receiver = "default";
          };
          
          receivers = [
            {
              name = "default";
            }
          ] ++ lib.optional (cfg.alertmanager.slackWebhookUrl != null) {
            name = "slack";
            slack_configs = [{
              api_url = cfg.alertmanager.slackWebhookUrl;
              channel = "#alerts";
              title = "Alert: {{ .GroupLabels.alertname }}";
              text = "{{ .CommonAnnotations.description }}";
            }];
          };
        };
      };
    };
    
    # Grafana configuration
    services.grafana = lib.mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          domain = "localhost";
          root_url = "http://localhost:${toString cfg.grafana.port}";
        };
        
        security = {
          admin_password = cfg.grafana.adminPassword;
          admin_user = "admin";
        };
        
        users = {
          default_theme = cfg.grafana.theme;
        };
        
        analytics.reporting_enabled = false;
        
        # Enable unified alerting
        unified_alerting = {
          enabled = true;
          max_annotation_age = "744h"; # 31 days
        };
        
        # SMTP configuration for notifications (optional)
        smtp = {
          enabled = false;
          # host = "localhost:587";
          # user = "";
          # password = "";
          # from_address = "admin@grafana.localhost";
          # from_name = "Grafana";
        };
      };
      
      provision = {
        enable = true;
        
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString cfg.prometheus.port}";
            isDefault = true;
          }
        ] ++ lib.optional cfg.loki.enable {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://localhost:${toString cfg.loki.port}";
        };
        
        dashboards.settings.providers = [{
          name = "Default";
          options.path = "/etc/grafana/dashboards";
          orgId = 1;
          type = "file";
          folder = "Monitoring";
          folderUid = "monitoring";
          disableDeletion = true;
          updateIntervalSeconds = 300;
        }];
        
        alerting.rules.settings.groups = [{
          name = "system-alerts";
          orgId = 1;
          folder = "alerts";
          interval = "1m";
          rules = [
            {
              uid = "cpu-high";
              title = "High CPU Usage";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "5m";
              annotations = {
                summary = "High CPU usage detected";
                description = "CPU usage is above 80% for more than 5 minutes";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "memory-high";
              title = "High Memory Usage";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "5m";
              annotations = {
                summary = "High memory usage detected";
                description = "Memory usage is above 85% for more than 5 minutes";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "disk-full";
              title = "Disk Space Low";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|fuse.lxcfs\",mountpoint=\"/\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs\",mountpoint=\"/\"})) * 100";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "2m";
              annotations = {
                summary = "Disk space is running low";
                description = "Disk usage is above 90%";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "service-down";
              title = "Service Down";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = "up == 0";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Service is down";
                description = "Service {{$labels.job}} on {{$labels.instance}} is down";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "postgres-down";
              title = "PostgreSQL Service Down";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = "pg_up == 0";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "PostgreSQL database is down";
                description = "PostgreSQL service is not responding";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "postgres-connections-high";
              title = "PostgreSQL High Connection Count";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "sum(pg_stat_database_numbackends) > 80";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "5m";
              annotations = {
                summary = "PostgreSQL connection count is high";
                description = "PostgreSQL has more than 80 active connections";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "redis-down";
              title = "Redis Service Down";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = "redis_up == 0";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Redis service is down";
                description = "Redis cache service is not responding";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "redis-memory-high";
              title = "Redis High Memory Usage";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "redis_memory_used_bytes / redis_memory_max_bytes * 100 > 85";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "5m";
              annotations = {
                summary = "Redis memory usage is high";
                description = "Redis is using more than 85% of available memory";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "nginx-down";
              title = "Nginx Service Down";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = "nginx_up == 0";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Nginx web server is down";
                description = "Nginx service is not responding";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "nginx-high-error-rate";
              title = "Nginx High Error Rate";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = "rate(nginx_http_requests_total{status=~\"5..\"}[5m]) / rate(nginx_http_requests_total[5m]) * 100 > 5";
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "prometheus";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "3m";
              annotations = {
                summary = "Nginx 5xx error rate is high";
                description = "More than 5% of requests are returning 5xx errors";
              };
              labels = {
                severity = "warning";
              };
            }
          ];
        }
        {
          name = "log-alerts";
          orgId = 1;
          folder = "alerts";
          interval = "1m";
          rules = [
            {
              uid = "nginx-error-spike";
              title = "Nginx Error Rate Spike";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = ''rate({job="nginx-error"} |= "error" [5m])'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "2m";
              annotations = {
                summary = "High nginx error rate detected";
                description = "Nginx error logs are showing elevated error rates";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "database-errors";
              title = "Database Error Logs";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job="postgresql"} |~ "(?i)(error|fatal|panic)" [10m]))'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Database errors detected in logs";
                description = "PostgreSQL logs contain error, fatal, or panic messages";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "service-restart-loop";
              title = "Service Restart Loop";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(started|stopped|failed)" [10m])) by (unit)'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "3m";
              annotations = {
                summary = "Service restart loop detected";
                description = "Service {{$labels.unit}} is restarting frequently";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "authentication-failures";
              title = "Authentication Failures";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(authentication failure|failed login|invalid user)" [5m]))'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Authentication failures detected";
                description = "Multiple authentication failures detected in system logs";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "disk-space-warnings";
              title = "Disk Space Warnings in Logs";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(no space left|disk full|filesystem full)" [10m]))'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Disk space warnings in logs";
                description = "Disk space warnings detected in system logs";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "oom-killer";
              title = "Out of Memory Killer";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(oom.killer|out of memory|killed process)" [10m]))'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Out of memory killer activated";
                description = "OOM killer has been activated, system is running low on memory";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "log-volume-anomaly";
              title = "Log Volume Anomaly";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 1800;
                  to = 0;
                };
                model = {
                  expr = ''(sum(rate({job=~".+"} [5m])) - avg_over_time(sum(rate({job=~".+"} [5m]))[30m:5m])) / stddev_over_time(sum(rate({job=~".+"} [5m]))[30m:5m]) > 3'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "5m";
              annotations = {
                summary = "Abnormal log volume detected";
                description = "Log volume is significantly higher than normal (>3 standard deviations)";
              };
              labels = {
                severity = "warning";
              };
            }
            {
              uid = "error-rate-anomaly";
              title = "Error Rate Anomaly";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 1800;
                  to = 0;
                };
                model = {
                  expr = ''(sum(rate({job=~".+"} |~ "(?i)(error|fatal|panic)" [5m])) - avg_over_time(sum(rate({job=~".+"} |~ "(?i)(error|fatal|panic)" [5m]))[30m:5m])) / stddev_over_time(sum(rate({job=~".+"} |~ "(?i)(error|fatal|panic)" [5m]))[30m:5m]) > 2'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "3m";
              annotations = {
                summary = "Abnormal error rate detected";
                description = "Error rate is significantly higher than normal (>2 standard deviations)";
              };
              labels = {
                severity = "critical";
              };
            }
            {
              uid = "new-error-pattern";
              title = "New Error Pattern Detected";
              condition = "A";
              data = [{
                refId = "A";
                queryType = "";
                relativeTimeRange = {
                  from = 300;
                  to = 0;
                };
                model = {
                  expr = ''sum(count_over_time({job=~".+"} |~ "(?i)(exception|stack trace|segmentation fault|core dumped)" [5m]))'';
                  intervalMs = 1000;
                  maxDataPoints = 43200;
                  refId = "A";
                };
                datasourceUid = "loki";
              }];
              noDataState = "NoData";
              execErrState = "Alerting";
              for_ = "1m";
              annotations = {
                summary = "Critical error pattern detected";
                description = "Detected severe errors: exceptions, stack traces, or crashes";
              };
              labels = {
                severity = "critical";
              };
            }
          ];
        }];
      };
    };
    
    # Loki configuration
    services.loki = lib.mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        server.http_listen_port = cfg.loki.port;
        auth_enabled = false;
        
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };
        
        schema_config = {
          configs = [{
            from = "2023-01-01";
            store = "boltdb";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "168h";
            };
          }];
        };
        
        storage_config = {
          boltdb = {
            directory = "/var/lib/loki/index";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        
        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          allow_structured_metadata = false;
          retention_period = "720h"; # 30 days
          max_query_length = "12000h"; # 500 days max query range
          max_query_parallelism = 32;
          max_streams_per_user = 0; # unlimited
          max_line_size = 256000; # 256KB max line size
          ingestion_rate_mb = 16; # 16MB/s ingestion rate
          ingestion_burst_size_mb = 32; # 32MB burst
          per_stream_rate_limit = "3MB";
          per_stream_rate_limit_burst = "15MB";
        };
        
        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "720h"; # 30 days retention
        };
        
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "filesystem";
        };
      };
    };
    
    # Promtail for shipping logs to Loki
    services.promtail = lib.mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        
        positions = {
          filename = "/tmp/positions.yaml";
        };
        
        clients = [{
          url = "http://localhost:${toString cfg.loki.port}/loki/api/v1/push";
        }];
        
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal_priority" ];
                target_label = "priority";
              }
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "hostname";
              }
            ];
            pipeline_stages = [
              {
                json = {
                  expressions = {
                    level = "PRIORITY";
                    message = "MESSAGE";
                    unit = "_SYSTEMD_UNIT";
                  };
                };
              }
              {
                labels = {
                  level = null;
                  unit = null;
                };
              }
            ];
          }
          {
            job_name = "nginx-access";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "nginx-access";
                __path__ = "/var/log/nginx/access.log";
              };
            }];
            pipeline_stages = [
              {
                regex = {
                  expression = ''^(?P<remote_addr>[\d\.]+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request_uri>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)" "(?P<http_x_forwarded_for>[^"]*)"'';
                };
              }
              {
                labels = {
                  method = null;
                  status = null;
                  remote_addr = null;
                };
              }
              {
                drop = {
                  expression = ".*healthcheck.*";
                  drop_counter_reason = "healthcheck";
                };
              }
            ];
          }
          {
            job_name = "nginx-error";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "nginx-error";
                __path__ = "/var/log/nginx/error.log";
                level = "error";
              };
            }];
            pipeline_stages = [
              {
                regex = {
                  expression = ''^(?P<timestamp>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?P<level>\w+)\] (?P<pid>\d+)#(?P<tid>\d+): (?P<message>.*)$'';
                };
              }
              {
                labels = {
                  level = null;
                  pid = null;
                };
              }
            ];
          }
          {
            job_name = "postgresql";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "postgresql";
                __path__ = "/var/log/postgresql/*.log";
              };
            }];
            pipeline_stages = [
              {
                regex = {
                  expression = ''^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \w+) \[(?P<pid>\d+)\] (?P<level>\w+):  (?P<message>.*)$'';
                };
              }
              {
                labels = {
                  level = null;
                  pid = null;
                };
              }
              {
                drop = {
                  expression = ".*connection received.*|.*connection authorized.*";
                  drop_counter_reason = "routine_connections";
                };
              }
            ];
          }
          {
            job_name = "redis";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "redis";
                __path__ = "/var/log/redis/*.log";
              };
            }];
            pipeline_stages = [
              {
                regex = {
                  expression = ''^(?P<pid>\d+):(?P<role>\w+) (?P<timestamp>\d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2}\.\d{3}) (?P<level>[#*\-\.]) (?P<message>.*)$'';
                };
              }
              {
                labels = {
                  level = null;
                  role = null;
                  pid = null;
                };
              }
            ];
          }
          {
            job_name = "grafana";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "grafana";
                __path__ = "/var/log/grafana/*.log";
              };
            }];
            pipeline_stages = [
              {
                json = {
                  expressions = {
                    level = "lvl";
                    logger = "logger";
                    message = "msg";
                    timestamp = "t";
                  };
                };
              }
              {
                labels = {
                  level = null;
                  logger = null;
                };
              }
            ];
          }
        ];
      };
    };
    
    
    # Nginx configuration for exporters
    services.nginx.virtualHosts = lib.mkIf (cfg.prometheus.exporters.nginx && config.services.nginx.enable) {
      "localhost" = {
        locations."/nginx_status" = {
          extraConfig = ''
            stub_status on;
            allow 127.0.0.1;
            deny all;
          '';
        };
      };
    };
    
    # Firewall rules for monitoring services
    networking.firewall.allowedTCPPorts = 
      lib.optional cfg.prometheus.enable cfg.prometheus.port
      ++ lib.optional cfg.grafana.enable cfg.grafana.port
      ++ lib.optional cfg.loki.enable cfg.loki.port
      ++ lib.optional cfg.alertmanager.enable cfg.alertmanager.port;
    
    # System packages for monitoring
    environment.systemPackages = with pkgs; [
      prometheus
      grafana
      prometheus-node-exporter
    ] ++ lib.optionals cfg.loki.enable [
      loki
      promtail
    ];
    
    # Create comprehensive dashboard files
    environment.etc = lib.mkIf cfg.grafana.enable {
      "grafana/dashboards/system-overview.json".text = builtins.toJSON {
        dashboard = {
          id = null;
          title = "System Overview";
          tags = ["system" "overview"];
          panels = [
            # Top row - Key metrics
            {
              id = 1;
              title = "CPU Usage";
              type = "stat";
              targets = [{
                expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "percent";
                  min = 0;
                  max = 100;
                  thresholds = {
                    steps = [
                      { color = "green"; value = null; }
                      { color = "yellow"; value = 70; }
                      { color = "red"; value = 90; }
                    ];
                  };
                };
              };
              gridPos = { h = 8; w = 6; x = 0; y = 0; };
            }
            {
              id = 2;
              title = "Memory Usage";
              type = "stat";
              targets = [{
                expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "percent";
                  min = 0;
                  max = 100;
                  thresholds = {
                    steps = [
                      { color = "green"; value = null; }
                      { color = "yellow"; value = 70; }
                      { color = "red"; value = 90; }
                    ];
                  };
                };
              };
              gridPos = { h = 8; w = 6; x = 6; y = 0; };
            }
            {
              id = 3;
              title = "Disk Usage";
              type = "stat";
              targets = [{
                expr = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|fuse.lxcfs\",mountpoint=\"/\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs\",mountpoint=\"/\"})) * 100";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "percent";
                  min = 0;
                  max = 100;
                  thresholds = {
                    steps = [
                      { color = "green"; value = null; }
                      { color = "yellow"; value = 70; }
                      { color = "red"; value = 90; }
                    ];
                  };
                };
              };
              gridPos = { h = 8; w = 6; x = 12; y = 0; };
            }
            {
              id = 4;
              title = "Load Average";
              type = "stat";
              targets = [{
                expr = "node_load15";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "short";
                  decimals = 2;
                };
              };
              gridPos = { h = 8; w = 6; x = 18; y = 0; };
            }
            # Second row - Time series
            {
              id = 5;
              title = "CPU Usage Over Time";
              type = "timeseries";
              targets = [
                {
                  expr = "100 - (avg by (cpu) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                  refId = "A";
                  legendFormat = "CPU {{cpu}}";
                }
                {
                  expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                  refId = "B";
                  legendFormat = "Average CPU";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "percent";
                  min = 0;
                  max = 100;
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 8; };
            }
            {
              id = 6;
              title = "Memory Usage Over Time";
              type = "timeseries";
              targets = [
                {
                  expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes";
                  refId = "A";
                  legendFormat = "Used Memory";
                }
                {
                  expr = "node_memory_MemAvailable_bytes";
                  refId = "B";
                  legendFormat = "Available Memory";
                }
                {
                  expr = "node_memory_Cached_bytes";
                  refId = "C";
                  legendFormat = "Cached";
                }
                {
                  expr = "node_memory_Buffers_bytes";
                  refId = "D";
                  legendFormat = "Buffers";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "bytes";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 8; };
            }
            # Third row - Network and Disk I/O
            {
              id = 7;
              title = "Network I/O";
              type = "timeseries";
              targets = [
                {
                  expr = "rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*\"}[5m])";
                  refId = "A";
                  legendFormat = "{{device}} - Receive";
                }
                {
                  expr = "rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*\"}[5m])";
                  refId = "B";
                  legendFormat = "{{device}} - Transmit";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "binBps";
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 16; };
            }
            {
              id = 8;
              title = "Disk I/O";
              type = "timeseries";
              targets = [
                {
                  expr = "rate(node_disk_read_bytes_total[5m])";
                  refId = "A";
                  legendFormat = "{{device}} - Read";
                }
                {
                  expr = "rate(node_disk_written_bytes_total[5m])";
                  refId = "B";
                  legendFormat = "{{device}} - Write";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "binBps";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 16; };
            }
            # Fourth row - System info and services
            {
              id = 9;
              title = "System Information";
              type = "table";
              targets = [{
                expr = "node_uname_info";
                refId = "A";
                format = "table";
                instant = true;
              }];
              transformations = [{
                id = "organize";
                options = {
                  excludeByName = { Time = true; __name__ = true; job = true; instance = true; };
                  renameByName = {
                    nodename = "Hostname";
                    release = "Kernel";
                    sysname = "OS";
                    machine = "Architecture";
                  };
                };
              }];
              gridPos = { h = 6; w = 12; x = 0; y = 24; };
            }
            {
              id = 10;
              title = "Service Status";
              type = "table";
              targets = [{
                expr = "up";
                refId = "A";
                format = "table";
                instant = true;
              }];
              transformations = [{
                id = "organize";
                options = {
                  excludeByName = { Time = true; __name__ = true; };
                  renameByName = {
                    job = "Service";
                    instance = "Instance";
                    Value = "Status";
                  };
                };
              }];
              fieldConfig = {
                overrides = [{
                  matcher = { id = "byName"; options = "Status"; };
                  properties = [{
                    id = "mappings";
                    value = [
                      { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                      { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                    ];
                  }];
                }];
              };
              gridPos = { h = 6; w = 12; x = 12; y = 24; };
            }
          ];
          time = { from = "now-1h"; to = "now"; };
          refresh = "30s";
        };
      };
      
      # PostgreSQL Dashboard
      "grafana/dashboards/postgresql.json".text = builtins.toJSON {
        dashboard = {
          id = null;
          title = "PostgreSQL Monitoring";
          tags = ["postgresql" "database"];
          panels = [
            {
              id = 1;
              title = "PostgreSQL Status";
              type = "stat";
              targets = [{
                expr = "pg_up";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 6; w = 6; x = 0; y = 0; };
            }
            {
              id = 2;
              title = "Active Connections";
              type = "stat";
              targets = [{
                expr = "sum(pg_stat_database_numbackends{datname!~\"template.*\"})";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "short";
                  thresholds = {
                    steps = [
                      { color = "green"; value = null; }
                      { color = "yellow"; value = 80; }
                      { color = "red"; value = 95; }
                    ];
                  };
                };
              };
              gridPos = { h = 6; w = 6; x = 6; y = 0; };
            }
            {
              id = 3;
              title = "Total Database Size";
              type = "stat";
              targets = [{
                expr = "sum(pg_database_size_bytes{datname!~\"template.*\"})";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "bytes";
                };
              };
              gridPos = { h = 6; w = 6; x = 12; y = 0; };
            }
            {
              id = 4;
              title = "Transactions per Second";
              type = "stat";
              targets = [{
                expr = "sum(rate(pg_stat_database_xact_commit{datname!~\"template.*\"}[5m])) + sum(rate(pg_stat_database_xact_rollback{datname!~\"template.*\"}[5m]))";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                  decimals = 2;
                };
              };
              gridPos = { h = 6; w = 6; x = 18; y = 0; };
            }
            {
              id = 5;
              title = "Database Connections";
              type = "timeseries";
              targets = [{
                expr = "pg_stat_database_numbackends{datname!~\"template.*\"}";
                refId = "A";
                legendFormat = "{{datname}}";
              }];
              fieldConfig = {
                defaults = {
                  unit = "short";
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 6; };
            }
            {
              id = 6;
              title = "Transaction Rate";
              type = "timeseries";
              targets = [
                {
                  expr = "rate(pg_stat_database_xact_commit{datname!~\"template.*\"}[5m])";
                  refId = "A";
                  legendFormat = "{{datname}} - Commits";
                }
                {
                  expr = "rate(pg_stat_database_xact_rollback{datname!~\"template.*\"}[5m])";
                  refId = "B";
                  legendFormat = "{{datname}} - Rollbacks";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 6; };
            }
          ];
          time = { from = "now-1h"; to = "now"; };
          refresh = "30s";
        };
      };
      
      # Redis Dashboard
      "grafana/dashboards/redis.json".text = builtins.toJSON {
        dashboard = {
          id = null;
          title = "Redis Monitoring";
          tags = ["redis" "cache"];
          panels = [
            {
              id = 1;
              title = "Redis Status";
              type = "stat";
              targets = [{
                expr = "redis_up";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 6; w = 6; x = 0; y = 0; };
            }
            {
              id = 2;
              title = "Connected Clients";
              type = "stat";
              targets = [{
                expr = "redis_connected_clients";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "short";
                };
              };
              gridPos = { h = 6; w = 6; x = 6; y = 0; };
            }
            {
              id = 3;
              title = "Memory Usage";
              type = "stat";
              targets = [{
                expr = "redis_memory_used_bytes";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "bytes";
                };
              };
              gridPos = { h = 6; w = 6; x = 12; y = 0; };
            }
            {
              id = 4;
              title = "Operations per Second";
              type = "stat";
              targets = [{
                expr = "rate(redis_commands_processed_total[5m])";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                  decimals = 2;
                };
              };
              gridPos = { h = 6; w = 6; x = 18; y = 0; };
            }
            {
              id = 5;
              title = "Commands Rate";
              type = "timeseries";
              targets = [{
                expr = "rate(redis_commands_processed_total[5m])";
                refId = "A";
                legendFormat = "Commands/sec";
              }];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 6; };
            }
            {
              id = 6;
              title = "Memory Usage Over Time";
              type = "timeseries";
              targets = [
                {
                  expr = "redis_memory_used_bytes";
                  refId = "A";
                  legendFormat = "Used Memory";
                }
                {
                  expr = "redis_memory_max_bytes";
                  refId = "B";
                  legendFormat = "Max Memory";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "bytes";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 6; };
            }
          ];
          time = { from = "now-1h"; to = "now"; };
          refresh = "30s";
        };
      };
      
      # Nginx Dashboard
      "grafana/dashboards/nginx.json".text = builtins.toJSON {
        dashboard = {
          id = null;
          title = "Nginx Monitoring";
          tags = ["nginx" "web-server"];
          panels = [
            {
              id = 1;
              title = "Nginx Status";
              type = "stat";
              targets = [{
                expr = "nginx_up";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 6; w = 6; x = 0; y = 0; };
            }
            {
              id = 2;
              title = "Active Connections";
              type = "stat";
              targets = [{
                expr = "nginx_connections_active";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "short";
                };
              };
              gridPos = { h = 6; w = 6; x = 6; y = 0; };
            }
            {
              id = 3;
              title = "Requests per Second";
              type = "stat";
              targets = [{
                expr = "rate(nginx_http_requests_total[5m])";
                refId = "A";
              }];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                  decimals = 2;
                };
              };
              gridPos = { h = 6; w = 6; x = 12; y = 0; };
            }
            {
              id = 4;
              title = "Request Rate";
              type = "timeseries";
              targets = [{
                expr = "rate(nginx_http_requests_total[5m])";
                refId = "A";
                legendFormat = "Requests/sec";
              }];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 6; };
            }
            {
              id = 5;
              title = "Connection States";
              type = "timeseries";
              targets = [
                {
                  expr = "nginx_connections_active";
                  refId = "A";
                  legendFormat = "Active";
                }
                {
                  expr = "nginx_connections_reading";
                  refId = "B";
                  legendFormat = "Reading";
                }
                {
                  expr = "nginx_connections_writing";
                  refId = "C";
                  legendFormat = "Writing";
                }
                {
                  expr = "nginx_connections_waiting";
                  refId = "D";
                  legendFormat = "Waiting";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "short";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 6; };
            }
          ];
          time = { from = "now-1h"; to = "now"; };
          refresh = "30s";
        };
      };
      
      # Log Analysis Dashboard
      "grafana/dashboards/log-analysis.json".text = builtins.toJSON {
        id = null;
        title = "Log Analysis & Monitoring";
        tags = ["logs" "analysis" "monitoring"];
        timezone = "browser";
        panels = [
          {
            id = 1;
            title = "Log Volume by Service";
            type = "timeseries";
            targets = [
              {
                expr = ''sum(rate({job=~".+"} [1m])) by (job)'';
                refId = "A";
                legendFormat = "{{job}}";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "logs/sec";
              };
            };
            gridPos = { h = 8; w = 12; x = 0; y = 0; };
          }
          {
            id = 2;
            title = "Error Rate by Service";
            type = "timeseries";
            targets = [
              {
                expr = ''sum(rate({job=~".+"} |~ "(?i)(error|fatal|panic|exception)" [5m])) by (job)'';
                refId = "A";
                legendFormat = "{{job}} errors";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "errors/sec";
                color = { mode = "fixed"; fixedColor = "red"; };
              };
            };
            gridPos = { h = 8; w = 12; x = 12; y = 0; };
          }
          {
            id = 3;
            title = "Top Error Messages";
            type = "table";
            targets = [
              {
                expr = ''topk(10, sum(count_over_time({job=~".+"} |~ "(?i)(error|fatal|panic)" [1h])) by (job))'';
                refId = "A";
                format = "table";
              }
            ];
            fieldConfig = {
              defaults = {
                custom = {
                  displayMode = "table";
                };
              };
            };
            gridPos = { h = 8; w = 8; x = 0; y = 8; };
          }
          {
            id = 4;
            title = "HTTP Status Codes (Nginx)";
            type = "pie";
            targets = [
              {
                expr = ''sum(count_over_time({job="nginx-access"} | json | status != "" [1h])) by (status)'';
                refId = "A";
                legendFormat = "{{status}}";
              }
            ];
            gridPos = { h = 8; w = 8; x = 8; y = 8; };
          }
          {
            id = 5;
            title = "Service Restarts";
            type = "stat";
            targets = [
              {
                expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(started|restarted)" [1h]))'';
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "short";
                thresholds = {
                  steps = [
                    { color = "green"; value = null; }
                    { color = "yellow"; value = 5; }
                    { color = "red"; value = 10; }
                  ];
                };
              };
            };
            gridPos = { h = 8; w = 8; x = 16; y = 8; };
          }
          {
            id = 6;
            title = "Authentication Events";
            type = "timeseries";
            targets = [
              {
                expr = ''sum(rate({job="systemd-journal"} |~ "(?i)(authentication|login)" [5m])) by (level)'';
                refId = "A";
                legendFormat = "{{level}}";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "events/sec";
              };
            };
            gridPos = { h = 8; w = 12; x = 0; y = 16; };
          }
          {
            id = 7;
            title = "Database Query Patterns";
            type = "timeseries";
            targets = [
              {
                expr = ''sum(rate({job="postgresql"} |~ "(?i)(select|insert|update|delete)" [5m]))'';
                refId = "A";
                legendFormat = "Query rate";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "queries/sec";
              };
            };
            gridPos = { h = 8; w = 12; x = 12; y = 16; };
          }
          {
            id = 8;
            title = "Recent Error Logs";
            type = "logs";
            targets = [
              {
                expr = ''{job=~".+"} |~ "(?i)(error|fatal|panic|exception)"'';
                refId = "A";
              }
            ];
            options = {
              showTime = true;
              showLabels = true;
              showCommonLabels = false;
              wrapLogMessage = true;
              prettifyLogMessage = false;
              enableLogDetails = true;
              dedupStrategy = "none";
              sortOrder = "Descending";
            };
            gridPos = { h = 10; w = 24; x = 0; y = 24; };
          }
          {
            id = 9;
            title = "Log Level Distribution";
            type = "donut";
            targets = [
              {
                expr = ''sum(count_over_time({job=~".+"} [1h])) by (level)'';
                refId = "A";
                legendFormat = "{{level}}";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "short";
              };
            };
            gridPos = { h = 8; w = 8; x = 0; y = 34; };
          }
          {
            id = 10;
            title = "Response Time Anomalies (Nginx)";
            type = "timeseries";
            targets = [
              {
                expr = ''histogram_quantile(0.95, sum(rate({job="nginx-access"} | json | response_time != "" | unwrap response_time [5m])) by (le))'';
                refId = "A";
                legendFormat = "95th percentile";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "s";
              };
            };
            gridPos = { h = 8; w = 8; x = 8; y = 34; };
          }
          {
            id = 11;
            title = "System Resource Warnings";
            type = "stat";
            targets = [
              {
                expr = ''sum(count_over_time({job="systemd-journal"} |~ "(?i)(memory|disk|cpu)" |~ "(?i)(warning|critical)" [24h]))'';
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                unit = "short";
                thresholds = {
                  steps = [
                    { color = "green"; value = null; }
                    { color = "yellow"; value = 1; }
                    { color = "red"; value = 5; }
                  ];
                };
              };
            };
            gridPos = { h = 8; w = 8; x = 16; y = 34; };
          }
        ];
        time = { from = "now-6h"; to = "now"; };
        refresh = "30s";
      };
      
      # Service Topology Dashboard
      "grafana/dashboards/service-topology.json".text = builtins.toJSON {
        dashboard = {
          id = null;
          title = "Service Topology & Dependencies";
          tags = ["topology" "dependencies" "architecture"];
          timezone = "browser";
          panels = [
            {
              id = 1;
              title = "Service Health Overview";
              type = "stat";
              targets = [
                {
                  expr = "count(up == 1)";
                  refId = "A";
                  legendFormat = "Services Up";
                }
                {
                  expr = "count(up == 0)";
                  refId = "B";
                  legendFormat = "Services Down";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "short";
                };
                overrides = [
                  {
                    matcher = { id = "byFrameRefID"; options = "A"; };
                    properties = [
                      { id = "color"; value = { mode = "fixed"; fixedColor = "green"; }; }
                    ];
                  }
                  {
                    matcher = { id = "byFrameRefID"; options = "B"; };
                    properties = [
                      { id = "color"; value = { mode = "fixed"; fixedColor = "red"; }; }
                    ];
                  }
                ];
              };
              gridPos = { h = 6; w = 12; x = 0; y = 0; };
            }
            {
              id = 2;
              title = "Service Status Matrix";
              type = "table";
              targets = [
                {
                  expr = "up";
                  refId = "A";
                  format = "table";
                  instant = true;
                }
              ];
              transformations = [
                {
                  id = "organize";
                  options = {
                    excludeByName = { Time = true; "__name__" = true; };
                    indexByName = {};
                    renameByName = {
                      job = "Service";
                      instance = "Instance";
                      Value = "Status";
                    };
                  };
                }
              ];
              fieldConfig = {
                overrides = [
                  {
                    matcher = { id = "byName"; options = "Status"; };
                    properties = [
                      {
                        id = "mappings";
                        value = [
                          { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                          { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                        ];
                      }
                    ];
                  }
                ];
              };
              gridPos = { h = 6; w = 12; x = 12; y = 0; };
            }
            {
              id = 3;
              title = "Database Layer Status";
              type = "stat";
              targets = [
                {
                  expr = "pg_up";
                  refId = "A";
                  legendFormat = "PostgreSQL";
                }
                {
                  expr = "redis_up";
                  refId = "B";
                  legendFormat = "Redis";
                }
                {
                  expr = "mongodb_up";
                  refId = "C";
                  legendFormat = "MongoDB";
                }
              ];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 8; w = 8; x = 0; y = 6; };
            }
            {
              id = 4;
              title = "Web Layer Status";
              type = "stat";
              targets = [
                {
                  expr = "nginx_up";
                  refId = "A";
                  legendFormat = "Nginx";
                }
              ];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 8; w = 8; x = 8; y = 6; };
            }
            {
              id = 5;
              title = "Monitoring Layer Status";
              type = "stat";
              targets = [
                {
                  expr = "prometheus_ready";
                  refId = "A";
                  legendFormat = "Prometheus";
                }
                {
                  expr = "up{job=\"grafana\"}";
                  refId = "B";
                  legendFormat = "Grafana";
                }
                {
                  expr = "up{job=\"loki\"}";
                  refId = "C";
                  legendFormat = "Loki";
                }
              ];
              fieldConfig = {
                defaults = {
                  mappings = [
                    { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
                    { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
                  ];
                };
              };
              gridPos = { h = 8; w = 8; x = 16; y = 6; };
            }
            {
              id = 6;
              title = "Service Dependencies Flow";
              type = "text";
              gridPos = { h = 12; w = 24; x = 0; y = 14; };
              options = {
                mode = "html";
                content = ''
<div style="text-align: center; font-family: Arial, sans-serif;">
  <h3>Service Architecture & Dependencies</h3>
  <div style="display: flex; justify-content: center; align-items: center; gap: 30px; margin: 20px 0;">
    
    <!-- User Traffic -->
    <div style="text-align: center;">
      <div style="background: #f0f0f0; padding: 10px; border-radius: 5px; border: 2px solid #333;">
        <strong>User Traffic</strong>
      </div>
      <div style="margin: 10px 0; font-size: 20px;">↓</div>
    </div>
    
    <!-- Web Layer -->
    <div style="text-align: center;">
      <div style="background: #e6f3ff; padding: 10px; border-radius: 5px; border: 2px solid #0066cc;">
        <strong>Nginx</strong><br>
        <small>Load Balancer & Reverse Proxy</small>
      </div>
      <div style="margin: 10px 0; font-size: 20px;">↓</div>
    </div>
    
    <!-- Application Layer -->
    <div style="text-align: center;">
      <div style="background: #fff2e6; padding: 10px; border-radius: 5px; border: 2px solid #ff8c00;">
        <strong>Application Servers</strong><br>
        <small>Backend Services</small>
      </div>
      <div style="margin: 10px 0; font-size: 20px;">↓</div>
    </div>
    
  </div>
  
  <!-- Database Layer -->
  <div style="display: flex; justify-content: center; gap: 20px; margin: 20px 0;">
    <div style="text-align: center;">
      <div style="background: #e6ffe6; padding: 10px; border-radius: 5px; border: 2px solid #00cc00;">
        <strong>PostgreSQL</strong><br>
        <small>Primary Database</small>
      </div>
    </div>
    <div style="text-align: center;">
      <div style="background: #ffe6e6; padding: 10px; border-radius: 5px; border: 2px solid #cc0000;">
        <strong>Redis</strong><br>
        <small>Cache & Sessions</small>
      </div>
    </div>
    <div style="text-align: center;">
      <div style="background: #f0e6ff; padding: 10px; border-radius: 5px; border: 2px solid #9900cc;">
        <strong>MongoDB</strong><br>
        <small>Document Store</small>
      </div>
    </div>
  </div>
  
  <!-- Monitoring Layer -->
  <div style="margin-top: 30px; padding-top: 20px; border-top: 2px dashed #ccc;">
    <h4>Monitoring & Observability</h4>
    <div style="display: flex; justify-content: center; gap: 20px;">
      <div style="text-align: center;">
        <div style="background: #fff5e6; padding: 10px; border-radius: 5px; border: 2px solid #ffaa00;">
          <strong>Prometheus</strong><br>
          <small>Metrics Collection</small>
        </div>
      </div>
      <div style="text-align: center;">
        <div style="background: #e6f7ff; padding: 10px; border-radius: 5px; border: 2px solid #00aaff;">
          <strong>Grafana</strong><br>
          <small>Dashboards & Alerts</small>
        </div>
      </div>
      <div style="text-align: center;">
        <div style="background: #f5f5f5; padding: 10px; border-radius: 5px; border: 2px solid #666;">
          <strong>Loki</strong><br>
          <small>Log Aggregation</small>
        </div>
      </div>
    </div>
  </div>
  
  <div style="margin-top: 20px; font-size: 12px; color: #666;">
    <p><strong>Data Flow:</strong> Nginx → Application → Databases</p>
    <p><strong>Monitoring:</strong> All services expose metrics to Prometheus, logs to Loki</p>
  </div>
</div>
                '';
              };
            }
            {
              id = 7;
              title = "Service Response Times";
              type = "timeseries";
              targets = [
                {
                  expr = "nginx_http_request_duration_seconds{quantile=\"0.5\"}";
                  refId = "A";
                  legendFormat = "Nginx (p50)";
                }
                {
                  expr = "prometheus_http_request_duration_seconds{quantile=\"0.5\"}";
                  refId = "B";
                  legendFormat = "Prometheus (p50)";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "s";
                };
              };
              gridPos = { h = 8; w = 12; x = 0; y = 26; };
            }
            {
              id = 8;
              title = "Cross-Service Communication";
              type = "timeseries";
              targets = [
                {
                  expr = "rate(nginx_http_requests_total[5m])";
                  refId = "A";
                  legendFormat = "Nginx Requests/sec";
                }
                {
                  expr = "rate(postgres_connections_total[5m])";
                  refId = "B";
                  legendFormat = "PostgreSQL Connections/sec";
                }
                {
                  expr = "rate(redis_commands_processed_total[5m])";
                  refId = "C";
                  legendFormat = "Redis Commands/sec";
                }
              ];
              fieldConfig = {
                defaults = {
                  unit = "reqps";
                };
              };
              gridPos = { h = 8; w = 12; x = 12; y = 26; };
            }
          ];
          time = { from = "now-1h"; to = "now"; };
          refresh = "30s";
        };
      };
      
      # Backup Monitoring Dashboard
      "grafana/dashboards/backup-monitoring.json".text = builtins.readFile ./grafana-dashboards/backup-monitoring.json;
    };

    # Shell aliases for monitoring
    environment.shellAliases = {
      # Prometheus
      prom-check = lib.mkIf cfg.prometheus.enable "${pkgs.prometheus}/bin/promtool check config /etc/prometheus/prometheus.yml";
      prom-targets = lib.mkIf cfg.prometheus.enable "curl -s localhost:${toString cfg.prometheus.port}/api/v1/targets | jq";
      
      # Grafana
      grafana-cli = lib.mkIf cfg.grafana.enable "grafana-cli";
      
      # Loki
      loki-logs = lib.mkIf cfg.loki.enable "curl -G -s http://localhost:${toString cfg.loki.port}/loki/api/v1/query_range";
      
      # General monitoring
      metrics-status = "systemctl status prometheus grafana loki promtail | grep -E 'Active:|●'";
    };
  };
}