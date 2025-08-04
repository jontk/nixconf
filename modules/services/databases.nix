# Database Services Configuration
{ config, lib, pkgs, ... }:

let
  cfg = config.nixconf.services.databases;
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
in
{
  options.nixconf.services.databases = with lib; {
    enable = mkEnableOption "database services" // { default = false; };
    
    postgresql = {
      enable = mkEnableOption "PostgreSQL database server" // { default = true; };
      
      version = mkOption {
        type = types.package;
        default = pkgs.postgresql_16;
        description = "PostgreSQL package to use";
      };
      
      port = mkOption {
        type = types.port;
        default = 5432;
        description = "Port for PostgreSQL to listen on";
      };
      
      databases = mkOption {
        type = types.listOf types.str;
        default = [ "development" "test" ];
        description = "Databases to create automatically";
      };
      
      authentication = mkOption {
        type = types.str;
        default = ''
          # TYPE  DATABASE        USER            ADDRESS                 METHOD
          local   all             postgres                                peer
          local   all             all                                     trust
          host    all             all             127.0.0.1/32            trust
          host    all             all             ::1/128                 trust
        '';
        description = "PostgreSQL authentication configuration";
      };
      
      extensions = mkOption {
        type = types.listOf types.package;
        default = with pkgs.postgresql16Packages; [
          postgis
          pg_cron
          timescaledb
        ];
        description = "PostgreSQL extensions to install";
      };
    };
    
    redis = {
      enable = mkEnableOption "Redis in-memory data store" // { default = true; };
      
      port = mkOption {
        type = types.port;
        default = 6379;
        description = "Port for Redis to listen on";
      };
      
      maxMemory = mkOption {
        type = types.str;
        default = "256mb";
        description = "Maximum memory Redis can use";
      };
      
      persistence = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Redis persistence";
      };
    };
    
    mysql = {
      enable = mkEnableOption "MySQL/MariaDB database server" // { default = false; };
      
      package = mkOption {
        type = types.package;
        default = pkgs.mariadb;
        description = "MySQL/MariaDB package to use";
      };
      
      port = mkOption {
        type = types.port;
        default = 3306;
        description = "Port for MySQL to listen on";
      };
    };
    
    mongodb = {
      enable = mkEnableOption "MongoDB NoSQL database" // { default = false; };
      
      port = mkOption {
        type = types.port;
        default = 27017;
        description = "Port for MongoDB to listen on";
      };
    };
  };
  
  config = lib.mkIf (cfg.enable && isNixOS) {
    # PostgreSQL configuration
    services.postgresql = lib.mkIf cfg.postgresql.enable {
      enable = true;
      package = cfg.postgresql.version;
      authentication = lib.mkForce cfg.postgresql.authentication;
      
      ensureDatabases = cfg.postgresql.databases ++ [ config.users.users.jontk.name ];
      ensureUsers = [
        {
          name = config.users.users.jontk.name;
          ensureDBOwnership = true;
        }
      ];
      
      settings = {
        # Port configuration
        port = cfg.postgresql.port;
        
        # Performance tuning
        shared_buffers = "256MB";
        effective_cache_size = "1GB";
        maintenance_work_mem = "64MB";
        checkpoint_completion_target = 0.9;
        wal_buffers = "16MB";
        default_statistics_target = 100;
        random_page_cost = 1.1;
        effective_io_concurrency = 200;
        work_mem = "4MB";
        min_wal_size = "1GB";
        max_wal_size = "4GB";
        
        # Logging
        log_statement = "all";
        log_duration = true;
        log_line_prefix = "%m [%p] %u@%d ";
        log_timezone = "UTC";
      };
      
      extensions = cfg.postgresql.extensions;
    };
    
    # Redis configuration
    services.redis = lib.mkIf cfg.redis.enable {
      servers.main = {
        enable = true;
        port = cfg.redis.port;
        
        settings = {
          maxmemory = cfg.redis.maxMemory;
          maxmemory-policy = "allkeys-lru";
          
          # Persistence settings
          save = lib.mkIf cfg.redis.persistence [
            "900 1"    # after 900 sec (15 min) if at least 1 key changed
            "300 10"   # after 300 sec (5 min) if at least 10 keys changed
            "60 10000" # after 60 sec if at least 10000 keys changed
          ];
          
          # Security
          protected-mode = "yes";
          
          # Performance
          tcp-backlog = 511;
          timeout = 0;
          tcp-keepalive = 300;
        };
      };
    };
    
    # MySQL/MariaDB configuration
    services.mysql = lib.mkIf cfg.mysql.enable {
      enable = true;
      package = cfg.mysql.package;
      settings = {
        mysqld = {
          port = cfg.mysql.port;
          bind-address = "127.0.0.1";
          
          # InnoDB settings
          innodb_buffer_pool_size = "256M";
          innodb_log_file_size = "64M";
          innodb_flush_log_at_trx_commit = 2;
          innodb_flush_method = "O_DIRECT";
          
          # Query cache
          query_cache_type = 1;
          query_cache_size = "16M";
          
          # Connection settings
          max_connections = 100;
          thread_cache_size = 8;
        };
      };
    };
    
    # MongoDB configuration
    services.mongodb = lib.mkIf cfg.mongodb.enable {
      enable = true;
      bind_ip = "127.0.0.1";
      
      extraConfig = ''
        storage:
          journal:
            enabled: true
        
        net:
          port: ${toString cfg.mongodb.port}
          bindIpAll: false
          
        security:
          authorization: disabled
      '';
    };
    
    # Firewall rules for databases (only for local development)
    networking.firewall = {
      allowedTCPPorts = lib.optional cfg.postgresql.enable cfg.postgresql.port
        ++ lib.optional cfg.redis.enable cfg.redis.port
        ++ lib.optional cfg.mysql.enable cfg.mysql.port
        ++ lib.optional cfg.mongodb.enable cfg.mongodb.port;
    };
    
    # System packages for database clients
    environment.systemPackages = with pkgs; 
      lib.optionals cfg.postgresql.enable [
        cfg.postgresql.version
        pgcli  # Better PostgreSQL CLI
        dbeaver-bin  # Universal database tool
      ] ++ lib.optionals cfg.redis.enable [
        redis
      ] ++ lib.optionals cfg.mysql.enable [
        cfg.mysql.package
        mycli  # Better MySQL CLI
      ] ++ lib.optionals cfg.mongodb.enable [
        mongosh  # MongoDB Shell
        mongodb-compass  # MongoDB GUI
      ];
    
    # Shell aliases for database access
    environment.shellAliases = {
      # PostgreSQL
      pgstart = lib.mkIf cfg.postgresql.enable "sudo systemctl start postgresql";
      pgstop = lib.mkIf cfg.postgresql.enable "sudo systemctl stop postgresql";
      pgstatus = lib.mkIf cfg.postgresql.enable "sudo systemctl status postgresql";
      pgconsole = lib.mkIf cfg.postgresql.enable "sudo -u postgres psql";
      
      # Redis
      redis-start = lib.mkIf cfg.redis.enable "sudo systemctl start redis-main";
      redis-stop = lib.mkIf cfg.redis.enable "sudo systemctl stop redis-main";
      redis-cli = lib.mkIf cfg.redis.enable "redis-cli -p ${toString cfg.redis.port}";
      
      # MySQL
      mysql-start = lib.mkIf cfg.mysql.enable "sudo systemctl start mysql";
      mysql-stop = lib.mkIf cfg.mysql.enable "sudo systemctl stop mysql";
      mysql-console = lib.mkIf cfg.mysql.enable "sudo mysql -u root";
      
      # MongoDB
      mongo-start = lib.mkIf cfg.mongodb.enable "sudo systemctl start mongodb";
      mongo-stop = lib.mkIf cfg.mongodb.enable "sudo systemctl stop mongodb";
    };
  };
}