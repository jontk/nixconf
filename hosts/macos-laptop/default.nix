{ config, pkgs, lib, ... }:

{
  # macOS-specific configuration with nix-darwin
  
  # Enable nix-darwin
  system.stateVersion = 4;
  
  # Nix configuration
  nix = {
    # Use the Nix daemon for multi-user support
    useDaemon = true;
    
    # Enable flakes and other experimental features
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Keep derivations and outputs for better caching
      keep-outputs = true;
      keep-derivations = true;
      # Automatic store optimization
      auto-optimise-store = true;
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
  };
  
  # macOS system defaults
  system.defaults = {
    # Global macOS defaults
    NSGlobalDomain = {
      # Appearance
      AppleInterfaceStyle = "Dark"; # Dark mode
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleHighlightColor = "0.764700 0.976500 0.568600";
      AppleAquaColorVariant = 1; # Blue appearance
      AppleAccentColor = 0; # Blue accent color
      
      # Keyboard
      InitialKeyRepeat = 14; # Delay until repeat
      KeyRepeat = 1; # Key repeat rate (lower = faster)
      ApplePressAndHoldEnabled = false; # Disable press-and-hold for keys
      AppleKeyboardUIMode = 3; # Full keyboard access
      AppleFnUsageType = 2; # F1, F2, etc. behave as standard function keys
      
      # Text input
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticTextCompletionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      NSUserDictionaryReplacementItems = [];
      
      # UI behavior
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSTableViewDefaultSizeMode = 2; # Medium sidebar icons
      NSToolbarTitleViewRolloverDelay = 0; # Reduce toolbar title rollover delay
      NSWindowResizeTime = 0.001; # Speed up window resize animations
      NSAutomaticWindowAnimationsEnabled = false; # Disable window animations
      NSScrollAnimationEnabled = false; # Disable smooth scrolling
      NSUseAnimatedFocusRing = false; # Disable animated focus ring
      
      # Window behavior
      AppleActionOnDoubleClick = "Maximize"; # Maximize windows on double click
      AppleWindowTabbingMode = "manual"; # Don't tab windows by default
      NSWindowShouldDragOnGesture = true; # Enable window dragging gestures
      
      # Sound
      "com.apple.sound.beep.feedback" = 0;
      "com.apple.sound.beep.volume" = 0.0;
      "com.apple.sound.uiaudio.enabled" = 0; # Disable UI sound effects
      
      # Mouse
      AppleEnableMouseSwipeNavigateWithScrolls = false;
      AppleEnableSwipeNavigateWithScrolls = false;
      "com.apple.mouse.scaling" = 1.0;
      
      # Screenshots
      "com.apple.screencapture.location" = "~/Desktop/Screenshots";
      "com.apple.screencapture.type" = "png";
      "com.apple.screencapture.disable-shadow" = true;
      
      # Misc
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDisableAutomaticTermination = true; # Don't terminate inactive apps
      NSQuitAlwaysKeepsWindows = false; # Don't restore windows when quitting and reopening apps
      WebKitDeveloperExtras = true; # Enable Safari developer menu
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
      FXDefaultSearchScope = "SCcf"; # Search current folder by default
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # List view
      QuitMenuItem = true; # Allow quitting Finder
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true; # Sort folders before files
      ShowRecentTags = false; # Don't show recent tags
      NewWindowTarget = "Home"; # New windows open in home directory
      NewWindowTargetPath = "file://$HOME/";
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowExternalHardDrivesOnDesktop = true;
      DisableAllAnimations = true; # Disable Finder animations
      WarnOnEmptyTrash = false; # Don't warn when emptying trash
      FXInfoPanesExpanded = {
        General = true;
        OpenWith = true;
        Privileges = true;
      };
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
    
    # Trackpad settings
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
      TrackpadScroll = true;
      TrackpadHorizScroll = true;
      ActuationStrength = 0; # Silent clicking
      Dragging = false; # Tap to drag (separate from three finger drag)
      DragLock = false;
      TrackpadPinch = true;
      TrackpadRotate = true;
      TrackpadTwoFingerDoubleTapGesture = true;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 0; # Disable notification center swipe
      TrackpadFiveFingerPinchGesture = true;
      TrackpadFourFingerPinchGesture = true;
      TrackpadFourFingerHorizSwipeGesture = 2; # Switch between spaces
      TrackpadFourFingerVertSwipeGesture = 2; # Mission control and app expose
      TrackpadMomentumScroll = true;
      TrackpadCornerSecondaryClick = 0; # Right-click in bottom right corner
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
      DateFormat = "EEE d MMM HH:mm:ss";
      ShowDate = 1; # Show date
      ShowDayOfWeek = true;
      ShowAMPM = false; # 24-hour time
      ShowSeconds = true;
    };
    
    # Hot corners (already disabled above, but for completeness)
    # 1: No action, 2: Mission Control, 3: Show application windows
    # 4: Desktop, 5: Start screen saver, 6: Disable screen saver
    # 10: Put display to sleep, 11: Launchpad, 12: Notification Center
    # 13: Lock Screen, 14: Quick Note
    "com.apple.dock" = {
      wvous-tl-corner = 1; # Top left: disabled
      wvous-tl-modifier = 0;
      wvous-tr-corner = 1; # Top right: disabled
      wvous-tr-modifier = 0;
      wvous-bl-corner = 1; # Bottom left: disabled
      wvous-bl-modifier = 0;
      wvous-br-corner = 1; # Bottom right: disabled
      wvous-br-modifier = 0;
    };
    
    # Other settings
    CustomUserPreferences = {
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
  security.pam.enableSudoTouchIdAuth = true;
  
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
    hostName = "macos-laptop";
    computerName = "macOS Laptop";
    localHostName = "macos-laptop";
    
    # DNS configuration
    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];
    
    # Enable mDNS
    # Note: This is typically enabled by default on macOS
  };
  
  # Power management settings
  power = {
    sleep = {
      computer = 15;
      display = 10;
      harddisk = 10;
      allowSleepByPowerButton = true;
    };
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    # macOS-specific utilities
    mas # Mac App Store CLI
    cocoapods
    terminal-notifier
    dockutil
    pngpaste # Paste images from clipboard
    pbcopy # Command line clipboard utilities
    pbpaste
    
    # System utilities
    coreutils-full
    moreutils
    watch
    psutil
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
    xcode-install
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
    
    # Taps
    taps = [
      "homebrew/services"
      "homebrew/cask-versions"
      "homebrew/cask-fonts"
    ];
    
    # Brews (command-line tools not available in nixpkgs)
    brews = [
      # Tools that require macOS-specific features
      "pinentry-mac"
      "trash"
      
      # Services
      "postgresql@15"
      "redis"
      "nginx"
      
      # macOS specific tools
      "switchaudio-osx" # Switch audio devices
      "brightness" # Control display brightness
      "sleepwatcher" # Run commands on sleep/wake
      "blueutil" # Bluetooth CLI
      "wifi-password" # Get current WiFi password
      
      # Development services
      "mkcert" # Local HTTPS certificates
      "nss" # Network Security Services (for mkcert)
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
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "Hack" ]; })
      fira-code
      fira-code-symbols
      roboto
      roboto-mono
      source-code-pro
    ];
  };
  
  # Services
  services = {
    # Nix daemon
    nix-daemon.enable = true;
    
    # Activate system configuration on boot
    activate-system.enable = true;
    
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
      enableBashCompletion = true;
      enableFzfCompletion = true;
      enableFzfGit = true;
      enableFzfHistory = true;
    };
    
    # Enable bash (for compatibility)
    bash = {
      enable = true;
      enableCompletion = true;
    };
  };
  
  # Import common modules
  imports = [
    ../../modules/common
    ../../modules/development
  ];
  
  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jontk = import ../../users/jontk {
      inherit config pkgs lib;
      isDarwin = true;
      isNixOS = false;
    };
    # Extra arguments passed to home-manager modules
    extraSpecialArgs = {
      inherit (config.nixpkgs) overlays;
      isDarwin = true;
      isNixOS = false;
    };
    # Verbose output for debugging
    verbose = true;
  };
  
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
      # Clean Downloads folder weekly
      cleanup-downloads = {
        script = ''
          find ~/Downloads -mtime +30 -type f -delete
          find ~/Downloads -type d -empty -delete
        '';
        serviceConfig = {
          StartCalendarInterval = [
            { Hour = 3; Minute = 0; Weekday = 0; } # Sunday at 3 AM
          ];
        };
      };
      
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
  
  # System-wide aliases
  environment.shellAliases = {
    # Nix aliases
    rebuild = "darwin-rebuild switch --flake .";
    update = "nix flake update";
    garbage = "nix-collect-garbage -d";
    
    # Navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    
    # Safety aliases
    rm = "rm -i";
    cp = "cp -i";
    mv = "mv -i";
    
    # Colorful output
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree";
    cat = "bat";
    
    # Git aliases
    g = "git";
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git log --oneline --graph";
    
    # System info
    top = "btop";
    ps = "procs";
    df = "duf";
    du = "dust";
    
    # Network
    ip = "dig +short myip.opendns.com @resolver1.opendns.com";
    localip = "ipconfig getifaddr en0";
    flush = "dscacheutil -flushcache && killall -HUP mDNSResponder";
    
    # macOS specific
    showfiles = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder";
    hidefiles = "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder";
    spotoff = "sudo mdutil -a -i off";
    spoton = "sudo mdutil -a -i on";
    
    # Development
    serve = "python3 -m http.server";
    json = "jq '.'";
    
    # Misc
    weather = "curl wttr.in";
    speedtest = "curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -";
  };
  
  # System activation scripts
  system.activationScripts.postUserActivation.text = ''
    # Rebuild Spotlight index if needed
    if [ ! -f ~/.spotlight-rebuilt ]; then
      echo "Rebuilding Spotlight index..."
      sudo mdutil -E /
      touch ~/.spotlight-rebuilt
    fi
    
    # Set default shell to zsh if not already
    if [ "$SHELL" != "${pkgs.zsh}/bin/zsh" ]; then
      echo "Setting default shell to zsh..."
      chsh -s ${pkgs.zsh}/bin/zsh
    fi
    
    # Create Screenshots directory if it doesn't exist
    mkdir -p ~/Desktop/Screenshots
    
    # Configure Rosetta 2 for Apple Silicon Macs
    if [ "$(uname -m)" = "arm64" ]; then
      if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Installing Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
      fi
    fi
    
    # Set computer sleep preferences
    sudo pmset -a sleep 0 # Never sleep while plugged in
    sudo pmset -b sleep 15 # Sleep after 15 minutes on battery
    
    # Disable Gatekeeper (use with caution)
    # sudo spctl --master-disable
    
    # Enable firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    
    # Disable remote apple events
    sudo systemsetup -setremoteappleevents off
    
    # Disable wake-on modem
    sudo systemsetup -setwakeonmodem off
    
    # Disable wake-on LAN
    sudo systemsetup -setwakeonnetworkaccess off
    
    # Set standby delay to 24 hours (default is 1 hour)
    sudo pmset -a standbydelay 86400
    
    # Disable the sound effects on boot
    sudo nvram SystemAudioVolume=" "
    
    # Menu bar: hide the Time Machine and Volume icons
    for domain in ~/Library/Preferences/ByHost/com.apple.systemuiserver.*; do
      defaults write "''${domain}" dontAutoLoad -array \
        "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
        "/System/Library/CoreServices/Menu Extras/Volume.menu"
    done
    
    # Expand save panel by default
    defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
    defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
    
    # Expand print panel by default
    defaults write -g PMPrintingExpandedStateForPrint -bool true
    defaults write -g PMPrintingExpandedStateForPrint2 -bool true
    
    # Save to disk (not to iCloud) by default
    defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false
    
    # Restart affected applications
    for app in "Dock" "Finder" "SystemUIServer"; do
      killall "''${app}" > /dev/null 2>&1 || true
    done
    
    echo "System preferences have been configured. Some changes may require a logout/restart to take effect."
  '';
  
  # System startup items and login items
  system.defaults.LaunchServices = {
    LSQuarantine = false; # Disable quarantine for downloaded apps
  };
}