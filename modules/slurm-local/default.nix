{ config, lib, pkgs, ... }:

let
  cfg = config.services.slurm-local;
  slurmPackage = pkgs.callPackage ./slurm-package.nix {};
  mysqlPasswordLine = lib.optionalString (cfg.database.password != "") ''
    StoragePass=${cfg.database.password}
  '';

  slurmConf = ''
    # SLURM Local Dev Cluster Configuration
    ClusterName=${cfg.clusterName}
    SlurmctldHost=${cfg.controlMachine}

    # Authentication
    AuthType=auth/munge
    AuthAltTypes=auth/jwt
    AuthAltParameters=jwt_key=${cfg.stateDir}/jwt_hs256.key
    CryptoType=crypto/munge

    # Process tracking
    MpiDefault=none
    ProctrackType=proctrack/linuxproc
    ReturnToService=2

    # Paths
    SlurmctldPidFile=${cfg.stateDir}/slurmctld/slurmctld.pid
    SlurmctldPort=6817
    SlurmdPort=6818
    SlurmdSpoolDir=${cfg.stateDir}/%n/spool
    SlurmUser=slurm
    StateSaveLocation=${cfg.stateDir}/slurmctld
    SwitchType=switch/none
    TaskPlugin=task/none

    # Scheduling
    SchedulerType=sched/backfill
    SelectType=select/cons_tres
    SelectTypeParameters=CR_Core_Memory

    # Accounting via slurmdbd
    AccountingStorageType=accounting_storage/slurmdbd
    AccountingStorageHost=localhost
    AccountingStoragePort=6819
    AccountingStorageEnforce=associations,limits
    JobAcctGatherType=jobacct_gather/linux

    # Job completion
    JobCompType=jobcomp/none

    # Logging
    SlurmctldDebug=info
    SlurmdDebug=info
    SlurmctldLogFile=${cfg.logDir}/slurmctld.log
    SlurmdLogFile=${cfg.logDir}/slurmd-%n.log

    # GRES and TRES tracking
    GresTypes=gpu
    AccountingStorageTRES=gres/gpu

    # Node definitions - use loopback aliases for unique hostnames
    # Use Boards to avoid topology mismatch with hardware
    NodeName=node1 NodeHostname=node1 NodeAddr=127.0.0.1 Port=6818 CPUs=${toString cfg.cpusPerNode} Boards=1 SocketsPerBoard=1 CoresPerSocket=${toString cfg.cpusPerNode} ThreadsPerCore=1 RealMemory=${toString cfg.memoryPerNode} State=UNKNOWN
    NodeName=node2 NodeHostname=node2 NodeAddr=127.0.0.1 Port=6821 CPUs=${toString cfg.cpusPerNode} Boards=1 SocketsPerBoard=1 CoresPerSocket=${toString cfg.cpusPerNode} ThreadsPerCore=1 RealMemory=${toString cfg.memoryPerNode} Gres=gpu:${toString cfg.gpu.count} State=UNKNOWN

    # Partitions
    PartitionName=normal Nodes=node1 Default=YES MaxTime=INFINITE State=UP
    PartitionName=gpu Nodes=node2 MaxTime=INFINITE State=UP
    PartitionName=all Nodes=node1,node2 MaxTime=INFINITE State=UP
  '';

  gresConf = lib.optionalString cfg.gpu.enable ''
    NodeName=node2 Name=gpu File=${cfg.gpu.deviceFile} Count=${toString cfg.gpu.count}
  '';

  slurmdbdConf = ''
    # SLURM Database Daemon Configuration
    AuthType=auth/munge
    AuthAltTypes=auth/jwt
    AuthAltParameters=jwt_key=${cfg.stateDir}/jwt_hs256.key
    DbdHost=localhost
    DbdPort=6819
    SlurmUser=slurm
    DebugLevel=info
    LogFile=${cfg.logDir}/slurmdbd.log
    PidFile=${cfg.stateDir}/slurmdbd/slurmdbd.pid

    # Database connection
    StorageType=accounting_storage/mysql
    StorageHost=localhost
    StoragePort=3306
    StorageUser=slurm
    ${mysqlPasswordLine}
    StorageLoc=slurm_acct_db

    # Purge old data after 6 months
    PurgeEventAfter=6months
    PurgeJobAfter=6months
    PurgeStepAfter=6months
  '';

