{ config, pkgs, lib, ... }:

{
  # macOS-specific configuration with nix-darwin
  
  # Enable nix-darwin
  system.stateVersion = 4;
  system.primaryUser = "jontk";
  ids.gids.nixbld = 350;
  
  # Nix configuration
  nix = {
    # nix-darwin only supports multi-user daemon installations
    
    # Enable flakes and other experimental features
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Keep derivations and outputs for better caching
      keep-outputs = true;
      keep-derivations = true;
      # Store optimization is done via nix.optimise.automatic below
      # Build in parallel
      max-jobs = "auto";
      cores = 0;
      # Trusted users for Darwin
      trusted-users = [ "root" "@admin" "jontk" ];
    };
    
    # Configure garbage collection
    gc = {
      automatic = true;
      interval = { Hour = 3; Minute = 0; Weekday = 0; }; # Every Sunday at 3 AM
      options = "--delete-older-than 30d";
    };
    
    # Extra substituters for faster builds
    settings.substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
    ];
    
    settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];

    # Automatic store optimization (replaces auto-optimise-store)
    optimise.automatic = true;
  };

  # macOS system defaults
  system.defaults = {
    # Global macOS defaults (only nix-darwin supported options)
    NSGlobalDomain = {
      # Appearance
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;

      # Keyboard
      InitialKeyRepeat = 14;
      KeyRepeat = 1;
      ApplePressAndHoldEnabled = false;
      AppleKeyboardUIMode = 3;

      # Text input
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;

      # UI behavior
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSTableViewDefaultSizeMode = 2;
      NSWindowResizeTime = 0.001;
      NSAutomaticWindowAnimationsEnabled = false;
      NSScrollAnimationEnabled = false;

      # Window behavior
      AppleWindowTabbingMode = "manual";

      # Sound
      "com.apple.sound.beep.feedback" = 0;
      "com.apple.sound.beep.volume" = 0.0;

      # Misc
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };
    
    # Dock settings
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.5;
      expose-animation-duration = 0.15;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      mouse-over-hilite-stack = true;
      mru-spaces = false;
      orientation = "bottom";
      show-process-indicators = true;
      show-recents = false;
      showhidden = true;
      static-only = false;
      tilesize = 48;
      # Disable hot corners
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };
    
    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      CreateDesktop = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      NewWindowTarget = "Other";
      NewWindowTargetPath = "file://$HOME/";
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
    };
    
    # Login window settings
    loginwindow = {
      GuestEnabled = false;
      DisableConsoleAccess = true;
      LoginwindowText = "NixOS-managed macOS";
    };
    
    # Spaces settings
    spaces = {
      spans-displays = false; # Each display has separate spaces
    };
    
    # Trackpad settings (nix-darwin supported subset)
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
      ActuationStrength = 0; # Silent clicking
      Dragging = false;
    };
    
    # Screen saver settings
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 5; # Seconds before password is required
    };
    
    # Screenshot settings
    screencapture = {
      location = "~/Desktop/Screenshots";
      type = "png";
      disable-shadow = true;
    };
    
    # Universal Access settings
    universalaccess = {
      reduceMotion = true; # Reduce animations
      reduceTransparency = false; # Keep transparency
      closeViewScrollWheelToggle = false; # Don't use scroll gesture with modifier keys to zoom
      closeViewZoomFollowsFocus = false;
    };
    
    # Control Center settings (macOS 11+)
    controlcenter = {
      AirDrop = false; # Don't show in menu bar
      Bluetooth = true; # Show in menu bar
      Display = true;
      Sound = true;
      NowPlaying = false;
      FocusModes = false;
      BatteryShowPercentage = true;
    };
    
    # Menu extras
    menuExtraClock = {
      Show24Hour = true;
      ShowSeconds = true;
    };
    
    # Hot corner modifiers (set via CustomUserPreferences below)
    
    # Other settings
    CustomUserPreferences = {
      # NSGlobalDomain keys not directly supported by nix-darwin
      "NSGlobalDomain" = {
        AppleHighlightColor = "0.764700 0.976500 0.568600";
        AppleAquaColorVariant = 1;
        AppleAccentColor = 0;
        AppleFnUsageType = 2;
        NSAutomaticTextCompletionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSToolbarTitleViewRolloverDelay = 0;
        NSUseAnimatedFocusRing = false;
        NSWindowShouldDragOnGesture = true;
        AppleActionOnDoubleClick = "Maximize";
        AppleEnableMouseSwipeNavigateWithScrolls = false;
        AppleEnableSwipeNavigateWithScrolls = false;
        NSDisableAutomaticTermination = true;
        NSQuitAlwaysKeepsWindows = false;
        WebKitDeveloperExtras = true;
        "com.apple.sound.uiaudio.enabled" = 0;
        "com.apple.mouse.scaling" = 1.0;
      };

      # Finder settings not directly supported by nix-darwin
      "com.apple.finder" = {
        ShowRecentTags = false;
        WarnOnEmptyTrash = false;
        DisableAllAnimations = true;
        FXInfoPanesExpanded = {
          General = true;
          OpenWith = true;
          Privileges = true;
        };
      };

      # Hot corner modifiers
      "com.apple.dock" = {
        wvous-tl-modifier = 0;
        wvous-tr-modifier = 0;
        wvous-bl-modifier = 0;
        wvous-br-modifier = 0;
      };

      # Disable Spotlight keyboard shortcuts
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "64" = { enabled = false; }; # Spotlight search
          "65" = { enabled = false; }; # Spotlight window
        };
      };
      
      # Safari settings
      "com.apple.Safari" = {
        ShowFullURLInSmartSearchField = true;
        ShowFavoritesBar = false;
        ShowSidebarInTopSites = false;
        SuppressSearchSuggestions = true;
        UniversalSearchEnabled = false;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebKitPreferences.developerExtrasEnabled = true;
        IncludeDevelopMenu = true;
        WebKitMediaPlaybackAllowsInline = true;
        WebContinuousSpellCheckingEnabled = false;
        WebAutomaticSpellingCorrectionEnabled = false;
        AutoOpenSafeDownloads = false;
        HomePage = "";
        ShowFavoritesBar-v2 = false;
        NewTabBehavior = 1;
        NewWindowBehavior = 1;
        TabCreationPolicy = 2;
        DebugSnapshotsUpdatePolicy = 2;
        SearchProviderIdentifier = "com.duckduckgo";
      };
      
      # Terminal settings
      "com.apple.Terminal" = {
        StringEncodings = 4;
        "Default Window Settings" = "Pro";
        "Startup Window Settings" = "Pro";
        ShowLineMarks = 0;
        WindowNumber = 0;
      };
      
      # Activity Monitor settings
      "com.apple.ActivityMonitor" = {
        IconType = 5; # CPU usage
        ShowCategory = 0; # All processes
        SortColumn = "CPUUsage";
        SortDirection = 0; # Descending
        OpenMainWindow = true;
      };
      
      # Mail settings
      "com.apple.mail" = {
        DisableReplyAnimations = true;
        DisableSendAnimations = true;
        DisableInlineAttachmentViewing = true;
        AddressesIncludeNameOnPasteboard = false;
        DraftsViewerAttributes = {
          DisplayInThreadedMode = "yes";
          SortedDescending = "yes";
          SortOrder = "received-date";
        };
      };
      
      # Messages settings
      "com.apple.messageshelper.MessageController" = {
        "SOInputLineSettings.automaticEmojiSubstitutionEnabled" = false;
        "SOInputLineSettings.automaticQuoteSubstitutionEnabled" = false;
      };
      
      # TextEdit settings
      "com.apple.TextEdit" = {
        RichText = false; # Use plain text by default
        OpenPanelFollowsLastDocument = false;
        ShowRuler = false;
        SmartCopyPaste = false;
        TextReplacement = false;
        CorrectSpellingAutomatically = false;
      };
      
      # Preview settings
      "com.apple.Preview" = {
        NSQuitAlwaysKeepsWindows = false;
        NSCloseAlwaysConfirmsChanges = false;
      };
      
      # Screenshot settings
      "com.apple.screencapture" = {
        location = "~/Desktop/Screenshots";
        type = "png";
        "disable-shadow" = true;
        "include-date" = true;
        "show-thumbnail" = true;
        target = "file";
      };
      
      # Time Machine settings
      "com.apple.TimeMachine" = {
        DoNotOfferNewDisksForBackup = true;
        ExcludeSystemFiles = true;
      };
      
      # Software Update settings
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        ScheduleFrequency = 7; # Check weekly
        AutomaticDownload = 0;
        CriticalUpdateInstall = 0;
      };
      
      # Disk Utility settings
      "com.apple.DiskUtility" = {
        DUDebugMenuEnabled = true;
        "advanced-image-options" = true;
      };
      
      # Music/iTunes settings
      "com.apple.Music" = {
        userWantsPlaybackNotifications = false;
        dontAutomaticallySyncIPods = true;
      };
    };
  };
  
  # Enable Touch ID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
  
  # Additional security settings
  system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = false; # Don't auto-install OS updates
  };
  
  # Keyboard and input settings
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = false; # Set to true if you want Caps Lock as Escape
    # remapCapsLockToControl = true; # Alternative: Caps Lock as Control
    userKeyMapping = [
      # Example: Remap right Command to right Option
      # {
      #   HIDKeyboardModifierMappingSrc = 30064771303;
      #   HIDKeyboardModifierMappingDst = 30064771302;
      # }
    ];
  };
  
  # Networking configuration
  networking = {
    hostName = "refur";
    computerName = "refur";
    localHostName = "refur";

    # DNS — let DHCP provide DNS (typically 192.168.1.1)
    # Uncomment to override with custom DNS:
    # dns = [ "192.168.1.1" ];
  };
  
  # Power management is configured via pmset in the activation script below
  
  # System packages
  environment.systemPackages = with pkgs; [
    # macOS-specific utilities
    mas # Mac App Store CLI
    cocoapods
    terminal-notifier
    dockutil
    pngpaste # Paste images from clipboard
    # pbcopy/pbpaste are macOS builtins, no nix package needed
    
    # System utilities
    coreutils-full
    moreutils
    watch
    lsof
    file
    which
    gnugrep
    gnutar
    gnused
    gawk
    findutils
    
    # File management
    trash-cli
    ncdu # Disk usage analyzer
    duf # Modern df replacement
    dust # Modern du replacement
    
    # Process management
    procs # Modern ps replacement
    bottom # System monitor
    
    # Network utilities
    mtr # Network diagnostic tool
    bandwhich # Network utilization monitor
    gping # Ping with graph
    
    # Security tools
    gnupg
    pass
    pinentry_mac
    
    # Archive utilities
    p7zip
    unrar
    xz
    
    # Development tools (basic, more in development module)
    xcodes
    
    # System maintenance
    nix-index # File database for nix
    cachix # Binary cache management
    
    # Terminal enhancements
    starship # Prompt
    zoxide # Smarter cd
    fzf # Fuzzy finder
    eza # Modern ls replacement
    bat # Modern cat replacement
    ripgrep # Modern grep replacement
    fd # Modern find replacement
    sd # Modern sed replacement
    tealdeer # Modern tldr client
    
    # JSON/YAML tools
    jq
    yq-go
    
    # HTTP tools
    curl
    wget
    httpie
    
    # Network utilities (extended)
    nmap
    netcat
    # traceroute is Linux-only; macOS has /usr/sbin/traceroute built-in
    dig
    whois
    speedtest-cli
    iperf

    # Version control extras
    tig
    gitui
    lazygit
    delta

    # Terminal multiplexers
    tmux
    zellij

    # Editors
    micro
    zed-editor

    # Build tools
    gnumake
    cmake
    pkg-config
    autoconf
    automake
    libtool

    # Cloud/infra tools
    google-cloud-sdk
    azure-cli
    doctl
    terraform
    terragrunt
    pulumi
    ansible

    # Kubernetes extras
    kubectl
    kubectx
    k9s
    kubernetes-helm
    kustomize
    stern
    fluxcd
    argocd

    # Productivity/backup
    taskwarrior3
    timewarrior
    pass
    gopass
    rclone
    restic
    borgbackup
    syncthing

    # Document tools
    pandoc
    poppler_utils
    ghostscript
    (texlive.combine {
      inherit (texlive) scheme-basic xetex collection-fontsrecommended collection-plaingeneric collection-latexextra;
    })

    # System utilities (extended)
    choose # cut alternative
    miller # CSV/JSON/tabular data tool

    # Media tools
    yt-dlp
    ffmpeg
    imagemagick
    exiftool
    mediainfo

    # Secrets management
    doppler

    # Tools previously only in brew
    chezmoi
    hugo
    tesseract # OCR engine
    sox # Audio processing
    reattach-to-user-namespace # tmux clipboard on macOS
    clisp # Common Lisp
    xcodegen # Generate Xcode projects from YAML
    plotutils # Vector graphics tools
    pstoedit # PostScript conversion

    # Database clients
    postgresql
    redis
    sqlite

    # HTTP clients
    curlie
    xh

    # Misc utilities
    neofetch
    cowsay
    fortune
    figlet
    lolcat
  ];
  
  # Homebrew integration
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap"; # Remove unlisted formulae and casks
      upgrade = true;
      autoUpdate = true;
    };
    
    # Taps — homebrew/services, cask-versions, cask-fonts are now built-in/merged
    taps = [ ];
    
    # Brews — only things that need brew (services, macOS-specific)
    # CLI tools go in environment.systemPackages via nix instead
    brews = [
      # Services (managed via `brew services start`)
      "postgresql@15"
      "redis"
      "nginx"

      # macOS-specific tools (no nix equivalent)
      "switchaudio-osx"
      "brightness"
      "sleepwatcher"
      "blueutil"
      "wifi-password"

      # Local HTTPS certificates
      "mkcert"
      "nss"
    ];
    
    # Casks (GUI applications)
    casks = [
      # Browsers
      "firefox"
      "google-chrome"
      
      # Communication
      "slack"
      "discord"
      "zoom"
      
      # Development
      "visual-studio-code"
      "iterm2"
      "docker"
      "zed"
      
      # Utilities
      "rectangle" # Window management
      "alfred" # Launcher
      "1password" # Password manager
      "bartender" # Menu bar management
      "cleanmymac" # System maintenance
      
      # Media
      "spotify"
      "vlc"
      
      # Productivity
      "notion"
      "obsidian"
      
      # System tools
      "istat-menus" # System monitoring
      "little-snitch" # Network monitor
      "carbon-copy-cloner" # Backup
    ];
    
    # Mac App Store apps
    masApps = {
      "Amphetamine" = 937984704;
      "Xcode" = 497799835;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
    };
  };
  
  # Enable fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      fira-code
      fira-code-symbols
      roboto
      roboto-mono
      source-code-pro
    ];
  };
  
  # Services
  services = {
    # Tailscale VPN
    tailscale = {
      enable = true;
    };

    # Karabiner Elements for keyboard customization
    karabiner-elements.enable = true;
    
    # Yabai window manager (optional, disabled by default)
    # yabai = {
    #   enable = false;
    #   package = pkgs.yabai;
    #   enableScriptingAddition = true;
    #   config = {
    #     layout = "bsp";
    #     window_placement = "second_child";
    #     window_opacity = "on";
    #     window_opacity_duration = "0.0";
    #     active_window_opacity = "1.0";
    #     normal_window_opacity = "0.95";
    #   };
    # };
    
    # skhd hotkey daemon (pairs with yabai)
    # skhd = {
    #   enable = false;
    #   package = pkgs.skhd;
    # };
  };
  
  # Shell configuration
  programs = {
    # Enable zsh
    zsh = {
      enable = true;
      enableCompletion = true;
      enableSyntaxHighlighting = true;
    };

    # Bash is available by default on macOS
  };
  
  # Common and development modules are imported via flake.nix (commonModules/developmentModules)
  
  # Home Manager disabled — dotfiles managed by chezmoi
  
  # User configuration
  users.users.jontk = {
    name = "jontk";
    home = "/Users/jontk";
    shell = pkgs.zsh;
  };
  
  # LaunchDaemons and LaunchAgents
  launchd = {
    # User agents (run as user)
    agents = {
      # Downloads cleanup — disabled until folder is triaged
      # cleanup-downloads = {
      #   script = ''
      #     find ~/Downloads -mtime +30 -type f -delete
      #     find ~/Downloads -type d -empty -delete
      #   '';
      #   serviceConfig = {
      #     StartCalendarInterval = [
      #       { Hour = 3; Minute = 0; Weekday = 0; }
      #     ];
      #   };
      # };

      # Update nix-index database weekly
      update-nix-index = {
        script = ''
          ${pkgs.nix-index}/bin/nix-index
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 4; Minute = 0; Weekday = 1; } # Monday at 4 AM
          ];
        };
      };
      
      # Clear Trash older than 30 days
      auto-empty-trash = {
        script = ''
          find ~/.Trash -mtime +30 -exec rm -rf {} +
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 3; Minute = 30; Weekday = 0; } # Sunday at 3:30 AM
          ];
        };
      };
      
      # Backup important directories
      backup-documents = {
        script = ''
          if [ -d "/Volumes/Backup" ]; then
            rsync -av --delete ~/Documents/ /Volumes/Backup/Documents/
            rsync -av --delete ~/Desktop/ /Volumes/Backup/Desktop/
          fi
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 2; Minute = 0; } # Daily at 2 AM
          ];
        };
      };
    };
    
    # System daemons (run as root)
    daemons = {
      # Optimize Nix store weekly
      optimize-nix-store = {
        script = ''
          ${pkgs.nix}/bin/nix-store --optimise
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 5; Minute = 0; Weekday = 0; } # Sunday at 5 AM
          ];
        };
      };
      
      # Update system time via NTP
      ntp-sync = {
        script = ''
          /usr/sbin/sntp -sS time.apple.com
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 12; Minute = 0; } # Daily at noon
          ];
        };
      };
    };
  };
  
  # Environment variables
  environment.variables = {
    EDITOR = "vim";
    VISUAL = "vim";
    PAGER = "less";
    LANG = "en_US.UTF-8";
    # Development
    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_INSECURE_REDIRECT = "1";
    HOMEBREW_CASK_OPTS = "--require-sha";
    # Nix
    NIX_CONF_DIR = "/etc/nix";
    # Terminal
    TERM = "xterm-256color";
    COLORTERM = "truecolor";
  };
  
  # System-wide aliases — only nix/darwin-specific commands
  # General shell aliases are managed by chezmoi (~/.config/shell/aliases.sh)
  environment.shellAliases = {
    # Nix management (chezmoi can't provide these)
    rebuild = "darwin-rebuild switch --flake .";
    update = "nix flake update";
    garbage = "nix-collect-garbage -d";

    # Spotlight (macOS-specific, not in chezmoi)
    spotoff = "sudo mdutil -a -i off";
    spoton = "sudo mdutil -a -i on";
  };
  
  # System activation scripts (runs as root in new nix-darwin)
  system.activationScripts.postActivation.text = ''
    # Create Screenshots directory
    sudo -u jontk mkdir -p /Users/jontk/Desktop/Screenshots

    # Configure Rosetta 2 for Apple Silicon Macs
    if [ "$(uname -m)" = "arm64" ]; then
      if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Installing Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
      fi
    fi

    # Power management
    pmset -a sleep 0
    pmset -b sleep 15
    pmset -a standbydelay 86400

    # Firewall
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
    /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

    # Security hardening
    systemsetup -setremoteappleevents off 2>/dev/null || true
    systemsetup -setwakeonmodem off 2>/dev/null || true
    systemsetup -setwakeonnetworkaccess off 2>/dev/null || true

    # Disable boot sound
    nvram SystemAudioVolume=" " 2>/dev/null || true

    echo "System preferences configured."
  '';
  
  # System startup items and login items
  system.defaults.LaunchServices = {
    LSQuarantine = false; # Disable quarantine for downloaded apps
  };
}