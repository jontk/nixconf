{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
in
{
  # Development tools configuration
  environment.systemPackages = with pkgs; [
    # Terminal multiplexers and tools
    tmux
    tmuxp # tmux session manager
    screen
    zellij # Modern terminal multiplexer
    
    # Text processing
    ripgrep
    silver-searcher
    ack
    fzf
    fd
    sd # Find and replace
    choose # Cut alternative
    jless # JSON viewer
    
    # File watchers and monitors
    watchman
    entr # Run commands on file change
    fswatch
    
    # HTTP/API testing tools
    curl
    wget
    httpie
    xh # Friendly HTTP client
    curlie # Curl with httpie interface
    grpcurl
    websocat # WebSocket client
    
    # Benchmarking and profiling
    hyperfine
    wrk # HTTP benchmarking
    hey # HTTP load generator
    vegeta # HTTP load testing
    
    # Database clients and tools
    pgcli # PostgreSQL CLI with auto-completion
    mycli # MySQL CLI with auto-completion
    litecli # SQLite CLI with auto-completion
    redis-cli
    mongosh # MongoDB Shell
    usql # Universal SQL CLI
    
    # Container and orchestration tools
    podman
    buildah
    skopeo
    hadolint # Dockerfile linter
    container-diff
    cosign # Container signing
    
    # CI/CD tools
    act # Run GitHub Actions locally
    dagger # CI/CD engine
    earthly # Build tool
    
    # Documentation generators
    mdbook
    mkdocs
    sphinx
    asciidoctor
    hugo
    zola
    
    # Diagram and visualization tools
    graphviz
    plantuml
    mermaid-cli
    drawio-headless
    
    # Security tools
    trivy # Vulnerability scanner
    gitleaks # Secret scanner
    semgrep # Static analysis
    tfsec # Terraform security scanner
    
    # Code formatting and linting
    shfmt # Shell formatter
    shellcheck
    editorconfig-core-c
    yamllint
    jsonlint
    hadolint
    sqlfluff # SQL linter
    
    # Diff and merge tools
    difftastic # Structural diff
    delta # Git diff viewer
    diff-so-fancy
    icdiff # Improved colored diff
    
    # Log viewers and analyzers
    lnav # Log file navigator
    goaccess # Real-time web log analyzer
    angle-grinder # Log analysis
    
    # Process and system monitoring
    htop
    btop
    bottom
    glances
    ctop # Container metrics
    lazydocker
    
    # Network debugging
    tcpdump
    nmap
    netcat
    socat
    mtr
    iperf3
    bandwhich # Network utilization
    
    # File and directory tools
    tree
    broot # Interactive tree
    lsd # ls with icons
    exa # Modern ls
    zoxide # Smarter cd
    autojump
    
    # Archive and compression
    zip
    unzip
    p7zip
    pigz # Parallel gzip
    pbzip2 # Parallel bzip2
    zstd
    
    # Cloud CLI tools
    awscli2
    google-cloud-sdk
    azure-cli
    doctl # DigitalOcean
    linode-cli
    vultr-cli
    
    # Infrastructure as Code
    terraform
    terragrunt
    pulumi
    ansible
    ansible-lint
    
    # Kubernetes tools
    kubectl
    k9s
    helm
    helmfile
    kustomize
    kubeseal
    kubeval
    stern
    kubectl-tree
    kubectl-neat
    
    # Development utilities
    direnv
    lorri # Nix shell helper
    devbox # Development environments
    mise # Runtime executor (asdf rust clone)
    
    # macOS specific tools
  ] ++ lib.optionals isDarwin [
    m-cli # macOS command line tools
    duti # Default app associations
    trash # Move files to trash
    
  ] ++ lib.optionals isNixOS [
    # Linux specific tools
    inotify-tools
    sysstat
    dstat
  ];
  
  # Tool-specific configurations
  programs = {
    # Tmux configuration is handled in home-manager
    
    # Enable direnv
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    
    # Git configuration
    git = {
      enable = true;
      lfs.enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        merge.tool = "vimdiff";
        diff.tool = "vimdiff";
        core = {
          editor = "vim";
          pager = "${pkgs.delta}/bin/delta";
        };
        delta = {
          enable = true;
          navigate = true;
          line-numbers = true;
          syntax-theme = "Monokai Extended";
        };
      };
    };
  };
  
  # Tool-specific environment variables
  environment.variables = {
    # FZF configuration
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
    FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --inline-info";
    FZF_CTRL_T_COMMAND = "$FZF_DEFAULT_COMMAND";
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
    
    # Ripgrep configuration
    RIPGREP_CONFIG_PATH = "$HOME/.config/ripgrep/config";
    
    # Less configuration
    LESS = "-FRX";
    LESSHISTFILE = "-";
    
    # Man pager with syntax highlighting
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };
  
  # Tool-specific aliases
  environment.shellAliases = {
    # Modern replacements
    cat = "bat";
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    tree = "eza --tree";
    find = "fd";
    grep = "rg";
    sed = "sd";
    ps = "procs";
    du = "dust";
    df = "duf";
    top = "btop";
    
    # Git helpers
    gst = "git status";
    gco = "git checkout";
    gcm = "git commit -m";
    gaa = "git add --all";
    gp = "git push";
    gpl = "git pull";
    glog = "git log --oneline --graph --decorate";
    gdiff = "git diff";
    
    # Docker helpers
    dps = "docker ps";
    dpsa = "docker ps -a";
    di = "docker images";
    drm = "docker rm";
    drmi = "docker rmi";
    dex = "docker exec -it";
    dlog = "docker logs -f";
    dprune = "docker system prune -a";
    
    # Kubernetes helpers
    k = "kubectl";
    kgp = "kubectl get pods";
    kgs = "kubectl get svc";
    kgd = "kubectl get deployment";
    kgi = "kubectl get ingress";
    kaf = "kubectl apply -f";
    kdel = "kubectl delete";
    klog = "kubectl logs -f";
    kexec = "kubectl exec -it";
    kctx = "kubectx";
    kns = "kubens";
    
    # Terraform helpers
    tf = "terraform";
    tfi = "terraform init";
    tfp = "terraform plan";
    tfa = "terraform apply";
    tfd = "terraform destroy";
    tfv = "terraform validate";
    tff = "terraform fmt";
    
    # Quick servers
    serve = "python3 -m http.server";
    serve-php = "php -S localhost:8000";
    serve-ruby = "ruby -run -e httpd . -p 8000";
    
    # JSON/YAML tools
    json = "jq '.'";
    yaml = "yq eval '.'";
    
    # Network tools
    ports = "netstat -tulanp";
    listening = "lsof -P -i -n";
    myip = "curl -s https://ifconfig.me";
    
    # System info
    sysinfo = "neofetch";
    diskspace = "ncdu";
    
    # Quick edits
    zshrc = "$EDITOR ~/.zshrc";
    vimrc = "$EDITOR ~/.vimrc";
    tmuxconf = "$EDITOR ~/.tmux.conf";
  };
  
  # macOS specific tool configurations
  system = lib.mkIf isDarwin {
    defaults.CustomUserPreferences = {
      # Terminal app preferences for development tools
      "com.googlecode.iterm2" = {
        LoadPrefsFromCustomFolder = true;
        PrefsCustomFolder = "~/.config/iterm2";
        NoSyncNeverRemindPrefsChangesLostForFile = true;
      };
      
      # Dash documentation browser
      "com.kapeli.dashdoc" = {
        shouldSyncBookmarks = true;
        shouldSyncDocsets = true;
        syncFolderPath = "~/Library/Mobile Documents/com~apple~CloudDocs/Dash";
      };
    };
  };
  
  # Homebrew tool installations (macOS only)
  homebrew = lib.mkIf isDarwin {
    brews = [
      # Additional CLI tools not in nixpkgs
      "gh" # GitHub CLI
      "glab" # GitLab CLI
      "hub" # Another GitHub CLI
      "tig" # Text-mode interface for git
      "lazygit" # Terminal UI for git
      "gitui" # Terminal UI for git (Rust)
      
      # macOS specific utilities
      "coreutils"
      "findutils"
      "gnu-sed"
      "gnu-tar"
      "gawk"
      "gnutls"
      "gnu-indent"
      "gnu-getopt"
      
      # Development tools
      "commitizen" # Conventional commits
      "pre-commit" # Git hooks
      "git-flow-avh" # Git flow
      "git-lfs" # Large file storage
      
      # Container tools
      "colima" # Container runtime for macOS
      "lima" # Linux VMs for macOS
      
      # Additional monitoring tools
      "glances" # System monitoring
      "duf" # Disk usage
      "dust" # Disk usage
      "procs" # Process viewer
      "bottom" # System monitor
      
      # Security tools
      "sops" # Secrets management
      "age" # Encryption tool
    ];
    
    casks = [
      # GUI development tools
      "iterm2"
      "kitty"
      "alacritty"
      "warp" # AI-powered terminal
      
      # API testing
      "postman"
      "insomnia"
      "paw"
      "httpie"
      
      # Database tools
      "tableplus"
      "dbeaver-community"
      "sequel-ace"
      "mongodb-compass"
      "redis-insight"
      
      # Container management
      "docker"
      "lens"
      "portainer"
      
      # Network analysis
      "wireshark"
      "charles"
      "proxyman"
      "ngrok"
      
      # Documentation
      "dash"
      "devdocs"
      
      # Diff tools
      "beyond-compare"
      "kaleidoscope"
      "meld"
      
      # Git GUIs
      "sourcetree"
      "tower"
      "fork"
      "sublime-merge"
      "github"
      
      # System monitoring
      "stats" # Menu bar system monitor
      "istat-menus"
      
      # Productivity
      "raycast" # Launcher with dev tools
      "fig" # Terminal autocomplete
    ];
  };
}