in
{
  options.services.slurm-local = with lib; {
    enable = mkEnableOption "local SLURM cluster for development/testing";

    clusterName = mkOption {
      type = types.str;
      default = "localdev";
      description = "SLURM cluster name";
    };

    controlMachine = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Hostname of the SLURM controller";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/slurm-local";
      description = "Base state directory for SLURM";
    };

    logDir = mkOption {
      type = types.str;
      default = "/var/log/slurm-local";
      description = "Log directory for SLURM daemons";
    };

    cpusPerNode = mkOption {
      type = types.int;
      default = 6;
      description = "Number of CPUs per virtual node";
    };

    memoryPerNode = mkOption {
      type = types.int;
      default = 30000;
      description = "Memory per virtual node in MB";
    };

    gpu = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose GPU via GRES on node2";
      };

      count = mkOption {
        type = types.int;
        default = 1;
        description = "Number of GPUs to expose";
      };

      deviceFile = mkOption {
        type = types.str;
        default = "/dev/nvidia0";
        description = "GPU device path";
      };
    };

    slurmrestd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable slurmrestd REST API daemon";
      };

      port = mkOption {
        type = types.port;
        default = 6820;
        description = "Port for slurmrestd to listen on";
      };
    };

    database = {
      password = mkOption {
        type = types.str;
        default = "slurm";
        description = ''
          Password for the slurm MariaDB account used by slurmdbd.
          Defaults to "slurm" because slurmdbd connects to MariaDB over
          TCP (StorageHost=localhost:3306) where unix_socket auth does
          not apply. Override if you manage the DB user out-of-band.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # Add SLURM and munge binaries to system PATH
    environment.systemPackages = [ slurmPackage pkgs.munge ];

    # Configuration files
    environment.etc."slurm/slurm.conf" = {
      text = slurmConf;
      mode = "0644";
    };

    environment.etc."slurm/gres.conf" = {
      text = gresConf;
      mode = "0644";
    };

    environment.etc."slurm/slurmdbd.conf" = {
      text = slurmdbdConf;
      mode = "0600";
      user = "slurm";
      group = "slurm";
    };

    # Users and groups
    users.users.slurm = {
      isSystemUser = true;
      group = "slurm";
      uid = 64030;
      home = cfg.stateDir;
    };
    users.groups.slurm.gid = 64030;

    # slurmrestd user (can't be root, SlurmUser, or in SlurmUser's group)
    users.users.slurmrestd = {
      isSystemUser = true;
      group = "slurmrestd";
    };
    users.groups.slurmrestd = {};

    # Munge user (don't use services.munge to avoid conflicts)
    users.users.munge = {
      isSystemUser = true;
      group = "munge";
    };
    users.groups.munge = {};

    # Directories
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 slurm slurm -"
      "d ${cfg.stateDir}/slurmctld 0755 slurm slurm -"
      "d ${cfg.stateDir}/slurmdbd 0755 slurm slurm -"
      "d ${cfg.stateDir}/node1 0755 root root -"
      "d ${cfg.stateDir}/node1/spool 0755 root root -"
      "d ${cfg.stateDir}/node2 0755 root root -"
      "d ${cfg.stateDir}/node2/spool 0755 root root -"
      "d ${cfg.logDir} 0755 slurm slurm -"
      "d /etc/munge 0700 munge munge -"
      "d /var/lib/munge 0711 munge munge -"
      "d /var/log/munge 0755 munge munge -"
      "d /run/munge 0755 munge munge -"
    ];

    # MariaDB for slurmdbd
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "slurm_acct_db" ];
      ensureUsers = [
        {
          name = "slurm";
          ensurePermissions = {
            "slurm_acct_db.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # ---- Systemd Services ----

    # JWT key generation (oneshot)
    systemd.services.slurm-local-jwt-keygen = {
      description = "Generate JWT key for SLURM REST API";
      wantedBy = [ "multi-user.target" ];
      before = [ "slurm-local-slurmctld.service" "slurm-local-slurmdbd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f ${cfg.stateDir}/jwt_hs256.key ]; then
          ${pkgs.coreutils}/bin/dd if=/dev/urandom bs=32 count=1 of=${cfg.stateDir}/jwt_hs256.key 2>/dev/null
          ${pkgs.coreutils}/bin/chown slurm:slurm ${cfg.stateDir}/jwt_hs256.key
          ${pkgs.coreutils}/bin/chmod 0640 ${cfg.stateDir}/jwt_hs256.key
          echo "Generated new JWT key"
        else
          echo "JWT key already exists"
        fi
        # Ensure slurmrestd user can read the key
        ${pkgs.acl}/bin/setfacl -m u:slurmrestd:r ${cfg.stateDir}/jwt_hs256.key 2>/dev/null || true
      '';
    };

    # Munge key generation (oneshot)
    systemd.services.slurm-local-munge-keygen = {
      description = "Generate munge key for SLURM local cluster";
      wantedBy = [ "multi-user.target" ];
      before = [ "slurm-local-munged.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f /etc/munge/munge.key ]; then
          ${pkgs.coreutils}/bin/dd if=/dev/urandom bs=1 count=1024 of=/etc/munge/munge.key 2>/dev/null
          ${pkgs.coreutils}/bin/chown munge:munge /etc/munge/munge.key
          ${pkgs.coreutils}/bin/chmod 0400 /etc/munge/munge.key
          echo "Generated new munge key"
        else
          echo "Munge key already exists"
        fi
      '';
    };

    # Munge daemon
    systemd.services.slurm-local-munged = {
      description = "MUNGE authentication service (SLURM local)";
      after = [ "slurm-local-munge-keygen.service" ];
      requires = [ "slurm-local-munge-keygen.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.munge}/bin/munged --force";
        User = "munge";
        Group = "munge";
        RuntimeDirectory = "munge";
        PIDFile = "/run/munge/munged.pid";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # slurmdbd
    systemd.services.slurm-local-slurmdbd = {
      description = "SLURM database daemon (local)";
      after = [ "slurm-local-munged.service" "slurm-local-jwt-keygen.service" "mysql.service" ];
      requires = [ "slurm-local-munged.service" "slurm-local-jwt-keygen.service" "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${slurmPackage}/sbin/slurmdbd -D";
        User = "slurm";
        Group = "slurm";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # slurmctld
    systemd.services.slurm-local-slurmctld = {
      description = "SLURM controller daemon (local)";
      after = [ "slurm-local-munged.service" "slurm-local-jwt-keygen.service" "slurm-local-slurmdbd.service" "network.target" ];
      requires = [ "slurm-local-munged.service" "slurm-local-jwt-keygen.service" "slurm-local-slurmdbd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${slurmPackage}/sbin/slurmctld -D";
        User = "slurm";
        Group = "slurm";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # slurmd - node1 (CPU)
    systemd.services.slurm-local-slurmd-node1 = {
      description = "SLURM compute daemon (node1 - CPU)";
      after = [ "slurm-local-slurmctld.service" ];
      requires = [ "slurm-local-munged.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${slurmPackage}/sbin/slurmd -D -N node1";
        Restart = "always";
        RestartSec = 5;
      };
    };

    # slurmd - node2 (GPU)
    systemd.services.slurm-local-slurmd-node2 = {
      description = "SLURM compute daemon (node2 - GPU)";
      after = [ "slurm-local-slurmctld.service" ];
      requires = [ "slurm-local-munged.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${slurmPackage}/sbin/slurmd -D -N node2";
        Restart = "always";
        RestartSec = 5;
        SupplementaryGroups = [ "video" "render" ];
      };
    };

    # slurmrestd
    systemd.services.slurm-local-slurmrestd = lib.mkIf cfg.slurmrestd.enable {
      description = "SLURM REST API daemon (local)";
      after = [ "slurm-local-slurmctld.service" ];
      requires = [ "slurm-local-munged.service" "slurm-local-slurmctld.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        SLURM_JWT = "daemon";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${slurmPackage}/sbin/slurmrestd -a rest_auth/jwt 0.0.0.0:${toString cfg.slurmrestd.port}";
        User = "slurmrestd";
        Group = "slurmrestd";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Cluster initialization (create account/user after slurmdbd is ready)
    systemd.services.slurm-local-setup = {
      description = "Initialize SLURM local cluster accounts";
      after = [ "slurm-local-slurmctld.service" "slurm-local-slurmdbd.service" ];
      requires = [ "slurm-local-slurmctld.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Wait for slurmctld to be responsive
        for i in $(seq 1 30); do
          if ${slurmPackage}/bin/sinfo >/dev/null 2>&1; then
            break
          fi
          echo "Waiting for slurmctld... ($i/30)"
          sleep 2
        done

        # Create default account and add root user
        ${slurmPackage}/bin/sacctmgr -i add account default Description="Default account" Organization="local" 2>/dev/null || true
        ${slurmPackage}/bin/sacctmgr -i add user root Account=default 2>/dev/null || true
        ${slurmPackage}/bin/sacctmgr -i add user ${config.users.users.jontk.name or "jontk"} Account=default 2>/dev/null || true
        ${slurmPackage}/bin/sacctmgr -i modify user ${config.users.users.jontk.name or "jontk"} set AdminLevel=Admin 2>/dev/null || true

        echo "SLURM local cluster initialized"
        ${slurmPackage}/bin/sinfo
      '';
    };

    # Host entries for virtual SLURM nodes
    networking.extraHosts = ''
      127.0.0.1 node1
      127.0.0.1 node2
    '';

    # Open slurmrestd port
    networking.firewall.allowedTCPPorts = lib.optional cfg.slurmrestd.enable cfg.slurmrestd.port;
  };
}
