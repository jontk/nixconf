# Remote Development Module
# Provides comprehensive remote development capabilities including VS Code Server, SSH, and cloud IDE support

{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

with lib;

let
  cfg = config.modules.development.remoteDev;

  # VS Code Server setup script
  vscodeServerSetup = pkgs.writeShellScript "vscode-server-setup" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    VSCODE_SERVER_DIR="$HOME/.vscode-server"
    
    echo "Setting up VS Code Server environment..."
    
    # Create necessary directories
    mkdir -p "$VSCODE_SERVER_DIR/bin"
    mkdir -p "$VSCODE_SERVER_DIR/extensions"
    
    # Create wrapper script for nix-ld compatibility
    cat > "$VSCODE_SERVER_DIR/nix-support.sh" << 'EOF'
    # Auto-generated VS Code Server Nix support
    export NIX_LD=$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)
    export NIX_LD_LIBRARY_PATH="${lib.makeLibraryPath cfg.vscodeServer.libraries}:$NIX_LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
    export PATH="${lib.makeBinPath cfg.vscodeServer.binaries}:$PATH"
    EOF
    
    echo "VS Code Server environment configured!"
  '';

  # Remote development environment setup
  remoteEnvSetup = pkgs.writeShellScript "remote-env-setup" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    PROJECT="''${1:-default}"
    
    echo "Setting up remote development environment: $PROJECT"
    
    # Create project directory
    mkdir -p "$HOME/projects/$PROJECT"
    cd "$HOME/projects/$PROJECT"
    
    # Initialize git if needed
    if [[ ! -d .git ]]; then
      git init
      echo "# $PROJECT" > README.md
      git add README.md
      git commit -m "Initial commit"
    fi
    
    # Create development environment file
    cat > .envrc << 'EOF'
    # direnv configuration for remote development
    use nix
    
    # Project-specific environment variables
    export PROJECT_ROOT="$PWD"
    export DEVELOPMENT_MODE="remote"
    
    # Load VS Code Server support if available
    if [[ -f "$HOME/.vscode-server/nix-support.sh" ]]; then
      source "$HOME/.vscode-server/nix-support.sh"
    fi
    
    # Custom project setup
    ${cfg.projectSetup}
    EOF
    
    # Allow direnv
    direnv allow
    
    echo "Remote development environment ready!"
  '';

in

