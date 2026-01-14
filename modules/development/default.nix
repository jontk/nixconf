{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isNixOS = !isDarwin;
in
{
  imports = [
    ./languages.nix
    ./tools.nix
    ./containers.nix
    ./code-quality.nix
    ./profiling.nix
    ./remote-dev.nix
  ];

  # Development environment configuration
  environment.systemPackages = with pkgs; [
    # Version Control
    git
    git-lfs
    gitAndTools.gitflow
    gitAndTools.git-extras
    gitAndTools.diff-so-fancy
    gitAndTools.git-crypt
    gitAndTools.git-secrets
    mercurial
    subversion
    
    # Code Editors and IDEs
    vim
    neovim
    emacs30
    
    # Build Tools
    gnumake
    cmake
    ninja
    meson
    bazel
    
    # Container Tools
    docker-compose
    docker-credential-helpers
    dive # Docker image explorer
    lazydocker # Docker TUI
    
    # Kubernetes Tools
    kubectl
    kubernetes-helm
    k9s # Kubernetes TUI
    stern # Multi-pod log tailing
    kubectx # Context switching
    kubeseal # Sealed secrets
    
    # Cloud Tools
    awscli2
    google-cloud-sdk
    azure-cli
    terraform
    terragrunt
    packer
    vault
    
    # API Development
    httpie
    curl
    wget
    jq
    yq-go
    grpcurl
    # postman # May pull in dotnet-sdk-6.0
    insomnia
    
    # Database Tools
    postgresql_15
    mysql80
    redis
    sqlite
    dbeaver-bin
    
    # Documentation
    pandoc
    graphviz
    plantuml
    mermaid-cli
    
    # Code Quality
    pre-commit
    shellcheck
    hadolint # Dockerfile linter
    yamllint
    actionlint # GitHub Actions linter
    
    # Performance Analysis
    hyperfine # Command-line benchmarking
    tokei # Code statistics
    cloc # Count lines of code
    
    # Network Tools
    wireshark
    tcpdump
    nmap
    netcat
    mtr
    iperf3
    
    # Debugging Tools
    gdb
    lldb
    valgrind
    strace
    
    # macOS specific development tools
  ] ++ lib.optionals isDarwin [
    xcodes # Manage multiple Xcode versions
    cocoapods
    carthage
    swiftformat
    swiftlint
  ] ++ lib.optionals isNixOS [
    # Linux specific tools
    perf-tools
    bpftools
  ];
  
  # Development environment variables
  environment.variables = {
    EDITOR = lib.mkDefault "vim";
    VISUAL = lib.mkDefault "vim";
    PAGER = lib.mkDefault "less";
    
    # Development paths
    GOPATH = "$HOME/go";
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    
    # Tool configurations
    DOCKER_BUILDKIT = "1";
    COMPOSE_DOCKER_CLI_BUILD = "1";
    
    # Git configuration
    GIT_EDITOR = "vim";
  } // lib.optionalAttrs isDarwin {
    # macOS specific environment variables
    HOMEBREW_NO_AUTO_UPDATE = "1";
    HOMEBREW_NO_INSTALL_CLEANUP = "1";
  };
  
  # Shell aliases for development
  environment.shellAliases = {
    # Git shortcuts
    g = "git";
    gs = "git status";
    gd = "git diff";
    gds = "git diff --staged";
    gc = "git commit";
    gca = "git commit -a";
    gp = "git push";
    gl = "git pull";

    # Docker shortcuts are handled by dotfiles docker module
    # to avoid conflicts and use modern 'docker compose' command

    # Kubernetes shortcuts
    k = "kubectl";
    kgp = "kubectl get pods";
    kgs = "kubectl get svc";
    kgd = "kubectl get deployment";
    kaf = "kubectl apply -f";
    kdel = "kubectl delete";
    klog = "kubectl logs -f";
    
    # Development shortcuts
    serve = "python3 -m http.server";
    yaml = "yq";
    
    # Code navigation
    ff = "find . -type f -name";
    fd = "find . -type d -name";
    
    # macOS specific aliases
  } // lib.optionalAttrs isDarwin {
    # Xcode
    xc = "open *.xcodeproj";
    xcw = "open *.xcworkspace";
    
    # Simulator
    sim = "open -a Simulator";
    
    # Clear derived data
    xcclean = "rm -rf ~/Library/Developer/Xcode/DerivedData";
  };
  
  # Programs configuration
  programs = lib.mkMerge [
    {
      # Enable adb for Android development
      adb.enable = true;
      
      # Enable mtr with GUI support
      mtr.enable = true;
      
      # Enable wireshark
      wireshark = {
        enable = true;
        package = pkgs.wireshark;
      };
    }
    
    # NixOS specific programs
    (lib.mkIf isNixOS {
      # Enable nix-ld for running unpatched dynamic binaries (e.g., VSCode Server)
      nix-ld = {
        enable = true;
        libraries = with pkgs; [
          # Common libraries needed by VSCode Server and other binaries
          stdenv.cc.cc.lib
          zlib
          fuse3
          icu
          nss
          openssl
          curl
          expat
          # X11 libraries that might be needed
          xorg.libX11
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXi
          xorg.libXrandr
          xorg.libXrender
          xorg.libXtst
          xorg.libxcb
          xorg.libxkbfile
          # Additional libraries
          glib
          gtk3
          libnotify
          libsecret
          libuuid
          libgcc
          libglvnd
          libbsd
          libmd
        ];
      };
    })
  ];
  
  # Services configuration
  services = lib.mkMerge [
    {
      # PostgreSQL for development
      # Disabled - now configured via nixconf.services.databases
      # postgresql = {
      #   enable = true;
      #   package = pkgs.postgresql_15;
      #   enableTCPIP = true;
      #   authentication = pkgs.lib.mkOverride 10 ''
      #     local all all trust
      #     host all all 127.0.0.1/32 trust
      #     host all all ::1/128 trust
      #   '';
      #   initialScript = pkgs.writeText "postgres-init.sql" ''
      #     CREATE ROLE developer WITH LOGIN PASSWORD 'developer' CREATEDB;
      #     CREATE DATABASE development;
      #     GRANT ALL PRIVILEGES ON DATABASE development TO developer;
      #   '';
      # };
      
      # Redis for development
      # Disabled - now configured via nixconf.services.databases
      # redis = {
      #   servers."development" = {
      #     enable = true;
      #     port = 6379;
      #     bind = "127.0.0.1";
      #     save = [];
      #   };
      # };
    }
    
    # macOS specific services
    (lib.mkIf isDarwin {
      # Note: Many services on macOS are handled by Homebrew
      # This section can be expanded as needed
    })
    
    # NixOS specific services
    (lib.mkIf isNixOS {
      # Docker is handled via virtualisation, not services - moved to feature-implementations.nix
      # VirtualBox is handled via virtualisation, not services - moved to feature-implementations.nix
    })
  ];
  
  # macOS specific configuration
} // lib.optionalAttrs isDarwin {
  system = {
    # Additional defaults for development
    defaults = {
      NSGlobalDomain = {
        # Show all file extensions (important for development)
        AppleShowAllExtensions = true;
        
        # Enable developer extras in Safari
        WebKitDeveloperExtras = true;
        
        # Show full POSIX path in Finder title
        _FXShowPosixPathInTitle = true;
      };
      
      # Custom user preferences for development apps
      CustomUserPreferences = {
        # Xcode
        "com.apple.dt.Xcode" = {
          ShowBuildOperationDuration = true;
          IDEIndexerActivityShowNumericProgress = true;
          IDEShowParsedSourceTextForIndexing = false;
          DVTTextShowLineNumbers = true;
          DVTTextShowPageGuide = true;
          DVTTextPageGuideLocation = 120;
          DVTTextIndentUsingSpaces = true;
          DVTTextIndentWidth = 2;
          IDEEditorCoordinatorTarget_DoubleClick = "SameAsClick";
          IDEIssueNavigatorDetailLevel = 30;
          IDESearchNavigatorDetailLevel = 30;
          IDESourceControlAutomaticallySyncLocalStatusChecks = true;
        };
        
        # Tower Git client
        "com.fournova.Tower3" = {
          GTUserDefaultsAlwaysOpenDiffsInUnifiedMode = true;
          GTUserDefaultsDefaultCloningDirectory = "~/src";
          GTUserDefaultsGitBinaryPath = "${pkgs.git}/bin/git";
        };
        
        # TablePlus
        "com.tinyapp.TablePlus" = {
          SidebarVisible = true;
          OpenNewConnectionInTab = true;
          AlwaysShowConnectionBar = true;
        };
        
        # Paw/RapidAPI
        "com.luckymarmot.Paw" = {
          TabSizeInSpaces = 2;
          SoftTabs = true;
          ShowLineNumbers = true;
        };
      };
    };
  };
  
  # User configuration for development
  users.users = {
    # Add user to development-related groups
    "${config.users.primaryUser.username or "jontk"}" = {
      extraGroups = [ "docker" ];
    };
  };
  
  # Homebrew packages for development (macOS only) - disabled temporarily
} // lib.optionalAttrs false {
  homebrew = {
    # Development-specific taps
    taps = [
      "homebrew/cask-versions"
      "hashicorp/tap"
      "mongodb/brew"
    ];
    
    # Development brews
    brews = [
      # iOS development
      "ios-deploy"
      "ideviceinstaller"
      "libimobiledevice"
      
      # Android development
      "android-platform-tools"
      
      # Database clients
      "libpq" # PostgreSQL client
      "mysql-client"
      "mongodb-community"
      
      # Additional development tools
      "watchman" # File watching service
      "direnv" # Environment switcher
      "asdf" # Version manager
    ];
    
    # Development casks
    casks = [
      # IDEs and Editors
      "visual-studio-code"
      "intellij-idea"
      "webstorm"
      "pycharm"
      "goland"
      "datagrip"
      "android-studio"
      
      # API Development
      "postman"
      "insomnia"
      "paw"
      
      # Database Tools
      "tableplus"
      "sequel-ace"
      "mongodb-compass"
      "redis-insight"
      
      # Container/K8s Tools
      "docker"
      "lens"
      "rancher"
      
      # Network Analysis
      "wireshark"
      "charles"
      "proxyman"
      
      # Version Control
      "sourcetree"
      "tower"
      "github"
      "gitup"
      
      # Design/Documentation
      "drawio"
      "dash"
      
      # Virtualization
      "vagrant"
      "virtualbox"
      "utm" # For Apple Silicon
      
      # Cloud Tools
      "aws-vault"
      "session-manager-plugin"
    ];
  };
}