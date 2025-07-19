{ config, pkgs, lib, isDarwin ? false, isNixOS ? false, ... }:

{
  # Home Manager configuration for user jontk
  home.stateVersion = "25.05";
  
  # User information
  home.username = "jontk";
  home.homeDirectory = if isDarwin then "/Users/jontk" else "/home/jontk";
  
  # Enable home-manager
  programs.home-manager.enable = true;
  
  # User-specific package configuration
  # This section allows for easy customization of packages by category
  
  # Package categories - customize these lists as needed
  # Each category can be enabled/disabled and packages can be added/removed
  home.packages = let
    # Core packages - always installed
    corePackages = with pkgs; [
      # Essential CLI tools
      curl
      wget
      tree
      htop
      btop
      killall
      unzip
      zip
      rsync
      
      # Network tools
      nmap
      netcat
      traceroute
      dig
      whois
      
      # Text processing
      jq
      yq
      ripgrep
      fd
      bat
      eza
      fzf
      
      # File management
      file
      which
      less
      most
      
      # System monitoring
      iotop
      nethogs
      iftop
      lsof
      psmisc
      
      # Compression
      p7zip
      xz
      gzip
      bzip2
      
      # Version control basics
      git
      subversion
      mercurial
    ];
    
    # Development packages - programming languages and tools
    developmentPackages = with pkgs; [
      # Terminal utilities
      tmux
      screen
      zellij # Modern terminal multiplexer
      
      # Text editors
      emacs
      micro # Simple terminal editor
      
      # Git tools
      gh # GitHub CLI
      glab # GitLab CLI
      hub # GitHub hub tool
      lazygit # Terminal UI for git
      tig # Text-mode interface for git
      gitui # Rust-based git TUI
      delta # Better git diffs
      
      # Code quality
      shellcheck # Shell script linter
      shfmt # Shell formatter
      
      # Build tools
      gnumake
      cmake
      pkg-config
      autoconf
      automake
      libtool
      
      # Documentation
      man-pages
      tldr
      cheat
      
      # Container tools
      docker-compose
      podman-compose
      skopeo
      buildah
      
      # Cloud tools
      awscli2
      google-cloud-sdk
      azure-cli
      doctl # DigitalOcean CLI
      
      # Infrastructure as code
      terraform
      terragrunt
      ansible
      pulumi
      
      # Kubernetes
      kubectl
      kubectx  # includes kubens
      k9s
      helm
      kustomize
      stern # Multi-pod logs
      
      # Database tools
      postgresql
      redis
      sqlite
      
      # API tools
      httpie
      curlie # curl with HTTP/2 support
      xh # HTTPie in Rust
    ];
    
    # Productivity packages - general productivity tools
    productivityPackages = with pkgs; [
      # Task and time management
      taskwarrior3
      timewarrior
      vit # Terminal task manager
      
      # Note-taking and documentation
      obsidian
      zettlr
      pandoc
      
      # Calendar and contacts
      khal # CLI calendar
      khard # CLI contacts
      
      # Password management
      pass
      gopass
      
      # Backup and sync
      rclone
      restic
      borgbackup
      syncthing
      
      # File conversion
      poppler_utils # PDF utilities
      ghostscript
      pandoc
      
      # Network utilities
      mtr # Network diagnostic
      speedtest-cli
      iperf
      
      # System utilities
      ncdu # Disk usage analyzer
      duf # Disk usage in Go
      dust # du in Rust
      procs # ps in Rust
      bandwhich # Network utilization
      
      # Text manipulation
      sd # sed alternative in Rust
      choose # cut alternative
      miller # CSV/JSON processor
    ];
    
    # Media packages - audio, video, and image tools
    mediaPackages = with pkgs; [
      # Video tools
      yt-dlp
      ffmpeg
      mpv
      vlc
      
      # Audio tools
      audacity
      
      # Image tools
      imagemagick
      gimp
      inkscape
      
      # Ebook management
      calibre
      
      # Media organization
      exiftool # Image metadata
      mediainfo # Media file info
      
      # Streaming
      obs-studio
      
      # Graphics
      blender
      krita
    ];
    
    # Communication packages - messaging and social
    communicationPackages = with pkgs; [
      # Chat applications
      discord
      signal-desktop
      telegram-desktop
      element-desktop # Matrix client
      
      # Email
      thunderbird
      neomutt # Terminal email
      
      # IRC
      weechat
      irssi
      
      # Video calls
      zoom-us
      teams-for-linux
    ];
    
    # Security packages - security and privacy tools
    securityPackages = with pkgs; [
      # Network security
      nmap
      masscan
      wireshark
      tcpdump
      
      # Password tools
      john # Password cracker
      hashcat # Password recovery
      
      # Cryptography
      gnupg
      age # File encryption
      sops # Secrets management
      
      # VPN
      openvpn
      wireguard-tools
      
      # Security scanning
      lynis # Security auditing
      
      # Forensics
      volatility3
      sleuthkit
      
      # Network tools
      aircrack-ng
      kismet
    ];
    
    # Gaming packages - games and gaming tools
    gamingPackages = with pkgs; [
      # Steam and gaming
      steam
      lutris
      bottles
      
      # Emulation
      retroarch
      
      # Game development
      godot_4
      
      # Fun terminal tools
      neofetch
      cowsay
      fortune
      lolcat
      figlet
      
      # Games
      bastet # Tetris
      nudoku # Sudoku
      moon-buggy # Side-scrolling game
    ];
    
    # Research packages - academic and research tools
    researchPackages = with pkgs; [
      # Reference management
      zotero
      
      # Document preparation
      texlive.combined.scheme-full
      
      # Data analysis
      R
      rstudio
      
      # Scientific computing
      octave
      scilab
      
      # Statistics
      pspp # SPSS alternative
      
      # Plotting
      gnuplot
      
      # Citation tools
      citeproc
    ];
    
    # Platform-specific packages
    macosPackages = lib.optionals isDarwin (with pkgs; [
      reattach-to-user-namespace # For tmux clipboard support
      pinentry_mac # GPG on macOS
      mas # Mac App Store CLI
      
      # macOS-specific tools
      m-cli # Swiss Army Knife for macOS
      
      # Homebrew integration
      # Note: These are Nix packages that provide similar functionality to Homebrew
    ]);
    
    nixosPackages = lib.optionals (!isDarwin) (with pkgs; [
      # Linux-specific tools
      lshw # Hardware lister
      pciutils # PCI utilities
      usbutils # USB utilities
      hdparm # Hard disk parameters
      smartmontools # SMART disk monitoring
      
      # System monitoring
      iotop
      powertop # Power consumption
      
      # Display and graphics
      arandr # Monitor configuration
      xorg.xrandr
      
      # Audio
      pavucontrol # PulseAudio control
      alsa-utils # ALSA mixer (includes alsamixer)
      
      # Desktop utilities
      xclip # Clipboard
      xsel # X selection
      wl-clipboard # Wayland clipboard
      
      # File managers
      ranger # Terminal file manager
      nnn # Terminal file browser
      xfce.thunar # GUI file manager
      
      # Archiving with GUI
      file-roller
      
      # Web browsers
      firefox
      chromium
      
      # Office and productivity
      libreoffice
      evince # PDF viewer
      
      # Media viewers
      eog # Image viewer
      
      # Communication
      thunderbird
      
      # System utilities
      gnome-calculator
      gnome-system-monitor
      gnome-disk-utility
      
      # Wayland tools
      wlr-randr
      kanshi # Display management
      
      # Screenshot tools
      flameshot
      
      # System info
      neofetch
      screenfetch
      
      # Virtualization
      qemu
      libvirt
      virt-manager
    ]);
    
    # User customization section
    # Add your personal packages here
    personalPackages = with pkgs; [
      # Add your favorite packages here
      # Examples:
      # slack
      # spotify
      # vscode
      # jetbrains.idea-ultimate
      # firefox
      # chromium
      
      # Placeholder - remove this and add your packages
    ];
    
  in
    # Combine all package categories
    # You can comment out entire categories to disable them
    corePackages
    ++ developmentPackages
    ++ productivityPackages
    ++ mediaPackages
    ++ communicationPackages
    # ++ securityPackages      # Uncomment if you need security tools
    # ++ gamingPackages        # Uncomment if you want gaming packages
    # ++ researchPackages      # Uncomment if you need research tools
    ++ macosPackages
    ++ nixosPackages
    ++ personalPackages;
  
  
  # RustDesk wrapper script to preserve server settings
  home.file.".local/bin/rustdesk-local" = lib.mkIf isNixOS {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      # Create config directory if it doesn't exist
      mkdir -p ~/.config/rustdesk
      
      # Stop any running RustDesk instances
      pkill -x rustdesk || true
      sleep 1
      
      # Write the config file
      cat > ~/.config/rustdesk/RustDesk2.toml << 'EOF'
      rendezvous_server = '192.168.1.241:21119'
      nat_type = 1
      serial = 1
      
      [options]
      custom-rendezvous-server = '192.168.1.241:21119'
      relay-server = '192.168.1.241:21117'
      api-server = ""
      key = ""
      EOF
      
      # Make it harder to overwrite (not foolproof but helps)
      chmod 644 ~/.config/rustdesk/RustDesk2.toml
      
      # Start RustDesk
      exec ${pkgs.rustdesk}/bin/rustdesk "$@"
    '';
  };
  
  # Alternative: Use a systemd timer to restore config
  systemd.user.timers.rustdesk-config-restore = lib.mkIf isNixOS {
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "rustdesk-config-restore.service";
    };
  };
  
  systemd.user.services.rustdesk-config-restore = lib.mkIf isNixOS {
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "restore-rustdesk-config" ''
        #!/usr/bin/env bash
        
        # Only restore if RustDesk is running
        if pgrep -x rustdesk > /dev/null; then
          # Check if config has wrong server
          if ! grep -q "192.168.1.241:21119" ~/.config/rustdesk/RustDesk2.toml 2>/dev/null; then
            cat > ~/.config/rustdesk/RustDesk2.toml << 'EOF'
        rendezvous_server = '192.168.1.241:21119'
        nat_type = 1
        serial = 1
        
        [options]
        custom-rendezvous-server = '192.168.1.241:21119'
        relay-server = '192.168.1.241:21117'
        api-server = ""
        key = ""
        EOF
          fi
        fi
      ''}";
    };
  };
  
  # Git configuration
  programs.git = {
    enable = true;
    userName = "Jon Thor Kristinsson";
    userEmail = "git@jontk.com"; # TODO: Update with actual email
    
    aliases = {
      # Status and info
      st = "status -sb";
      s = "status -sb";
      ss = "status";
      info = "remote show origin";
      
      # Commits
      c = "commit";
      cm = "commit -m";
      ca = "commit -a";
      cam = "commit -am";
      amend = "commit --amend";
      ammend = "commit --amend --no-edit";
      fixup = "commit --fixup";
      
      # Branches
      b = "branch";
      ba = "branch -a";
      bd = "branch -d";
      bD = "branch -D";
      co = "checkout";
      cob = "checkout -b";
      com = "!git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')";
      sw = "switch";
      swc = "switch -c";
      
      # Logging
      l = "log --oneline --graph";
      ll = "log --oneline --graph --all";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      lp = "log --pretty=format:'%h %s' --graph";
      recent = "log --oneline -10";
      today = "log --since=midnight --oneline";
      tree = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all";
      
      # Diffs
      d = "diff";
      dc = "diff --cached";
      ds = "diff --staged";
      dw = "diff --color-words";
      dt = "difftool";
      
      # Remote
      f = "fetch";
      fa = "fetch --all --prune";
      pl = "pull";
      plr = "pull --rebase";
      ps = "push";
      psu = "push -u origin HEAD";
      psf = "push --force-with-lease";
      
      # Stash
      stash-all = "stash push --include-untracked";
      sp = "stash pop";
      sl = "stash list";
      ssp = "stash show -p";
      
      # Reset/Revert
      unstage = "reset HEAD --";
      uncommit = "reset --soft HEAD~1";
      last = "log -1 HEAD";
      undo = "reset HEAD~1 --mixed";
      hard = "reset --hard";
      
      # Rebase
      rb = "rebase";
      rbi = "rebase -i";
      rbc = "rebase --continue";
      rba = "rebase --abort";
      rbm = "!git rebase $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')";
      
      # Cherry-pick
      cp = "cherry-pick";
      cpc = "cherry-pick --continue";
      cpa = "cherry-pick --abort";
      
      # Working with remotes
      remotes = "remote -v";
      url = "remote get-url origin";
      open = "!open $(git remote get-url origin | sed 's/git@github.com:/https:\\/\\/github.com\\//g' | sed 's/.git$//')";
      pr = "!open $(git remote get-url origin | sed 's/git@github.com:/https:\\/\\/github.com\\//g' | sed 's/.git$//')/pull/new/$(git branch --show-current)";
      
      # Search
      grep = "grep -n";
      find = "!git ls-files | grep -i";
      
      # Submodules
      sub = "submodule";
      subi = "submodule init";
      subu = "submodule update";
      subp = "submodule foreach git pull origin master";
      
      # Workflow
      wip = "!git add -A && git commit -m 'WIP'";
      unwip = "!git log -1 --oneline | grep -q 'WIP' && git reset HEAD~1";
      save = "!git add -A && git commit -m 'SAVEPOINT'";
      
      # Show/Info
      show-files = "show --pretty='' --name-only";
      show-last = "show --stat";
      contributors = "shortlog --summary --numbered";
      filehistory = "log --follow -p --";
      
      # Maintenance
      cleanup = "!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d";
      prune-branches = "!git remote prune origin && git branch -vv | grep ': gone]' | grep -v '\\*' | awk '{ print $1; }' | xargs -r git branch -d";
      
      # Aliases
      alias = "!git config --get-regexp ^alias\\. | sed -e s/^alias\\.// -e s/\\ /\\ =\\ /";
    };
    
    extraConfig = {
      core = {
        editor = "nvim";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        excludesfile = "~/.gitignore_global";
        # pager is set by delta module
        autocrlf = "input";
        trustctime = false;
        precomposeunicode = false;
        untrackedCache = true;
        hooksPath = "~/.config/git/hooks";
      };
      
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
        interactive = "auto";
        grep = "auto";
        pager = true;
        decorate = "auto";
        showBranch = "auto";
      };
      
      push = {
        default = "current";
        autoSetupRemote = true;
        followTags = true;
      };
      
      pull = {
        rebase = true;
        ff = "only";
      };
      
      fetch = {
        prune = true;
        pruneTags = true;
      };
      
      diff = {
        colorMoved = "default";
        algorithm = "histogram";
        tool = "vimdiff";
        renames = "copies";
        mnemonicprefix = true;
      };
      
      merge = {
        conflictstyle = "diff3";
        tool = "vimdiff";
        ff = false;
        log = true;
      };
      
      rerere = {
        enabled = true;
        autoUpdate = true;
      };
      
      help = {
        autocorrect = 1;
      };
      
      init = {
        defaultBranch = "main";
      };
      
      branch = {
        autosetupmerge = "always";
        autosetuprebase = "always";
        sort = "-committerdate";
      };
      
      status = {
        short = true;
        branch = true;
        showStash = true;
        submoduleSummary = true;
      };
      
      log = {
        date = "relative";
        abbrevCommit = true;
        follow = true;
      };
      
      grep = {
        lineNumber = true;
        extendedRegexp = true;
      };
      
      rebase = {
        autoStash = true;
        autoSquash = true;
        abbreviateCommands = true;
      };
      
      commit = {
        verbose = true;
        gpgsign = false; # Set to true if using GPG
        template = "~/.gitmessage";
      };
      
      stash = {
        showPatch = true;
        showStat = true;
      };
      
      submodule = {
        recurse = true;
      };
      
      url = {
        "git@github.com:" = {
          insteadOf = "gh:";
          pushInsteadOf = [ "github:" "https://github.com/" ];
        };
        "git@gitlab.com:" = {
          insteadOf = "gl:";
          pushInsteadOf = [ "gitlab:" "https://gitlab.com/" ];
        };
        "git@bitbucket.org:" = {
          insteadOf = "bb:";
          pushInsteadOf = [ "bitbucket:" "https://bitbucket.org/" ];
        };
      };
      
      # Platform specific
      credential = lib.mkMerge [
        {
          helper = "${
            pkgs.git.override { withLibsecret = true; }
          }/bin/git-credential-libsecret";
        }
        (lib.mkIf isDarwin {
          helper = "osxkeychain";
        })
      ];
    };
    
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
        side-by-side = false;
        file-style = "bold yellow ul";
        file-decoration-style = "yellow box";
        hunk-header-decoration-style = "blue box";
        hunk-header-line-number-style = "purple bold";
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = "red";
        line-numbers-plus-style = "green";
        line-numbers-zero-style = "dimgray";
        minus-style = "red bold";
        minus-emph-style = "bold red 52";
        plus-style = "green bold";
        plus-emph-style = "bold green 22";
        whitespace-error-style = "reverse red";
      };
    };
    
    lfs = {
      enable = true;
    };
    
    signing = {
      key = null; # Set to your GPG key ID when ready
      signByDefault = false;
    };
    
    ignores = [
      # macOS
      ".DS_Store"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      
      # Editors
      "*.swp"
      "*.swo"
      "*~"
      ".idea/"
      ".vscode/"
      "*.sublime-workspace"
      
      # Dependencies
      "node_modules/"
      ".npm/"
      
      # Compiled files
      "*.pyc"
      "__pycache__/"
      "*.class"
      "*.o"
      "*.so"
      
      # Logs
      "*.log"
      "npm-debug.log*"
      
      # Environment
      ".env"
      ".env.local"
      
      # Build outputs
      "dist/"
      "build/"
      "out/"
      
      # Temporary files
      "*.tmp"
      "*.temp"
      ".cache/"
    ];
  };
  
  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    history = {
      size = 100000;
      save = 100000;
      path = "/home/jontk/.zsh_history";
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    
    initContent = ''
      # Load shell environment
      [[ -f ~/.config/shell/env.sh ]] && source ~/.config/shell/env.sh
      
      # Load custom shell functions
      [[ -f ~/.config/zsh/functions.sh ]] && source ~/.config/zsh/functions.sh
      
      # Load terminal-specific integration
      [[ "$TERM_PROGRAM" == "alacritty" || "$TERM" == "alacritty" ]] && [[ -f ~/.config/shell/alacritty-integration.sh ]] && source ~/.config/shell/alacritty-integration.sh
      [[ "$TERM" == "xterm-kitty" ]] && [[ -f ~/.config/shell/kitty-integration.sh ]] && source ~/.config/shell/kitty-integration.sh
      
      # Load any local configuration
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
      
      # Better history search
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      
      # macOS specific
      ${lib.optionalString isDarwin ''
        # Add Homebrew to PATH if it exists
        [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
        [[ -f /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
      ''}
      
      # Enable vi mode
      bindkey -v
      export KEYTIMEOUT=1
      
      # Better vi mode indicators
      function zle-keymap-select {
        if [[ ''${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
          echo -ne '\e[1 q'
        elif [[ ''${KEYMAP} == main ]] || [[ ''${KEYMAP} == viins ]] || [[ ''${KEYMAP} == "" ]] || [[ $1 = 'beam' ]]; then
          echo -ne '\e[5 q'
        fi
      }
      zle -N zle-keymap-select
    '';
    
    shellAliases = {
      # Directory navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      
      # ls aliases (using eza)
      ls = "eza --group-directories-first";
      ll = "eza -l --group-directories-first";
      la = "eza -la --group-directories-first";
      lt = "eza --tree --group-directories-first";
      
      # Safety nets
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";
      
      # Shortcuts
      g = "git";
      v = "nvim";
      e = "emacs";
      
      # Nix shortcuts
      ns = "nix-shell";
      nb = "nix build";
      ne = "nix-env";
      nq = "nix-env -q";
      
      # System info
      myip = "curl http://ipecho.net/plain; echo";
      ps = "procs";
      
    } // lib.optionalAttrs isNixOS {
      # RustDesk with local server
      rustdesk = "rustdesk-local";
      
    } // lib.optionalAttrs isDarwin {
      # macOS specific
      showfiles = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder";
      hidefiles = "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder";
      
      # Homebrew
      brewup = "brew update && brew upgrade && brew cleanup";
      brewinfo = "brew info";
      brewsearch = "brew search";
    };
    
    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.8.0";
          sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
        };
      }
    ];
  };
  
  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    
    settings = {
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$python"
        "$nodejs"
        "$rust"
        "$golang"
        "$character"
      ];
      
      directory = {
        style = "blue bold";
        format = "[$path]($style) ";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      
      character = {
        success_symbol = "[➜](bold green) ";
        error_symbol = "[✗](bold red) ";
        vicmd_symbol = "[V](bold green) ";
      };
      
      git_branch = {
        format = "[$branch]($style) ";
        style = "purple bold";
      };
      
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "red bold";
      };
      
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "yellow bold";
      };
      
      python = {
        format = "[$symbol$version]($style) ";
        style = "yellow bold";
      };
      
      nodejs = {
        format = "[$symbol$version]($style) ";
        style = "green bold";
      };
      
      rust = {
        format = "[$symbol$version]($style) ";
        style = "red bold";
      };
      
      golang = {
        format = "[$symbol$version]($style) ";
        style = "cyan bold";
      };
    };
  };
  
  # Direnv
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
    
    config = {
      global = {
        load_dotenv = true;
        strict_env = false;
        warn_timeout = "30s";
      };
      whitelist = {
        prefix = [
          "$HOME/src"
          "$HOME/Projects"
        ];
      };
    };
  };
  
  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    historyControl = [ "erasedups" "ignoredups" "ignorespace" ];
    historyFile = "$HOME/.bash_history";
    historyFileSize = 100000;
    historySize = 10000;
    
    initExtra = ''
      # Load shell environment
      [[ -f ~/.config/shell/env.sh ]] && source ~/.config/shell/env.sh
      
      # Load custom shell functions
      [[ -f ~/.config/zsh/functions.sh ]] && source ~/.config/zsh/functions.sh
      
      # Load terminal-specific integration
      [[ "$TERM_PROGRAM" == "alacritty" || "$TERM" == "alacritty" ]] && [[ -f ~/.config/shell/alacritty-integration.sh ]] && source ~/.config/shell/alacritty-integration.sh
      [[ "$TERM" == "xterm-kitty" ]] && [[ -f ~/.config/shell/kitty-integration.sh ]] && source ~/.config/shell/kitty-integration.sh
      
      # Better history search
      bind '"\e[A": history-search-backward'
      bind '"\e[B": history-search-forward'
      
      # Enable vi mode
      set -o vi
      
      # Prompt command
      PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
      
      # Load local configuration
      [[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
      
      # macOS specific
      ${lib.optionalString isDarwin ''
        # Add Homebrew to PATH if it exists
        [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
        [[ -f /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
      ''}
    '';
    
    shellAliases = config.programs.zsh.shellAliases; # Use same aliases as zsh
  };
  
  # fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
    
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    ];
    
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --level=2 {}'"
    ];
  };
  
  # Bat (better cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "Dracula";
      style = "numbers,changes,header";
    };
  };
  
  # Eza (better ls)
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };
  
  # Zoxide (better cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  
  # Tmux
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 10000;
    keyMode = "vi";
    mouse = true;
    sensibleOnTop = true;
    terminal = "screen-256color";
    
    extraConfig = ''
      # Prefix key
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix
      
      # True color support
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",*256col*:Tc"
      set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
      set-environment -g COLORTERM "truecolor"
      
      # Split panes
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %
      
      # Navigate panes (vim-tmux-navigator handles this)
      # Smart pane switching with awareness of Vim splits.
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
      
      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
      
      # Fallback navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      
      # Resize panes
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5
      
      # Windows
      bind c new-window -c "#{pane_current_path}"
      bind -r C-h previous-window
      bind -r C-l next-window
      bind Space last-window
      
      # Window management
      bind w choose-window
      bind s choose-session
      bind r command-prompt -I "#{window_name}" "rename-window '%%'"
      bind R command-prompt -I "#{session_name}" "rename-session '%%'"
      
      # Session management
      bind-key C-j switch-client -n
      bind-key C-k switch-client -p
      
      # Copy mode improvements
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi V send-keys -X select-line
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi Escape send-keys -X cancel
      
      # Search improvements
      bind-key / copy-mode \; send-key ?
      bind-key ? copy-mode \; send-key /
      
      # Clipboard integration
      ${lib.optionalString isDarwin ''
        bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
        bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
      ''}
      ${lib.optionalString (!isDarwin) ''
        bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
        bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
      ''}
      
      # Quick reload
      bind R source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
      
      # Sync panes
      bind e setw synchronize-panes
      
      # Zoom current pane
      bind f resize-pane -Z
      
      # Status bar configuration
      set -g status-position bottom
      set -g status-justify left
      set -g status-style bg=colour234,fg=colour137,dim
      set -g status-left '#[fg=colour233,bg=colour245,bold] #S #[fg=colour245,bg=colour234,nobold]'
      set -g status-right '#[fg=colour233,bg=colour245] %d/%m #[fg=colour233,bg=colour245] %H:%M:%S '
      set -g status-right-length 50
      set -g status-left-length 40
      
      # Window status
      setw -g window-status-current-style fg=colour81,bg=colour238,bold
      setw -g window-status-current-format ' #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
      setw -g window-status-style fg=colour138,bg=colour235,none
      setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '
      
      # Pane borders
      set -g pane-border-style fg=colour238,bg=colour235
      set -g pane-active-border-style fg=colour51,bg=colour236
      
      # Messages
      set -g message-style fg=colour232,bg=colour166,bold
      
      # Activity monitoring
      setw -g monitor-activity on
      set -g visual-activity on
      setw -g window-status-activity-style fg=colour154,bg=colour235
      
      # Mouse mode improvements
      set -g mouse on
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M
      
      # Don't rename windows automatically
      set-option -g allow-rename off
      
      # Start windows and panes at 1
      set -g base-index 1
      setw -g pane-base-index 1
      
      # Renumber windows when one is closed
      set -g renumber-windows on
      
      # Aggressive resize
      setw -g aggressive-resize on
      
      # Fix SSH agent when tmux is detached
      setenv -g SSH_AUTH_SOCK $HOME/.ssh/ssh_auth_sock
    '';
    
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      pain-control
      sessionist
      vim-tmux-navigator
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-strategy-vim 'session'
          ${lib.optionalString isDarwin ''
            set -g @resurrect-processes 'ssh mosh nvim vim emacs node python'
          ''}
          ${lib.optionalString (!isDarwin) ''
            set -g @resurrect-processes 'ssh mosh nvim vim emacs node python'
          ''}
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
          set -g @continuum-boot 'on'
          ${lib.optionalString isDarwin ''
            set -g @continuum-boot-options 'alacritty,fullscreen'
          ''}
        '';
      }
      {
        plugin = tmux-fzf;
        extraConfig = ''
          # FZF integration
          set -g @tmux-fzf-launch-key 'C-f'
        '';
      }
    ];
  };
  
  # SSH configuration
  programs.ssh = {
    enable = true;
    compression = true;
    controlMaster = "auto";
    controlPath = "~/.ssh/control-%C";
    controlPersist = "10m";
    
    extraConfig = ''
      # General SSH configuration
      AddKeysToAgent yes
      ${lib.optionalString isDarwin "UseKeychain yes"}
      IdentitiesOnly yes
      
      # GitHub
      Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        
      # GitLab
      Host gitlab.com
        HostName gitlab.com
        User git
        IdentityFile ~/.ssh/id_ed25519
    '';
  };
  
  # GPG configuration
  programs.gpg = {
    enable = true;
    settings = {
      use-agent = true;
      default-key = ""; # TODO: Set your GPG key ID
    };
  };
  
  # Services configuration
  services = lib.mkMerge [
    # GPG agent for Linux (macOS uses gpg-agent from gnupg)
    (lib.mkIf (!isDarwin) {
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        pinentry.package = pkgs.pinentry-gtk2;
      };
    })
    
    # macOS-specific services
    (lib.mkIf isDarwin {
      # Example: syncthing could be configured here
      # syncthing = {
      #   enable = true;
      # };
    })
    
    # NixOS-specific services
    (lib.mkIf (!isDarwin) {
      # Notification system with dunst
      dunst = {
        enable = true;
        iconTheme = {
          name = "Dracula";
          package = pkgs.dracula-icon-theme;
          size = "32x32";
        };
        settings = {
          global = {
            monitor = 0;
            follow = "mouse";
            width = 350;
            height = 300;
            origin = "top-right";
            offset = "10x50";
            scale = 0;
            notification_limit = 5;
            progress_bar = true;
            progress_bar_height = 10;
            progress_bar_frame_width = 1;
            progress_bar_min_width = 150;
            progress_bar_max_width = 300;
            indicate_hidden = "yes";
            shrink = "no";
            transparency = 0;
            separator_height = 2;
            padding = 8;
            horizontal_padding = 8;
            text_icon_padding = 0;
            frame_width = 2;
            frame_color = "#282a36";
            separator_color = "frame";
            sort = "yes";
            idle_threshold = 120;
            font = "JetBrains Mono 10";
            line_height = 0;
            markup = "full";
            format = "<b>%s</b>\\n%b";
            alignment = "left";
            vertical_alignment = "center";
            show_age_threshold = 60;
            word_wrap = "yes";
            ellipsize = "middle";
            ignore_newline = "no";
            stack_duplicates = true;
            hide_duplicate_count = false;
            show_indicators = "yes";
            icon_position = "left";
            min_icon_size = 0;
            max_icon_size = 32;
            sticky_history = "yes";
            history_length = 20;
            dmenu = "rofi -dmenu -p dunst:";
            browser = "firefox";
            always_run_script = true;
            title = "Dunst";
            class = "Dunst";
            corner_radius = 8;
            ignore_dbusclose = false;
            force_xinerama = false;
            mouse_left_click = "close_current";
            mouse_middle_click = "do_action, close_current";
            mouse_right_click = "close_all";
          };
          
          urgency_low = {
            background = "#282a36";
            foreground = "#f8f8f2";
            timeout = 10;
          };
          
          urgency_normal = {
            background = "#282a36";
            foreground = "#f8f8f2";
            timeout = 10;
          };
          
          urgency_critical = {
            background = "#ff5555";
            foreground = "#f8f8f2";
            frame_color = "#ff5555";
            timeout = 0;
          };
        };
      };
    })
  ];
  
  # Readline configuration
  programs.readline = {
    enable = true;
    extraConfig = ''
      set editing-mode vi
      set show-mode-in-prompt on
      set vi-ins-mode-string \1\e[6 q\2
      set vi-cmd-mode-string \1\e[2 q\2
      set completion-ignore-case on
      set completion-prefix-display-length 3
      set mark-symlinked-directories on
      set show-all-if-ambiguous on
      set show-all-if-unmodified on
      set visible-stats on
    '';
  };
  
  # htop
  programs.htop = {
    enable = true;
    settings = {
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      highlight_base_name = true;
      show_program_path = false;
      tree_view = true;
    };
  };
  
  # Alacritty terminal emulator
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 10;
          y = 10;
        };
        decorations = if isDarwin then "buttonless" else "full";
        opacity = 0.95;
        startup_mode = "Windowed";
        dynamic_title = true;
      };
      
      scrolling = {
        history = 10000;
        multiplier = 3;
      };
      
      font = {
        normal = {
          family = "FiraCode Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "FiraCode Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "FiraCode Nerd Font";
          style = "Italic";
        };
        bold_italic = {
          family = "FiraCode Nerd Font";
          style = "Bold Italic";
        };
        size = 14.0;
      };
      
      colors = {
        primary = {
          background = "#282a36";
          foreground = "#f8f8f2";
          bright_foreground = "#ffffff";
        };
        cursor = {
          text = "CellBackground";
          cursor = "CellForeground";
        };
        selection = {
          text = "CellForeground";
          background = "#44475a";
        };
        normal = {
          black   = "#21222c";
          red     = "#ff5555";
          green   = "#50fa7b";
          yellow  = "#f1fa8c";
          blue    = "#bd93f9";
          magenta = "#ff79c6";
          cyan    = "#8be9fd";
          white   = "#f8f8f2";
        };
        bright = {
          black   = "#6272a4";
          red     = "#ff6e6e";
          green   = "#69ff94";
          yellow  = "#ffffa5";
          blue    = "#d6acff";
          magenta = "#ff92df";
          cyan    = "#a4ffff";
          white   = "#ffffff";
        };
      };
      
      cursor = {
        style = {
          shape = "Block";
          blinking = "On";
        };
        vi_mode_style = "None";
        blink_interval = 750;
        unfocused_hollow = true;
      };
      
      live_config_reload = true;
      
      shell = {
        program = "${pkgs.zsh}/bin/zsh";
        args = [ "-l" ];
      };
      
      mouse = {
        hide_when_typing = true;
      };
      
      key_bindings = [
        # Vi mode
        { key = "Space"; mods = "Control|Shift"; mode = "~Search"; action = "ToggleViMode"; }
        { key = "Escape"; mode = "Vi|~Search"; action = "ClearSelection"; }
        
        # Tmux integration
        { key = "A"; mods = "Control"; chars = "\\x01"; }
        { key = "D"; mods = "Control"; chars = "\\x01\\x64"; }
        { key = "T"; mods = "Control|Shift"; chars = "\\x01\\x63"; }
      ] ++ lib.optionals isDarwin [
        # macOS specific bindings
        { key = "K"; mods = "Command"; action = "ClearHistory"; }
        { key = "V"; mods = "Command"; action = "Paste"; }
        { key = "C"; mods = "Command"; action = "Copy"; }
        { key = "Q"; mods = "Command"; action = "Quit"; }
        { key = "N"; mods = "Command"; action = "SpawnNewInstance"; }
        { key = "Return"; mods = "Command"; action = "ToggleFullscreen"; }
        { key = "Plus"; mods = "Command"; action = "IncreaseFontSize"; }
        { key = "Minus"; mods = "Command"; action = "DecreaseFontSize"; }
        { key = "Equals"; mods = "Command"; action = "ResetFontSize"; }
      ];
    };
  };
  
  # Kitty terminal emulator
  programs.kitty = {
    enable = true;
    font = {
      name = "FiraCode Nerd Font";
      size = 14;
    };
    
    theme = "Dracula";
    
    settings = {
      # Window layout
      remember_window_size = true;
      initial_window_width = "120c";
      initial_window_height = "40c";
      window_padding_width = 5;
      hide_window_decorations = if isDarwin then "titlebar-only" else "no";
      background_opacity = "0.95";
      
      # Scrollback
      scrollback_lines = 10000;
      
      # Mouse
      mouse_hide_wait = "3.0";
      url_style = "curly";
      
      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
      
      # Bell
      enable_audio_bell = false;
      visual_bell_duration = "0.0";
      
      # Tab bar
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_bar_min_tabs = 2;
      
      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = 0;
      
      # macOS specific
    } // lib.optionalAttrs isDarwin {
      macos_option_as_alt = true;
      macos_quit_when_last_window_closed = true;
      macos_window_resizable = true;
      macos_thicken_font = 0;
      macos_traditional_fullscreen = false;
      macos_show_window_title_in = "all";
      macos_titlebar_color = "background";
    };
    
    keybindings = lib.mkMerge [
      {
        # Common keybindings
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";
        "ctrl+shift+n" = "new_os_window";
        "ctrl+shift+w" = "close_window";
        "ctrl+shift+enter" = "new_window";
        "ctrl+shift+t" = "new_tab";
        "ctrl+shift+q" = "close_tab";
        "ctrl+shift+]" = "next_tab";
        "ctrl+shift+[" = "previous_tab";
        "ctrl+shift+l" = "next_layout";
        "ctrl+shift+." = "move_tab_forward";
        "ctrl+shift+," = "move_tab_backward";
        "ctrl+shift+alt+t" = "set_tab_title";
        
        # Window management
        "ctrl+shift+right" = "next_window";
        "ctrl+shift+left" = "previous_window";
        "ctrl+shift+f" = "move_window_forward";
        "ctrl+shift+b" = "move_window_backward";
        "ctrl+shift+`" = "move_window_to_top";
        "ctrl+shift+r" = "start_resizing_window";
        
        # Font sizes
        "ctrl+shift+equal" = "change_font_size all +2.0";
        "ctrl+shift+minus" = "change_font_size all -2.0";
        "ctrl+shift+backspace" = "change_font_size all 0";
        
        # Scrolling
        "ctrl+shift+k" = "scroll_line_up";
        "ctrl+shift+j" = "scroll_line_down";
        "ctrl+shift+page_up" = "scroll_page_up";
        "ctrl+shift+page_down" = "scroll_page_down";
        "ctrl+shift+home" = "scroll_home";
        "ctrl+shift+end" = "scroll_end";
      }
      (lib.mkIf isDarwin {
        # macOS specific keybindings
        "cmd+c" = "copy_to_clipboard";
        "cmd+v" = "paste_from_clipboard";
        "cmd+n" = "new_os_window";
        "cmd+w" = "close_window";
        "cmd+enter" = "toggle_fullscreen";
        "cmd+t" = "new_tab";
        "cmd+shift+t" = "new_tab_with_cwd";
        "cmd+]" = "next_tab";
        "cmd+[" = "previous_tab";
        "cmd+equal" = "change_font_size all +2.0";
        "cmd+minus" = "change_font_size all -2.0";
        "cmd+0" = "change_font_size all 0";
        
        # Tab navigation
        "cmd+1" = "goto_tab 1";
        "cmd+2" = "goto_tab 2";
        "cmd+3" = "goto_tab 3";
        "cmd+4" = "goto_tab 4";
        "cmd+5" = "goto_tab 5";
        "cmd+6" = "goto_tab 6";
        "cmd+7" = "goto_tab 7";
        "cmd+8" = "goto_tab 8";
        "cmd+9" = "goto_tab 9";
      })
    ];
    
    extraConfig = ''
      # Additional configuration
      
      # Layouts
      enabled_layouts tall:bias=50;full_size=1;mirrored=false,grid,horizontal,vertical
      
      # Advanced
      allow_remote_control yes
      listen_on unix:/tmp/kitty
      
      # Shell integration
      shell_integration enabled
      
      # Terminal bell
      window_alert_on_bell yes
      
      # Color scheme overrides (if needed)
      # include ./theme.conf
      
      # Local overrides
      include ./kitty.local.conf
    '';
  };
  
  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      # Theme
      dracula-vim
      
      # UI enhancements
      vim-airline
      vim-airline-themes
      vim-devicons
      nerdtree
      nerdtree-git-plugin
      tagbar
      vim-gitgutter
      vim-fugitive
      vim-rhubarb
      gitsigns-nvim
      
      # Language support
      vim-nix
      vim-markdown
      vim-json
      vim-yaml
      vim-toml
      rust-vim
      vim-go
      vim-python-pep8-indent
      typescript-vim
      vim-jsx-pretty
      
      # Completion and snippets
      coc-nvim
      coc-json
      coc-yaml
      coc-pyright
      coc-rust-analyzer
      coc-tsserver
      coc-go
      coc-snippets
      vim-snippets
      
      # Text manipulation
      vim-surround
      vim-commentary
      vim-repeat
      vim-easy-align
      auto-pairs
      
      # Search and navigation
      fzf-vim
      vim-easymotion
      vim-smoothie
      
      # Tmux integration
      vim-tmux-navigator
      
      # Additional tools
      vim-lastplace
      vim-multiple-cursors
      indentLine
      rainbow
      vim-highlightedyank
      
      # LSP and treesitter (for Neovim)
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects
      trouble-nvim
      telescope-nvim
      plenary-nvim
    ];
    
    extraConfig = ''
      " Source the existing init.vim
      source ~/.config/nvim/init.vim
      
      " Additional configuration
      
      " Theme
      colorscheme dracula
      let g:airline_theme='dracula'
      let g:airline_powerline_fonts = 1
      
      " NERDTree
      nnoremap <leader>n :NERDTreeToggle<CR>
      nnoremap <leader>f :NERDTreeFind<CR>
      let NERDTreeShowHidden=1
      let NERDTreeIgnore=['\.pyc$', '\~$', '\.swp$', '\.git$', 'node_modules']
      
      " FZF
      nnoremap <C-p> :Files<CR>
      nnoremap <leader>b :Buffers<CR>
      nnoremap <leader>rg :Rg<CR>
      nnoremap <leader>t :Tags<CR>
      nnoremap <leader>m :Marks<CR>
      
      " CoC configuration
      let g:coc_global_extensions = [
        \ 'coc-json',
        \ 'coc-yaml',
        \ 'coc-python',
        \ 'coc-rust-analyzer',
        \ 'coc-tsserver',
        \ 'coc-go',
        \ 'coc-snippets',
        \ ]
      
      " Use tab for trigger completion
      inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ coc#refresh()
      inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
      
      function! s:check_back_space() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~# '\s'
      endfunction
      
      " GoTo code navigation
      nmap <silent> gd <Plug>(coc-definition)
      nmap <silent> gy <Plug>(coc-type-definition)
      nmap <silent> gi <Plug>(coc-implementation)
      nmap <silent> gr <Plug>(coc-references)
      
      " Show documentation
      nnoremap <silent> K :call <SID>show_documentation()<CR>
      
      function! s:show_documentation()
        if (index(['vim','help'], &filetype) >= 0)
          execute 'h '.expand('<cword>')
        else
          call CocActionAsync('doHover')
        endif
      endfunction
      
      " Tmux navigator
      let g:tmux_navigator_no_mappings = 1
      nnoremap <silent> <C-h> :TmuxNavigateLeft<cr>
      nnoremap <silent> <C-j> :TmuxNavigateDown<cr>
      nnoremap <silent> <C-k> :TmuxNavigateUp<cr>
      nnoremap <silent> <C-l> :TmuxNavigateRight<cr>
      
      " Easy align
      xmap ga <Plug>(EasyAlign)
      nmap ga <Plug>(EasyAlign)
      
      " GitGutter
      let g:gitgutter_sign_added = '+'
      let g:gitgutter_sign_modified = '~'
      let g:gitgutter_sign_removed = '-'
      nmap ]h <Plug>(GitGutterNextHunk)
      nmap [h <Plug>(GitGutterPrevHunk)
      
      " Lua configuration for Neovim-specific plugins
      lua << EOF
      -- Treesitter configuration
      require'nvim-treesitter.configs'.setup {
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      }
      
      -- Telescope configuration
      local telescope = require('telescope')
      telescope.setup{
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            },
          },
        },
      }
      
      -- Gitsigns
      require('gitsigns').setup()
      EOF
    '';
    
    extraPackages = with pkgs; [
      # Language servers
      nodePackages.typescript-language-server
      pyright
      rust-analyzer
      gopls
      lua-language-server
      nil # Nix language server
      
      # Formatters
      nixpkgs-fmt
      rustfmt
      black
      prettier
      # gofmt is included with go package
      
      # Additional tools
      ripgrep
      fd
      bat
      tree-sitter
    ];
  };
  
  
  # XDG directories
  xdg = {
    enable = true;
    # Use hardcoded paths since config.home.homeDirectory is not available in this context
    configHome = "/home/jontk/.config";
    dataHome = "/home/jontk/.local/share";
    cacheHome = "/home/jontk/.cache";
    stateHome = "/home/jontk/.local/state";
    
    # Desktop entries for applications (NixOS only)
  } // lib.optionalAttrs (!isDarwin) {
    desktopEntries = {
      "tmux-session" = {
        name = "Tmux Development Session";
        comment = "Start a new tmux development session";
        exec = "alacritty -e tmux new-session -s development";
        icon = "utilities-terminal";
        categories = [ "Development" "System" ];
      };
      
      "quick-edit" = {
        name = "Quick Edit";
        comment = "Quick file editor with Neovim";
        exec = "alacritty -e nvim";
        icon = "text-editor";
        categories = [ "Development" "TextEditor" ];
      };
      
      "project-browser" = {
        name = "Project Browser";
        comment = "Browse projects with file manager";
        exec = "thunar /home/jontk/projects";
        icon = "folder-development";
        categories = [ "Development" "FileManager" ];
      };
      
      "system-monitor" = {
        name = "System Monitor";
        comment = "Monitor system resources with btop";
        exec = "alacritty -e btop";
        icon = "utilities-system-monitor";
        categories = [ "System" "Monitor" ];
      };
    };
    
    # User directories configuration
    userDirs = {
      enable = true;
      desktop = "/home/jontk/Desktop";
      documents = "/home/jontk/Documents";
      download = "/home/jontk/Downloads";
      music = "/home/jontk/Music";
      pictures = "/home/jontk/Pictures";
      videos = "/home/jontk/Videos";
      # Development directories
      templates = "/home/jontk/Templates";
      publicShare = "/home/jontk/Public";
    };
    
    # MIME type associations
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = "nvim.desktop";
        "text/x-markdown" = "nvim.desktop";
        "text/x-shellscript" = "nvim.desktop";
        "application/json" = "nvim.desktop";
        "application/x-yaml" = "nvim.desktop";
        "text/x-python" = "nvim.desktop";
        "text/x-rust" = "nvim.desktop";
        "text/x-go" = "nvim.desktop";
        "text/x-javascript" = "nvim.desktop";
        "text/x-typescript" = "nvim.desktop";
        "text/html" = "nvim.desktop";
        "text/css" = "nvim.desktop";
        "application/pdf" = "firefox.desktop";
        "text/uri-list" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "image/jpeg" = "feh.desktop";
        "image/png" = "feh.desktop";
        "image/gif" = "feh.desktop";
        "image/webp" = "feh.desktop";
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "audio/mpeg" = "mpv.desktop";
        "audio/flac" = "mpv.desktop";
        "inode/directory" = "thunar.desktop";
      };
    };
  };
  
  # Create dotfiles structure
  home.file = {
    # Directory structure
    ".config/nvim/.keep".text = "";
    ".config/emacs/.keep".text = "";
    ".local/bin/.keep".text = "";
    
    # Terminal emulator configurations are now managed by programs.alacritty and programs.kitty
    
    # Neovim configuration
    ".config/nvim/init.vim".source = ./dotfiles/init.vim;
    
    # Tmux additional configuration
    ".tmux.conf.local" = {
      source = ./dotfiles/tmux.conf;
      onChange = ''
        ${pkgs.tmux}/bin/tmux source-file ~/.tmux.conf 2>/dev/null || true
      '';
    };
    
    # Git global ignore
    ".gitignore_global".source = ./dotfiles/gitignore_global;
    
    # Starship extended configuration
    ".config/starship-extended.toml".source = ./dotfiles/starship.toml;
    
    # Shell functions
    ".config/zsh/functions.sh".source = ./dotfiles/shell_functions.sh;
    
    # Shell environment
    ".config/shell/env.sh".source = ./dotfiles/shell_env.sh;
    
    # Direnv configuration
    ".config/direnv/direnvrc".source = ./dotfiles/direnvrc;
    
    # Terminal emulator integrations
    ".config/shell/alacritty-integration.sh".source = ./dotfiles/alacritty-integration.sh;
    ".config/shell/kitty-integration.sh".source = ./dotfiles/kitty-integration.sh;
    
    # Git configuration files
    ".gitmessage".source = ./dotfiles/gitmessage.txt;
    ".config/git/hooks/pre-commit" = {
      source = ./dotfiles/git-hooks/pre-commit;
      executable = true;
    };
    
    # Swaylock configuration
    ".config/swaylock/config" = lib.mkIf isNixOS {
      text = ''
        color=000000
        inside-color=1e1e1e
        ring-color=33ccff
        key-hl-color=00ff99
        line-color=000000
        separator-color=000000
        text-color=ffffff
        
        indicator-radius=100
        indicator-thickness=10
        
        effect-blur=7x5
        effect-vignette=0.5:0.5
        
        clock
        timestr=%H:%M
        datestr=%A, %Y-%m-%d
        
        fade-in=0.2
      '';
    };
    
    # Hyprlock configuration
    ".config/hypr/hyprlock.conf" = lib.mkIf isNixOS {
      text = ''
        background {
            monitor =
            path = screenshot
            blur_size = 5
            blur_passes = 2
        }

        input-field {
            monitor =
            size = 200, 50
            outline_thickness = 3
            dots_size = 0.33 # Scale of input-field height, 0.2 - 0.8
            dots_spacing = 0.15 # Scale of dots' absolute size, 0.0 - 1.0
            dots_center = true
            outer_color = rgb(151515)
            inner_color = rgb(200, 200, 200)
            font_color = rgb(10, 10, 10)
            fade_on_empty = true
            placeholder_text = <i>Password...</i>
            hide_input = false
            position = 0, -20
            halign = center
            valign = center
        }

        label {
            monitor =
            text = $TIME
            color = rgba(200, 200, 200, 1.0)
            font_size = 55
            font_family = Noto Sans
            position = 0, 80
            halign = center
            valign = center
        }
      '';
    };
    
    # Hyprland user configuration
    ".config/hypr/hyprland.conf" = lib.mkIf isNixOS {
      text = ''
        # User-specific Hyprland configuration
        # This configuration extends the system default
        
        # Source the system configuration
        source = /etc/hypr/hyprland.conf
        
        # VM-specific fixes
        env = WLR_NO_HARDWARE_CURSORS,1
        env = WLR_RENDERER,pixman
        env = LIBSEAT_BACKEND,logind
        
        # Simplified monitor config for VM
        monitor=,preferred,auto,1
        
        # Disable some effects for better VM performance
        decoration {
            blur {
                enabled = false
            }
            shadow {
                enabled = false
            }
        }
        
        # Simpler animations for VM
        animations {
            enabled = false
        }
        
        # Add your personal customizations below
        # Example: Custom keybindings, window rules, monitor setup, etc.
        
        # Override lock command to use swaylock (more reliable in VM)
        bind = $mainMod, L, exec, swaylock -c 000000
        
        # Personal keybindings
        # bind = $mainMod SHIFT, Return, exec, alacritty
        
        # Personal window rules
        # windowrulev2 = workspace 2,class:^(firefox)$
        # windowrulev2 = workspace 3,class:^(code)$
        
        # Personal startup applications
        # exec-once = firefox
        # exec-once = discord
      '';
    };
    
    # Custom scripts
    ".local/bin/update-system" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -e
        
        echo "Updating Nix flake..."
        cd /home/jontk/src/github.com/jontk/nixconf
        nix flake update
        
        echo "Rebuilding system..."
        ${if isDarwin then "darwin-rebuild switch --flake ." else "sudo nixos-rebuild switch --flake ."}
        
        echo "System update complete!"
      '';
    };
    
    ".local/bin/clean-system" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -e
        
        echo "Collecting garbage..."
        nix-collect-garbage -d
        ${if isDarwin then "" else "sudo nix-collect-garbage -d"}
        
        echo "Optimizing store..."
        nix-store --optimise
        
        echo "System cleanup complete!"
      '';
    };
  };
  
  # Activation scripts removed for compatibility - directories will be created by file management
  
  # macOS-specific programs
  programs.vscode = lib.mkIf isDarwin {
    enable = true;
    userSettings = {
      "editor.fontFamily" = "FiraCode Nerd Font";
      "editor.fontLigatures" = true;
      "editor.fontSize" = 14;
      "editor.tabSize" = 2;
      "editor.insertSpaces" = true;
      "editor.detectIndentation" = true;
      "editor.renderWhitespace" = "boundary";
      "editor.rulers" = [ 80 120 ];
      "editor.wordWrap" = "bounded";
      "editor.wordWrapColumn" = 120;
      "editor.cursorStyle" = "line";
      "editor.lineNumbers" = "on";
      "editor.minimap.enabled" = false;
      "editor.formatOnSave" = true;
      "editor.formatOnPaste" = true;
      
      "terminal.integrated.fontFamily" = "FiraCode Nerd Font";
      "terminal.integrated.fontSize" = 14;
      "terminal.integrated.shell.osx" = "${pkgs.zsh}/bin/zsh";
      
      "files.autoSave" = "afterDelay";
      "files.autoSaveDelay" = 1000;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      
      "workbench.colorTheme" = "Dracula";
      "workbench.iconTheme" = "material-icon-theme";
      
      "vim.enableNeovim" = true;
      "vim.neovimPath" = "${pkgs.neovim}/bin/nvim";
      "vim.useSystemClipboard" = true;
      "vim.hlsearch" = true;
      "vim.incsearch" = true;
      "vim.useCtrlKeys" = true;
      "vim.leader" = "<space>";
      
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;
    };
    
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      dracula-theme.theme-dracula
      eamodio.gitlens
      esbenp.prettier-vscode
      golang.go
      hashicorp.terraform
      jnoortheen.nix-ide
      ms-azuretools.vscode-docker
      ms-python.python
      ms-toolsai.jupyter
      ms-vscode-remote.remote-ssh
      redhat.vscode-yaml
      rust-lang.rust-analyzer
      vscodevim.vim
    ];
  };
  
  
  # Desktop-specific configurations for NixOS
  # These settings only apply to NixOS systems with desktop environments
  gtk = lib.mkIf (!isDarwin) {
    enable = true;
    
    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
    
    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };
    
    cursorTheme = {
      name = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
      size = 24;
    };
    
    font = {
      name = "Inter";
      size = 11;
    };
    
    gtk2.extraConfig = ''
      gtk-button-images = 1
      gtk-menu-images = 1
      gtk-enable-event-sounds = 1
      gtk-enable-input-feedback-sounds = 0
      gtk-xft-antialias = 1
      gtk-xft-hinting = 1
      gtk-xft-hintstyle = "hintfull"
      gtk-xft-rgba = "rgb"
    '';
    
    gtk3.extraConfig = {
      gtk-button-images = true;
      gtk-menu-images = true;
      gtk-enable-event-sounds = true;
      gtk-enable-input-feedback-sounds = false;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintfull";
      gtk-xft-rgba = "rgb";
      gtk-application-prefer-dark-theme = true;
    };
    
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
  
  # Qt theming for NixOS
  qt = lib.mkIf (!isDarwin) {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "Dracula";
      package = pkgs.dracula-qt5-theme;
    };
  };
  
  # dconf settings for GNOME applications
  dconf = lib.mkIf (!isDarwin) {
    enable = true;
    settings = {
      # GNOME settings
      "org/gnome/desktop/interface" = {
        gtk-theme = "Dracula";
        icon-theme = "Dracula";
        cursor-theme = "breeze_cursors";
        font-name = "Inter 11";
        document-font-name = "Inter 11";
        monospace-font-name = "JetBrains Mono 10";
        color-scheme = "prefer-dark";
        enable-hot-corners = false;
      };
      
      "org/gnome/desktop/wm/preferences" = {
        titlebar-font = "Inter Bold 11";
        theme = "Dracula";
      };
      
      # Nautilus settings
      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
        search-filter-time-type = "last_modified";
        show-hidden-files = true;
      };
      
      "org/gnome/nautilus/list-view" = {
        use-tree-view = true;
        default-zoom-level = "small";
      };
      
      # Terminal settings
      "org/gnome/desktop/applications/terminal" = {
        exec = "alacritty";
      };
    };
  };
  
  
  
  
  
  
  # Wayland-specific programs configuration
  wayland.windowManager.hyprland = lib.mkIf (!isDarwin) {
    enable = true;
    settings = {
      # Monitor configuration
      monitor = [
        ",preferred,auto,1"
      ];
      
      # Input configuration
      input = {
        kb_layout = "us";
        kb_options = "caps:escape,compose:ralt";
        
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          clickfinger_behavior = true;
          scroll_factor = 1.0;
        };
        
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification
      };
      
      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(bd93f9ee) rgba(ff79c6ee) 45deg";
        "col.inactive_border" = "rgba(44475aaa)";
        
        layout = "dwindle";
        allow_tearing = false;
      };
      
      # Decoration
      decoration = {
        rounding = 8;
        
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          new_optimizations = true;
        };
        
        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };
      
      # Animations
      animations = {
        enabled = true;
        
        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
        ];
        
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      
      # Dwindle layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      
      # Master layout
      master = {
        new_status = "master";
      };
      
      # Gestures
      gestures = {
        workspace_swipe = true;
      };
      
      # Misc settings
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };
      
      # Key bindings
      bind = [
        # Application shortcuts
        "SUPER, Return, exec, alacritty"
        "SUPER, D, exec, rofi -show drun"
        "SUPER, V, exec, code"
        "SUPER, F, exec, firefox"
        "SUPER, E, exec, nautilus"
        
        # Window management
        "SUPER, Q, killactive"
        "SUPER SHIFT, Q, exit"
        "SUPER, Space, togglefloating"
        "SUPER, P, pseudo"
        "SUPER, J, togglesplit"
        "SUPER, Escape, exec, hyprlock"
        
        # Move focus
        "SUPER, h, movefocus, l"
        "SUPER, l, movefocus, r"
        "SUPER, k, movefocus, u"
        "SUPER, j, movefocus, d"
        
        # Move windows
        "SUPER SHIFT, h, movewindow, l"
        "SUPER SHIFT, l, movewindow, r"
        "SUPER SHIFT, k, movewindow, u"
        "SUPER SHIFT, j, movewindow, d"
        
        # Workspace switching
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"
        "SUPER, 0, workspace, 10"
        
        # Move window to workspace
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        "SUPER SHIFT, 6, movetoworkspace, 6"
        "SUPER SHIFT, 7, movetoworkspace, 7"
        "SUPER SHIFT, 8, movetoworkspace, 8"
        "SUPER SHIFT, 9, movetoworkspace, 9"
        "SUPER SHIFT, 0, movetoworkspace, 10"
        
        # Special workspace (scratchpad)
        "SUPER, S, togglespecialworkspace, magic"
        "SUPER SHIFT, S, movetoworkspace, special:magic"
        
        # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"
        
        # Audio control
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        
        # Brightness control
        ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];
      
      # Mouse bindings
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
      
      # Window rules
      windowrule = [
        "float, ^(pavucontrol)$"
        "float, ^(nm-applet)$"
        "float, ^(blueman-manager)$"
        "float, ^(gnome-calculator)$"
        "float, ^(gnome-weather)$"
        "float, ^(file-roller)$"
        "center, ^(file-roller)$"
      ];
      
      # Exec once (startup applications)
      exec-once = [
        "waybar"
        "dunst"
        "hyprpaper"
        "hypridle"
        "nm-applet"
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
        "gnome-keyring-daemon --start --components=secrets,ssh,pkcs11"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];
    };
  };
  
  # Waybar configuration for status bar
  programs.waybar = lib.mkIf (!isDarwin) {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 35;
        spacing = 4;
        
        modules-left = [ "hyprland/workspaces" "hyprland/mode" "hyprland/scratchpad" "custom/media" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "temperature" "backlight" "keyboard-state" "battery" "clock" "tray" ];
        
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            "urgent" = "";
            "focused" = "";
            "default" = "";
          };
        };
        
        keyboard-state = {
          numlock = true;
          capslock = true;
          format = "{name} {icon}";
          format-icons = {
            locked = "";
            unlocked = "";
          };
        };
        
        "hyprland/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };
        
        "hyprland/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = [ "" "" ];
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };
        
        tray = {
          spacing = 10;
        };
        
        clock = {
          timezone = "America/New_York";
          tooltip-format = "<big>{:%Y %B}</big>\\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
        };
        
        cpu = {
          format = "{usage}% ";
          tooltip = false;
        };
        
        memory = {
          format = "{}% ";
        };
        
        temperature = {
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-icons = [ "" "" "" ];
        };
        
        backlight = {
          format = "{percent}% {icon}";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
        };
        
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        
        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ipaddr}/{cidr} ";
          tooltip-format = "{ifname} via {gwaddr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        
        pulseaudio = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
        
        "custom/media" = {
          format = "{icon} {}";
          return-type = "json";
          max-length = 40;
          format-icons = {
            spotify = "";
            default = "🎜";
          };
          escape = true;
          exec = "$HOME/.config/waybar/mediaplayer.py 2> /dev/null";
        };
      };
    };
    
    style = ''
      * {
        font-family: "JetBrains Mono", "Font Awesome 6 Free", "Font Awesome 6 Brands";
        font-size: 13px;
      }
      
      window#waybar {
        background-color: rgba(40, 42, 54, 0.9);
        border-bottom: 3px solid rgba(189, 147, 249, 0.8);
        color: #f8f8f2;
        transition-property: background-color;
        transition-duration: .5s;
      }
      
      window#waybar.hidden {
        opacity: 0.2;
      }
      
      button {
        box-shadow: inset 0 -3px transparent;
        border: none;
        border-radius: 0;
      }
      
      button:hover {
        background: inherit;
        box-shadow: inset 0 -3px #f8f8f2;
      }
      
      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #f8f8f2;
      }
      
      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
      }
      
      #workspaces button.focused {
        background-color: #44475a;
        box-shadow: inset 0 -3px #bd93f9;
      }
      
      #workspaces button.urgent {
        background-color: #ff5555;
      }
      
      #mode {
        background-color: #bd93f9;
        color: #282a36;
        border-bottom: 3px solid #f8f8f2;
      }
      
      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #tray,
      #mode,
      #idle_inhibitor,
      #scratchpad,
      #mpd {
        padding: 0 10px;
        color: #f8f8f2;
      }
      
      #window,
      #workspaces {
        margin: 0 4px;
      }
      
      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }
      
      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }
      
      #clock {
        background-color: #8be9fd;
        color: #282a36;
      }
      
      #battery {
        background-color: #50fa7b;
        color: #282a36;
      }
      
      #battery.charging, #battery.plugged {
        background-color: #50fa7b;
      }
      
      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }
      
      #battery.critical:not(.charging) {
        background-color: #ff5555;
        color: #f8f8f2;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
      
      label:focus {
        background-color: #000000;
      }
      
      #cpu {
        background-color: #ffb86c;
        color: #282a36;
      }
      
      #memory {
        background-color: #ff79c6;
        color: #282a36;
      }
      
      #disk {
        background-color: #f1fa8c;
        color: #282a36;
      }
      
      #backlight {
        background-color: #f1fa8c;
        color: #282a36;
      }
      
      #network {
        background-color: #bd93f9;
        color: #282a36;
      }
      
      #network.disconnected {
        background-color: #ff5555;
      }
      
      #pulseaudio {
        background-color: #8be9fd;
        color: #282a36;
      }
      
      #pulseaudio.muted {
        background-color: #6272a4;
        color: #f8f8f2;
      }
      
      #temperature {
        background-color: #50fa7b;
        color: #282a36;
      }
      
      #temperature.critical {
        background-color: #ff5555;
      }
      
      #tray {
        background-color: #6272a4;
      }
      
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #ff5555;
      }
      
      #idle_inhibitor {
        background-color: #44475a;
      }
      
      #idle_inhibitor.activated {
        background-color: #f8f8f2;
        color: #282a36;
      }
      
      #scratchpad {
        background-color: #6272a4;
      }
      
      #scratchpad.empty {
        background-color: transparent;
      }
    '';
  };
  
  # Secret Management System
  # This section sets up secure environment variable management
  # Secrets are loaded from external files, not stored in the Nix configuration
  
  # Create directories for secret management
  home.file.".local/share/secrets/.keep".text = "";
  home.file.".config/secrets/.keep".text = "";
  
  # Secret loading script
  home.file.".local/bin/load-secrets" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Secret loading script for secure environment variable management
      # This script loads secrets from secure files without storing them in Nix config
      
      set -euo pipefail
      
      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m'
      
      # Secret directories
      SECRETS_DIR="$HOME/.local/share/secrets"
      CONFIG_SECRETS_DIR="$HOME/.config/secrets"
      
      # Environment file to source
      ENV_FILE="$HOME/.local/share/secrets/environment"
      
      # Function to safely load environment file
      load_env_file() {
          local file="$1"
          if [[ -f "$file" && -r "$file" ]]; then
              # Check file permissions (should be 600 or 400)
              local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
              if [[ "$perms" != "600" && "$perms" != "400" ]]; then
                  echo "Warning: $file has permissive permissions ($perms)" >&2
                  echo "Consider: chmod 600 $file" >&2
              fi
              
              # Source the file
              set -a  # Mark variables for export
              source "$file"
              set +a  # Unmark variables for export
              echo -e "$${GREEN}✓ Loaded secrets from $file$${NC}" >&2
              return 0
          else
              echo -e "$${YELLOW}Warning: Secret file $file not found or not readable$${NC}" >&2
              return 1
          fi
      }
      
      # Function to load individual secret files
      load_secret_files() {
          local secrets_dir="$1"
          if [[ -d "$secrets_dir" ]]; then
              for file in "$secrets_dir"/*.env; do
                  [[ -f "$file" ]] && load_env_file "$file"
              done
          fi
      }
      
      # Create secret directories if they don't exist
      mkdir -p "$SECRETS_DIR" "$CONFIG_SECRETS_DIR"
      
      # Set secure permissions on secret directories
      chmod 700 "$SECRETS_DIR" "$CONFIG_SECRETS_DIR"
      
      # Load main environment file
      load_env_file "$ENV_FILE" || true
      
      # Load individual secret files
      load_secret_files "$SECRETS_DIR"
      load_secret_files "$CONFIG_SECRETS_DIR"
      
      # Load platform-specific secrets
      if [[ "$(uname)" == "Darwin" ]]; then
          load_env_file "$SECRETS_DIR/macos.env" || true
      else
          load_env_file "$SECRETS_DIR/linux.env" || true
      fi
      
      # Load host-specific secrets
      local hostname=$(hostname | cut -d. -f1)
      load_env_file "$SECRETS_DIR/$hostname.env" || true
      
      # Execute command with loaded environment
      if [[ $# -gt 0 ]]; then
          exec "$@"
      fi
    '';
  };
  
  # Secret template creation script
  home.file.".local/bin/init-secrets" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Initialize secret management templates
      
      set -euo pipefail
      
      SECRETS_DIR="$HOME/.local/share/secrets"
      CONFIG_SECRETS_DIR="$HOME/.config/secrets"
      
      # Create directories
      mkdir -p "$SECRETS_DIR" "$CONFIG_SECRETS_DIR"
      chmod 700 "$SECRETS_DIR" "$CONFIG_SECRETS_DIR"
      
      # Create main environment template
      if [[ ! -f "$SECRETS_DIR/environment" ]]; then
          cat > "$SECRETS_DIR/environment" << 'EOF'
      # Main environment variables for secrets
      # This file should have permissions 600: chmod 600 ~/.local/share/secrets/environment
      
      # === API KEYS ===
      # export OPENAI_API_KEY="your-openai-key"
      # export ANTHROPIC_API_KEY="your-anthropic-key"
      # export GITHUB_TOKEN="your-github-token"
      
      # === CLOUD PROVIDERS ===
      # export AWS_ACCESS_KEY_ID="your-aws-access-key"
      # export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"
      # export AWS_DEFAULT_REGION="us-west-2"
      # export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
      # export AZURE_CLIENT_ID="your-azure-client-id"
      # export AZURE_CLIENT_SECRET="your-azure-client-secret"
      # export AZURE_TENANT_ID="your-azure-tenant-id"
      
      # === DATABASE CONNECTIONS ===
      # export DATABASE_URL="postgresql://user:pass@localhost:5432/dbname"
      # export REDIS_URL="redis://localhost:6379"
      # export MONGODB_URI="mongodb://localhost:27017/dbname"
      
      # === AUTHENTICATION ===
      # export JWT_SECRET="your-jwt-secret"
      # export SESSION_SECRET="your-session-secret"
      
      # === COMMUNICATION ===
      # export SLACK_TOKEN="your-slack-token"
      # export DISCORD_TOKEN="your-discord-token"
      # export TELEGRAM_BOT_TOKEN="your-telegram-token"
      
      # === DEVELOPMENT ===
      # export DOCKER_REGISTRY_PASSWORD="your-registry-password"
      # export NPM_TOKEN="your-npm-token"
      # export PYPI_TOKEN="your-pypi-token"
      
      # === MONITORING ===
      # export DATADOG_API_KEY="your-datadog-key"
      # export NEW_RELIC_LICENSE_KEY="your-newrelic-key"
      # export SENTRY_DSN="your-sentry-dsn"
      
      EOF
          chmod 600 "$SECRETS_DIR/environment"
          echo "✓ Created $SECRETS_DIR/environment"
      fi
      
      # Create platform-specific templates
      if [[ "$(uname)" == "Darwin" && ! -f "$SECRETS_DIR/macos.env" ]]; then
          cat > "$SECRETS_DIR/macos.env" << 'EOF'
      # macOS-specific environment variables
      
      # === HOMEBREW ===
      # export HOMEBREW_GITHUB_API_TOKEN="your-github-token"
      
      # === XCODE ===
      # export FASTLANE_PASSWORD="your-apple-id-password"
      # export MATCH_PASSWORD="your-match-password"
      
      EOF
          chmod 600 "$SECRETS_DIR/macos.env"
          echo "✓ Created $SECRETS_DIR/macos.env"
      fi
      
      if [[ "$(uname)" == "Linux" && ! -f "$SECRETS_DIR/linux.env" ]]; then
          cat > "$SECRETS_DIR/linux.env" << 'EOF'
      # Linux-specific environment variables
      
      # === SYSTEM ===
      # export SUDO_PASSWORD="your-sudo-password"  # Use with caution
      
      # === DESKTOP ===
      # export DESKTOP_SESSION_TOKEN="your-session-token"
      
      EOF
          chmod 600 "$SECRETS_DIR/linux.env"
          echo "✓ Created $SECRETS_DIR/linux.env"
      fi
      
      # Create development environment template
      if [[ ! -f "$CONFIG_SECRETS_DIR/development.env" ]]; then
          cat > "$CONFIG_SECRETS_DIR/development.env" << 'EOF'
      # Development environment secrets
      
      # === LOCAL DEVELOPMENT ===
      # export DEV_DATABASE_URL="postgresql://localhost:5432/myapp_dev"
      # export TEST_DATABASE_URL="postgresql://localhost:5432/myapp_test"
      # export DEV_REDIS_URL="redis://localhost:6379/0"
      
      # === API ENDPOINTS ===
      # export API_BASE_URL="http://localhost:3000"
      # export WEBHOOK_SECRET="your-webhook-secret"
      
      # === FEATURE FLAGS ===
      # export ENABLE_DEBUG_MODE="true"
      # export ENABLE_EXPERIMENTAL_FEATURES="false"
      
      EOF
          chmod 600 "$CONFIG_SECRETS_DIR/development.env"
          echo "✓ Created $CONFIG_SECRETS_DIR/development.env"
      fi
      
      echo ""
      echo "Secret management initialized!"
      echo "Edit the files in $SECRETS_DIR to add your secrets."
      echo "Run 'load-secrets' to load secrets into your environment."
      echo "Run 'load-secrets <command>' to run a command with secrets loaded."
    '';
  };
  
  # Secret validation script
  home.file.".local/bin/check-secrets" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Check secret file security and validate configuration
      
      set -euo pipefail
      
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m'
      
      SECRETS_DIR="$HOME/.local/share/secrets"
      CONFIG_SECRETS_DIR="$HOME/.config/secrets"
      
      echo -e "$${BLUE}=== Secret Management Security Check ===$${NC}"
      echo ""
      
      # Check directory permissions
      check_directory_perms() {
          local dir="$1"
          if [[ -d "$dir" ]]; then
              local perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
              if [[ "$perms" == "700" ]]; then
                  echo -e "$${GREEN}✓ $dir has secure permissions ($perms)$${NC}"
              else
                  echo -e "$${RED}✗ $dir has insecure permissions ($perms), should be 700$${NC}"
                  echo -e "  Fix with: chmod 700 $dir"
              fi
          else
              echo -e "$${YELLOW}⚠ $dir does not exist$${NC}"
          fi
      }
      
      # Check file permissions
      check_file_perms() {
          local file="$1"
          if [[ -f "$file" ]]; then
              local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
              if [[ "$perms" == "600" || "$perms" == "400" ]]; then
                  echo -e "$${GREEN}✓ $file has secure permissions ($perms)$${NC}"
              else
                  echo -e "$${RED}✗ $file has insecure permissions ($perms), should be 600 or 400$${NC}"
                  echo -e "  Fix with: chmod 600 $file"
              fi
          fi
      }
      
      # Check for sensitive patterns
      check_sensitive_patterns() {
          local file="$1"
          if [[ -f "$file" ]]; then
              local issues=()
              
              # Check for common sensitive patterns (only if uncommented)
              if grep -q "^[^#]*password.*=" "$file" 2>/dev/null; then
                  issues+=("contains passwords")
              fi
              if grep -q "^[^#]*secret.*=" "$file" 2>/dev/null; then
                  issues+=("contains secrets")
              fi
              if grep -q "^[^#]*token.*=" "$file" 2>/dev/null; then
                  issues+=("contains tokens")
              fi
              if grep -q "^[^#]*key.*=" "$file" 2>/dev/null; then
                  issues+=("contains keys")
              fi
              
              if [[ ''${#issues[@]} -gt 0 ]]; then
                  echo -e "$${GREEN}✓ $file contains secrets (''${issues[*]})$${NC}"
              else
                  echo -e "$${YELLOW}⚠ $file appears to be empty or only contains comments$${NC}"
              fi
          fi
      }
      
      echo "Directory Security:"
      check_directory_perms "$SECRETS_DIR"
      check_directory_perms "$CONFIG_SECRETS_DIR"
      
      echo ""
      echo "File Security:"
      
      # Check all secret files
      for dir in "$SECRETS_DIR" "$CONFIG_SECRETS_DIR"; do
          if [[ -d "$dir" ]]; then
              for file in "$dir"/*.env "$dir"/environment; do
                  if [[ -f "$file" ]]; then
                      check_file_perms "$file"
                      check_sensitive_patterns "$file"
                  fi
              done
          fi
      done
      
      echo ""
      echo "Git Security Check:"
      
      # Check if secret files are in gitignore
      if [[ -f ".gitignore" ]]; then
          if grep -q ".local/share/secrets" .gitignore && grep -q ".config/secrets" .gitignore; then
              echo -e "$${GREEN}✓ Secret directories are in .gitignore$${NC}"
          else
              echo -e "$${RED}✗ Secret directories not properly ignored by git$${NC}"
              echo -e "  Add these lines to .gitignore:"
              echo -e "  .local/share/secrets/"
              echo -e "  .config/secrets/"
          fi
      else
          echo -e "$${YELLOW}⚠ No .gitignore file found$${NC}"
      fi
      
      # Check if any secret files are tracked
      if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
          local tracked_secrets=$(git ls-files | grep -E "(secrets|\.env)" || true)
          if [[ -n "$tracked_secrets" ]]; then
              echo -e "$${RED}✗ Secret files are tracked by git:$${NC}"
              echo "$tracked_secrets"
              echo -e "  Remove with: git rm --cached <file>"
          else
              echo -e "$${GREEN}✓ No secret files tracked by git$${NC}"
          fi
      fi
      
      echo ""
      echo "Environment Variable Check:"
      
      # List currently loaded secret environment variables
      local secret_vars=$(env | grep -E "(KEY|TOKEN|SECRET|PASSWORD)" | cut -d= -f1 | sort || true)
      if [[ -n "$secret_vars" ]]; then
          echo -e "$${BLUE}Currently loaded secret variables:$${NC}"
          echo "$secret_vars" | sed 's/^/  /'
      else
          echo -e "$${YELLOW}⚠ No secret environment variables currently loaded$${NC}"
          echo -e "  Run 'load-secrets' to load secrets"
      fi
      
      echo ""
      echo -e "$${BLUE}=== Security Recommendations ===$${NC}"
      echo "1. Keep secret files with 600 permissions (owner read/write only)"
      echo "2. Never commit secret files to version control"
      echo "3. Use different secret files per environment (dev/staging/prod)"
      echo "4. Regularly rotate API keys and tokens"
      echo "5. Use 'load-secrets <command>' to run commands with secrets loaded"
      echo "6. Consider using a proper secret management service for production"
    '';
  };
  
  # Environment variables for secret management
  # These are safe defaults and configuration, not actual secrets
  home.sessionVariables = lib.mkMerge [
    # Base session variables (always applied)
    {
      # Secret management paths
      SECRETS_DIR = "$HOME/.local/share/secrets";
      CONFIG_SECRETS_DIR = "$HOME/.config/secrets";
      
      # Security settings
      GNUPG_HOME = "$HOME/.gnupg";
      PASSWORD_STORE_DIR = "$HOME/.password-store";
      
      # Development environment defaults (non-sensitive)
      EDITOR = "nvim";
      BROWSER = if isDarwin then "open" else "firefox";
      PAGER = "less -R";
      
      # XDG Base Directory specification (managed by home-manager xdg module)
      # XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME, XDG_STATE_HOME are set by xdg module
      
      # Development tools configuration
      CARGO_HOME = "$HOME/.local/share/cargo";
      RUSTUP_HOME = "$HOME/.local/share/rustup";
      GOPATH = "$HOME/.local/share/go";
      GOBIN = "$HOME/.local/bin";
      NODE_REPL_HISTORY = "$HOME/.local/share/node_repl_history";
      NPM_CONFIG_USERCONFIG = "$HOME/.config/npm/npmrc";
      
      # History settings
      HISTSIZE = "10000";
      HISTFILESIZE = "10000";
      HISTCONTROL = "ignoreboth:erasedups";
      
      # Terminal settings
      TERM = "xterm-256color";
      COLORTERM = "truecolor";
      
      # Less settings for better output
      LESS = "-R --use-color -Dd+r$Du+b$";
      LESSHISTFILE = "$HOME/.local/share/less_history";
      
      # Prevent Wine from creating desktop links
      WINEDLLOVERRIDES = "winemenubuilder.exe=d";
    }
    
    # macOS-specific variables
    (lib.mkIf isDarwin {
      # macOS Homebrew
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_INSECURE_REDIRECT = "1";
      HOMEBREW_CASK_OPTS = "--require-sha";
      
      # macOS development
      OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
    })
    
    # NixOS-specific variables
    (lib.mkIf (!isDarwin) {
      # Linux desktop
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland;xcb";
      
      # Development on Linux
      DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
    })
  ];
  
  # Shell integration for secret loading
  programs.zsh.initExtra = lib.mkAfter ''
    # Secret management functions
    
    # Function to load secrets and run a command
    secrets() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: secrets <command> [args...]"
            echo "Example: secrets npm run dev"
            echo "         secrets kubectl get pods"
            return 1
        fi
        
        load-secrets "$@"
    }
    
    # Function to edit secrets securely
    edit-secrets() {
        local file="''${1:-$HOME/.local/share/secrets/environment}"
        
        # Ensure secure permissions
        touch "$file"
        chmod 600 "$file"
        
        # Edit with default editor
        "$EDITOR" "$file"
        
        # Verify permissions after editing
        chmod 600 "$file"
        echo "Secret file updated: $file"
    }
    
    # Function to show secret status
    secret-status() {
        check-secrets
    }
    
    # Auto-completion for secrets command
    _secrets_completion() {
        local state
        _arguments \
            '1: :_command_names' \
            '*: :_files'
    }
    compdef _secrets_completion secrets
    
    # Alias for convenience
    alias sec="secrets"
    alias edit-env="edit-secrets"
    
    # Warning if secrets directory doesn't exist
    if [[ ! -d "$HOME/.local/share/secrets" ]]; then
        echo "💡 Secret management not initialized. Run 'init-secrets' to set up."
    fi
    
    # System maintenance aliases
    alias nix-update="$CONFIG_ROOT/scripts/update.sh"
    alias nix-rollback="$CONFIG_ROOT/scripts/rollback.sh"
    alias nix-maintain="$CONFIG_ROOT/scripts/maintain.sh"
    alias system-status="$CONFIG_ROOT/scripts/maintain.sh status"
    alias system-health="$CONFIG_ROOT/scripts/maintain.sh health"
    alias system-cleanup="$CONFIG_ROOT/scripts/maintain.sh cleanup"
    
    # Quick maintenance shortcuts
    alias quick-update="$CONFIG_ROOT/scripts/update.sh quick"
    alias emergency-rollback="$CONFIG_ROOT/scripts/rollback.sh emergency"
    alias system-backup="$CONFIG_ROOT/scripts/maintain.sh backup"
    
    # Set CONFIG_ROOT for scripts
    export CONFIG_ROOT="$HOME/.config/nixconf"
  '';
  
  
  
  # Documentation file for secret management
  home.file.".local/share/docs/secret-management.md" = {
    text = ''
      # Secret Management Guide
      
      This system provides secure management of environment variables and secrets
      without storing them in the Nix configuration.
      
      ## Quick Start
      
      ```bash
      # Initialize secret management
      init-secrets
      
      # Edit your secrets
      edit-secrets
      
      # Load secrets and run a command
      secrets npm run dev
      secrets kubectl get pods
      
      # Check security status
      secret-status
      ```
      
      ## File Structure
      
      - `~/.local/share/secrets/environment` - Main secrets file
      - `~/.local/share/secrets/macos.env` - macOS-specific secrets
      - `~/.local/share/secrets/linux.env` - Linux-specific secrets
      - `~/.local/share/secrets/<hostname>.env` - Host-specific secrets
      - `~/.config/secrets/development.env` - Development environment secrets
      
      ## Security Features
      
      - Files have 600 permissions (owner read/write only)
      - Directories have 700 permissions
      - Files are automatically added to gitignore
      - Security validation with check-secrets command
      - No secrets stored in Nix configuration
      
      ## Best Practices
      
      1. Never commit secret files to version control
      2. Use different files for different environments
      3. Regularly rotate API keys and tokens
      4. Use the secrets command to run applications with secrets loaded
      5. Backup secret files securely (encrypted)
      
      ## Common Usage Patterns
      
      ```bash
      # Development workflow
      secrets npm run dev
      secrets docker-compose up
      secrets terraform apply
      
      # Cloud operations
      secrets aws s3 ls
      secrets kubectl get pods
      secrets gcloud compute instances list
      
      # Deployment
      secrets ansible-playbook deploy.yml
      secrets helm install myapp ./chart
      ```
    '';
  };
  
  # macOS launchd agents
  launchd = lib.mkIf isDarwin {
    agents = {
      # Example user agent
      # "com.example.backup" = {
      #   enable = true;
      #   config = {
      #     ProgramArguments = [ "/usr/bin/rsync" "-av" "$HOME/Documents" "/Volumes/Backup" ];
      #     StartCalendarInterval = [{ Hour = 2; Minute = 0; }];
      #   };
      # };
    };
  };
}