{
  options.modules.development.remoteDev = {
    enable = mkEnableOption "remote development capabilities";
    
    ssh = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SSH development support";
      };
      
      allowedUsers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Users allowed for SSH development";
      };
      
      forwardAgent = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SSH agent forwarding";
      };
      
      forwardX11 = mkOption {
        type = types.bool;
        default = false;
        description = "Enable X11 forwarding";
      };
      
      ports = mkOption {
        type = types.listOf types.int;
        default = [ 22 ];
        description = "SSH ports to listen on";
      };
    };
    
    vscodeServer = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable VS Code Server support";
      };
      
      libraries = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          openssl
          curl
          icu
          libsecret
          libunwind
          libuuid
        ];
        description = "Libraries for VS Code Server";
      };
      
      binaries = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          nodejs
          git
          curl
          wget
        ];
        description = "Binaries available to VS Code Server";
      };
      
      extensions = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "ms-python.python" "rust-lang.rust-analyzer" ];
        description = "VS Code extensions to pre-install";
      };
    };
    
    codeServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable code-server (VS Code in browser)";
      };
      
      port = mkOption {
        type = types.int;
        default = 8080;
        description = "Port for code-server";
      };
      
      auth = mkOption {
        type = types.enum [ "password" "none" ];
        default = "password";
        description = "Authentication method";
      };
      
      cert = mkOption {
        type = types.bool;
        default = false;
        description = "Enable TLS with self-signed certificate";
      };
    };
    
    cloudIDEs = {
      gitpod = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Gitpod configuration";
        };
      };
      
      codespaces = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable GitHub Codespaces configuration";
        };
      };
    };
    
    collaboration = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable collaboration tools";
      };
      
      tmux = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable tmux for terminal sharing";
        };
        
        shareScript = mkOption {
          type = types.bool;
          default = true;
          description = "Install terminal sharing scripts";
        };
      };
      
      tmate = mkOption {
        type = types.bool;
        default = true;
        description = "Enable tmate for instant terminal sharing";
      };
    };
    
    tools = {
      mosh = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Mosh (mobile shell)";
      };
      
      eternal-terminal = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Eternal Terminal";
      };
      
      asciinema = mkOption {
        type = types.bool;
        default = true;
        description = "Enable terminal recording";
      };
      
      gotty = mkOption {
        type = types.bool;
        default = false;
        description = "Enable GoTTY web terminal";
      };
    };
    
    projectSetup = mkOption {
      type = types.lines;
      default = "";
      description = "Custom project setup commands";
    };
  };

  config = mkIf cfg.enable ({
    # Remote development packages
    environment.systemPackages = with pkgs; [
      # SSH tools
      openssh
      autossh
      sshfs
      sshpass
      ssh-copy-id
      
      # VS Code Server support
      (mkIf cfg.vscodeServer.enable (pkgs.writeShellScriptBin "setup-vscode-server" ''
        exec ${vscodeServerSetup}
      ''))
      
      # Code server
      (mkIf cfg.codeServer.enable code-server)
      
      # Remote shells
      (mkIf cfg.tools.mosh mosh)
      (mkIf cfg.tools.eternal-terminal eternal-terminal)
      
      # Collaboration tools
      (mkIf cfg.collaboration.tmux.enable tmux)
      (mkIf cfg.collaboration.tmate tmate)
      (mkIf cfg.tools.asciinema asciinema)
      (mkIf cfg.tools.gotty gotty)
      
      # Development environment tools
      direnv
      nix-direnv
      lorri
      
      # File synchronization
      rsync
      rclone
      mutagen
      syncthing
      
      # Remote editing
      neovim
      emacs-nox
      micro
      
      # Terminal multiplexers
      screen
      byobu
      
      # Remote development setup script
      (pkgs.writeShellScriptBin "remote-dev-init" ''
        exec ${remoteEnvSetup} "$@"
      '')
      
      # Terminal sharing helper
      (mkIf cfg.collaboration.tmux.shareScript (pkgs.writeShellScriptBin "tmux-share" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        SESSION="''${1:-shared}"
        
        # Create or attach to tmux session
        if tmux has-session -t "$SESSION" 2>/dev/null; then
          echo "Attaching to existing session: $SESSION"
          tmux attach -t "$SESSION"
        else
          echo "Creating new shared session: $SESSION"
          tmux new-session -s "$SESSION" -d
          
          # Set up for collaboration
          tmux set-option -t "$SESSION" -g aggressive-resize off
          tmux set-window-option -t "$SESSION" -g aggressive-resize off
          
          echo "Session created. Others can join with:"
          echo "  tmux attach -t $SESSION -r  # read-only"
          echo "  tmux attach -t $SESSION     # read-write"
          
          tmux attach -t "$SESSION"
        fi
      ''))
      
      # Remote pair programming
      (pkgs.writeShellScriptBin "pair-session" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        ACTION="''${1:-start}"
        
        case "$ACTION" in
          start)
            # Start tmate session
            tmate -F new-session -d -s pair
            sleep 2
            
            # Get connection strings
            echo "=== SSH Connection ==="
            tmate display -p '#{tmate_ssh}'
            echo ""
            echo "=== Web Connection ==="
            tmate display -p '#{tmate_web}'
            echo ""
            echo "=== Read-only Web ==="
            tmate display -p '#{tmate_web_ro}'
            
            # Save to file
            tmate display -p '#{tmate_ssh}' > ~/.pair-session
            ;;
          stop)
            tmate kill-server
            rm -f ~/.pair-session
            echo "Pair session ended"
            ;;
          info)
            if [[ -f ~/.pair-session ]]; then
              echo "Current session:"
              cat ~/.pair-session
            else
              echo "No active pair session"
            fi
            ;;
          *)
            echo "Usage: pair-session [start|stop|info]"
            ;;
        esac
      '')
      
      # Cloud IDE configuration generators
      (mkIf cfg.cloudIDEs.gitpod.enable (pkgs.writeShellScriptBin "gitpod-init" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        if [[ -f .gitpod.yml ]]; then
          echo ".gitpod.yml already exists"
          exit 1
        fi
        
        cat > .gitpod.yml << 'EOF'
        # Gitpod configuration
        image:
          file: .gitpod.Dockerfile
        
        tasks:
          - name: Setup
            init: |
              # Install dependencies
              if [[ -f package.json ]]; then npm install; fi
              if [[ -f requirements.txt ]]; then pip install -r requirements.txt; fi
              if [[ -f go.mod ]]; then go mod download; fi
              if [[ -f Cargo.toml ]]; then cargo fetch; fi
            command: |
              # Start development server
              echo "Ready for development!"
        
        ports:
          - port: 3000
            onOpen: notify
          - port: 8080
            onOpen: open-preview
        
        vscode:
          extensions:
            - ms-python.python
            - golang.go
            - rust-lang.rust-analyzer
            - dbaeumer.vscode-eslint
        EOF
        
        cat > .gitpod.Dockerfile << 'EOF'
        FROM gitpod/workspace-full
        
        # Install additional tools
        RUN brew install \
            hyperfine \
            tokei \
            ripgrep \
            fd
        
        # Custom setup
        USER gitpod
        EOF
        
        echo "Gitpod configuration created!"
      ''))
      
      (mkIf cfg.cloudIDEs.codespaces.enable (pkgs.writeShellScriptBin "codespaces-init" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        mkdir -p .devcontainer
        
        cat > .devcontainer/devcontainer.json << 'EOF'
        {
          "name": "Development Environment",
          "image": "mcr.microsoft.com/devcontainers/universal:2",
          "features": {
            "ghcr.io/devcontainers/features/nix:1": {
              "version": "latest"
            }
          },
          "customizations": {
            "vscode": {
              "extensions": [
                "ms-python.python",
                "golang.go",
                "rust-lang.rust-analyzer",
                "ms-vscode.cpptools"
              ],
              "settings": {
                "terminal.integrated.defaultProfile.linux": "zsh",
                "editor.formatOnSave": true
              }
            }
          },
          "postCreateCommand": "nix-shell --run 'echo Environment ready!'",
          "remoteUser": "codespace"
        }
        EOF
        
        echo "GitHub Codespaces configuration created!"
      ''))
    ];
    
    # Environment variables
    environment.variables = {
      # VS Code Server support
      NIX_LD_LIBRARY_PATH = mkIf cfg.vscodeServer.enable (mkDefault (lib.makeLibraryPath cfg.vscodeServer.libraries));
      
      # SSH settings
      SSH_AUTH_SOCK = mkIf cfg.ssh.forwardAgent "$HOME/.ssh/agent";
    };
    
    # Shell aliases for remote development
    environment.shellAliases = {
      # SSH shortcuts
      ssh-tunnel = "ssh -N -L";
      ssh-reverse = "ssh -N -R";
      ssh-socks = "ssh -N -D";
      
      # Remote editing
      rvim = "vim scp://";
      remacs = "emacs /ssh:";
      
      # File transfer
      upload = "rsync -avzP";
      download = "rsync -avzP";
      
      # Session management
      tm = "tmux";
      tma = "tmux attach -t";
      tml = "tmux list-sessions";
      tms = "tmux-share";
      
      # Pair programming
      pair = "pair-session";
      
      # VS Code
      code-tunnel = "code tunnel";
      
      # Development environments
      dev-init = "remote-dev-init";
    };
    
  } // lib.optionalAttrs isNixOS {
    # SSH configuration
    services.openssh = mkIf cfg.ssh.enable {
      enable = true;
      settings = {
        PermitRootLogin = mkDefault "no";
        PasswordAuthentication = mkDefault false;
        X11Forwarding = cfg.ssh.forwardX11;
        GatewayPorts = "yes";
        StreamLocalBindUnlink = true;
      };

      ports = cfg.ssh.ports;

      extraConfig = ''
        # VS Code Server support
        AcceptEnv LANG LC_* NIX_*

        # Allow port forwarding
        AllowTcpForwarding yes
        AllowAgentForwarding ${if cfg.ssh.forwardAgent then "yes" else "no"}
        AllowStreamLocalForwarding yes

        # Client keep-alive
        ClientAliveInterval 60
        ClientAliveCountMax 10

        # Performance
        UseDNS no
        Compression yes
      '';
    };

    # Enable nix-ld for VS Code Server compatibility
    programs.nix-ld = mkIf cfg.vscodeServer.enable {
      enable = true;
      libraries = cfg.vscodeServer.libraries;
    };

    # Code-server service
    systemd.services.code-server = mkIf cfg.codeServer.enable {
      description = "VS Code Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = config.users.primaryUser.username or "jontk";
        ExecStart = ''
          ${pkgs.code-server}/bin/code-server \
            --bind-addr 0.0.0.0:${toString cfg.codeServer.port} \
            --auth ${cfg.codeServer.auth} \
            ${optionalString cfg.codeServer.cert "--cert"}
        '';
        Restart = "on-failure";
      };
    };

    # User configuration
    users.users = {
      "${config.users.primaryUser.username or "jontk"}" = {
        openssh.authorizedKeys.keys = cfg.ssh.allowedUsers;
      };
    };

    # Firewall rules
    networking.firewall = {
      allowedTCPPorts = cfg.ssh.ports
        ++ optional cfg.codeServer.enable cfg.codeServer.port
        ++ [ 8443 ]; # Common HTTPS alternative port
    };
  });
}