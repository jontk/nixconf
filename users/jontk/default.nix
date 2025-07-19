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
    procs # Modern replacement for ps
    
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
    taskwarrior3
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
      ss = "stash show -p";
      
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
        pager = "delta";
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
          pushInsteadOf = "github:";
          pushInsteadOf = "https://github.com/";
        };
        "git@gitlab.com:" = {
          insteadOf = "gl:";
          pushInsteadOf = "gitlab:";
          pushInsteadOf = "https://gitlab.com/";
        };
        "git@bitbucket.org:" = {
          insteadOf = "bb:";
          pushInsteadOf = "bitbucket:";
          pushInsteadOf = "https://bitbucket.org/";
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
    
    shellAliases = programs.zsh.shellAliases; # Use same aliases as zsh
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
        "ctrl+shift+]" = "next_window";
        "ctrl+shift+[" = "previous_window";
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
      coc-python
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
      nodePackages.pyright
      rust-analyzer
      gopls
      lua-language-server
      nil # Nix language server
      
      # Formatters
      nixpkgs-fmt
      rustfmt
      black
      prettier
      gofmt
      
      # Additional tools
      ripgrep
      fd
      bat
      tree-sitter
    ];
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