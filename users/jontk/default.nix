{ config, pkgs, lib, isDarwin ? false, isNixOS ? false, ... }:

{
  # Home Manager configuration for user jontk
  home.stateVersion = "25.05";
  
  # User information
  home.username = "jontk";
  home.homeDirectory = if isDarwin then "/Users/jontk" else "/home/jontk";
  
  # Enable home-manager
  programs.home-manager.enable = true;
  
  # Basic packages for user
  home.packages = with pkgs; [
    # Terminal utilities
    tmux
    screen
    
    # Text editors
    neovim
    emacs
    
    # Development tools
    gh # GitHub CLI
    glab # GitLab CLI
    hub # Another GitHub CLI tool
    lazygit # Terminal UI for git
    tig # Text-mode interface for git
    
    # Productivity tools
    taskwarrior
    timewarrior
    
    # Media tools
    yt-dlp
    ffmpeg
    imagemagick
    
    # macOS-specific tools
  ] ++ lib.optionals isDarwin [
    reattach-to-user-namespace # For tmux clipboard support on macOS
  ];
  
  
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
      
      # Commits
      c = "commit";
      cm = "commit -m";
      ca = "commit -a";
      cam = "commit -am";
      amend = "commit --amend";
      
      # Branches
      b = "branch";
      ba = "branch -a";
      bd = "branch -d";
      bD = "branch -D";
      co = "checkout";
      cob = "checkout -b";
      
      # Logging
      l = "log --oneline --graph";
      ll = "log --oneline --graph --all";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      
      # Diffs
      d = "diff";
      dc = "diff --cached";
      
      # Remote
      f = "fetch";
      pl = "pull";
      ps = "push";
      psu = "push -u origin HEAD";
      
      # Stash
      stash-all = "stash save --include-untracked";
      
      # Utils
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      visual = "!gitk";
      
      # Workflow
      wip = "!git add -A && git commit -m 'WIP'";
      undo = "reset HEAD~1 --mixed";
      
      # Maintenance
      cleanup = "!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d";
    };
    
    extraConfig = {
      core = {
        editor = "vim";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        excludesfile = "~/.gitignore_global";
      };
      
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
      };
      
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      
      pull = {
        rebase = true;
      };
      
      fetch = {
        prune = true;
      };
      
      diff = {
        colorMoved = "default";
      };
      
      merge = {
        conflictstyle = "diff3";
      };
      
      rerere = {
        enabled = true;
      };
      
      help = {
        autocorrect = 1;
      };
      
      init = {
        defaultBranch = "main";
      };
    };
    
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
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
    
    initExtra = ''
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
    nix-direnv.enable = true;
  };
  
  # fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
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
    icons = true;
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
      
      # Split panes
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %
      
      # Navigate panes
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
      
      # Copy mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
      
      # macOS clipboard integration
      ${lib.optionalString isDarwin ''
        bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
      ''}
      
      # Status bar
      set -g status-style bg=black,fg=white
      set -g status-left '#[fg=green]#S '
      set -g status-right '#[fg=yellow]#(uptime | cut -d "," -f 1) #[fg=white]%H:%M'
      set -g status-left-length 40
      
      # Window status
      setw -g window-status-style fg=cyan,bg=default,dim
      setw -g window-status-current-style fg=white,bg=red,bright
      
      # Pane borders
      set -g pane-border-style fg=green,bg=black
      set -g pane-active-border-style fg=white,bg=yellow
      
      # Messages
      set -g message-style fg=white,bg=black,bright
      
      # Activity
      setw -g monitor-activity on
      set -g visual-activity on
    '';
    
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      pain-control
      sessionist
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          ${lib.optionalString isDarwin ''
            set -g @resurrect-processes 'ssh mosh nvim vim emacs'
          ''}
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
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
        pinentryPackage = pkgs.pinentry-gtk2;
      };
    })
    
    # macOS-specific services
    (lib.mkIf isDarwin {
      # Example: syncthing could be configured here
      # syncthing = {
      #   enable = true;
      # };
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
  
  # User-specific environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  } // lib.optionalAttrs isDarwin {
    # macOS specific environment variables
    HOMEBREW_NO_ANALYTICS = "1";
  };
  
  # XDG directories
  xdg = {
    enable = true;
    # Use hardcoded paths since config.home.homeDirectory is not available in this context
    configHome = "/home/jontk/.config";
    dataHome = "/home/jontk/.local/share";
    cacheHome = "/home/jontk/.cache";
    stateHome = "/home/jontk/.local/state";
  };
  
  # Create dotfiles structure
  home.file = {
    ".config/nvim/.keep".text = "";
    ".config/emacs/.keep".text = "";
    ".local/bin/.keep".text = "";
    
    # Terminal emulator configurations
    ".config/alacritty/alacritty.yml".source = ./dotfiles/alacritty.yml;
    ".config/kitty/kitty.conf".source = ./dotfiles/kitty.conf;
    
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