{ config, pkgs, lib, inputs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

let
  cfg = config.nixconf.features;
in
{
  # Implementation of feature flags - this module applies the actual configurations
  # based on the feature flags defined in feature-flags.nix
  
  config = {
    # Consolidated system packages based on feature flags
    environment.systemPackages = with pkgs; (lib.optionals cfg.development.enable [
      # Essential development tools
      git
      gh
      lazygit
      
      # Build tools
      gnumake
      cmake
      pkg-config
      
      # Text editors and IDEs
      neovim
      emacs30
      
      # Development utilities
      direnv
      nix-direnv
      
      # Debugging and profiling (cross-platform)
      lldb
    ] ++ lib.optionals cfg.development.rust [
      # Rust toolchain via rust-overlay
      (rust-bin.stable.latest.default.override {
        extensions = [ "rust-src" "cargo" "rustc" ];
        targets = [ "wasm32-unknown-unknown" ];
      })
      rust-analyzer
      cargo-watch
      cargo-edit
      cargo-audit
      cargo-outdated
    ] ++ lib.optionals cfg.development.python [
      python3
      python3Packages.pip
      python3Packages.virtualenv
      python3Packages.poetry
      python3Packages.black
      python3Packages.isort
      python3Packages.flake8
      python3Packages.mypy
      python3Packages.pytest
      python3Packages.pylsp
    ] ++ lib.optionals cfg.development.nodejs [
      nodejs
      yarn
      pnpm
    ] ++ lib.optionals cfg.development.go [
      go
      gopls
      golangci-lint
      delve
      go-tools
    ] ++ lib.optionals cfg.development.java [
      openjdk17
      maven
      gradle
      visualvm
    ] ++ lib.optionals cfg.development.cpp [
      gcc
      clang
      lldb
      cmake
      ninja
      ccls
      cppcheck
    ] ++ lib.optionals cfg.development.docker [
      docker
      docker-compose
      dive
      lazydocker
    ] ++ lib.optionals cfg.development.kubernetes [
      kubectl
      kubectx
      k9s
      helm
      kustomize
      stern
    ]) ++ (lib.optionals cfg.security.yubikey (with pkgs; [
      # YubiKey packages
      yubikey-manager
      yubikey-personalization
      yubikey-personalization-gui
      yubico-piv-tool
      yubioath-flutter
    ])) ++ (lib.optionals cfg.desktop.office (with pkgs; [
      # Office applications
      libreoffice-fresh
      thunderbird
      firefox
      chromium
      obsidian
      zotero
    ])) ++ (lib.optionals cfg.desktop.multimedia (with pkgs; [
      # Multimedia applications
      vlc
      mpv
      ffmpeg
      gimp
      inkscape
      audacity
      obs-studio
      kdenlive
      imagemagick
      feh
    ])) ++ (lib.optionals cfg.backup.enable (with pkgs; [
      # Backup and sync tools
      rsync
      rclone
      restic
      borgbackup
    ] ++ lib.optionals cfg.backup.nextcloud [
      nextcloud-client
    ]));

    # macOS-specific feature implementations - disabled temporarily
} // lib.optionalAttrs isNixOS {
    # Docker configuration
    virtualisation.docker = lib.mkIf cfg.development.docker {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Podman as Docker alternative
    virtualisation.podman = lib.mkIf cfg.virtualization.podman {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # KVM/libvirt virtualization
    virtualisation.libvirtd = lib.mkIf cfg.virtualization.libvirt {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };

    # VirtualBox support
    virtualisation.virtualbox.host = lib.mkIf cfg.virtualization.virtualbox {
      enable = true;
      enableExtensionPack = true;
    };

    # Network services
    services = {
      # SSH configuration
      openssh = lib.mkIf cfg.remote.ssh {
        enable = true;
        ports = [ 22 ];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          X11Forwarding = false;
          MaxAuthTries = 3;
        };
        openFirewall = true;
      };

      # Tailscale mesh VPN
      tailscale = lib.mkIf cfg.network.tailscale {
        enable = true;
        useRoutingFeatures = "client";
      };

      # Syncthing file synchronization
      syncthing = lib.mkIf cfg.backup.syncthing {
        enable = true;
        user = "jontk";
        dataDir = "/home/jontk/Sync";
        configDir = "/home/jontk/.config/syncthing";
        openDefaultPorts = true;
      };

      # ZeroTier networking
      zerotierone = lib.mkIf cfg.network.zerotier {
        enable = true;
      };

      # Web server capabilities
      nginx = lib.mkIf cfg.server.web {
        enable = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        recommendedProxySettings = true;
      };

      # Database services
      postgresql = lib.mkIf cfg.server.database {
        enable = true;
        package = pkgs.postgresql_15;
        enableTCPIP = true;
        authentication = pkgs.lib.mkOverride 10 ''
          local all all trust
          host all all 127.0.0.1/32 trust
          host all all ::1/128 trust
        '';
        initialScript = pkgs.writeText "backend-initScript" ''
          CREATE ROLE jontk WITH LOGIN PASSWORD 'jontk' CREATEDB;
          CREATE DATABASE jontk;
          GRANT ALL PRIVILEGES ON DATABASE jontk TO jontk;
        '';
      };

      redis.servers."" = lib.mkIf cfg.server.database {
        enable = true;
        port = 6379;
        bind = "127.0.0.1";
      };

      # Monitoring and logging
      prometheus = lib.mkIf cfg.server.monitoring {
        enable = true;
        port = 9090;
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
            port = 9100;
          };
        };
        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [{
              targets = [ "localhost:9100" ];
            }];
          }
        ];
      };

      grafana = lib.mkIf cfg.server.monitoring {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = 3000;
          };
        };
      };

      # YubiKey support
      pcscd = lib.mkIf cfg.security.yubikey {
        enable = true;
      };

      udev.packages = lib.mkIf cfg.security.yubikey [
        pkgs.yubikey-personalization
      ];

      # Tor anonymity network
      tor = lib.mkIf cfg.security.tor {
        enable = true;
        client.enable = true;
        settings = {
          UseBridges = true;
          ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy";
        };
      };
    };

    # Kernel hardening via boot.kernel.sysctl
    boot.kernel.sysctl = lib.mkIf cfg.security.hardening {
      # Network security
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

      # Memory protection
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.yama.ptrace_scope" = 1;

      # File system security
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
    };

    # Security hardening
    security = lib.mkIf cfg.security.hardening {
      # AppArmor
      apparmor = {
        enable = true;
        killUnconfinedConfinables = true;
      };

      # Audit framework
      auditd.enable = true;
      audit.enable = true;
      audit.rules = [
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/group -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        "-w /etc/sudoers -p wa -k identity"
      ];
    };

    # WireGuard VPN
    networking.wireguard = lib.mkIf cfg.network.wireguard {
      enable = true;
    };

    # Gaming support and development tools (NixOS only)
    programs = lib.mkMerge [
      (lib.mkIf cfg.desktop.gaming {
        steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
        };

        gamemode.enable = true;
      })
      (lib.mkIf cfg.development.enable {
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      })
    ];

    hardware = lib.mkIf cfg.desktop.gaming {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };
    };

} // lib.optionalAttrs false {
  homebrew = {
      enable = true;
      brews = lib.optionals cfg.development.docker [
        "docker"
        "docker-compose"
      ] ++ lib.optionals cfg.development.kubernetes [
        "kubectl"
        "helm"
      ];
      
      casks = [
        "docker"
      ] ++ lib.optionals cfg.desktop.office [
        "libreoffice"
        "thunderbird"
      ] ++ lib.optionals cfg.desktop.multimedia [
        "vlc"
        "gimp"
      ];
    };
  };
}