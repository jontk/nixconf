{ config, pkgs, lib, isDarwin ? false, isNixOS ? false, ... }:

{
  # Home Manager configuration for user jontk
  # MINIMAL VERSION - Only package installation
  # All configuration is managed by chezmoi

  home.stateVersion = "25.05";
  home.username = "jontk";
  home.homeDirectory = if isDarwin then "/Users/jontk" else "/home/jontk";

  programs.home-manager.enable = true;

  # ONLY package installation - NO configuration
  # All dotfiles and configuration managed by chezmoi
  home.packages = with pkgs; [
    # Core CLI tools
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
    stow

    # System monitoring
    lsof

    # Compression
    p7zip
    xz
    gzip
    bzip2

    # Version control
    git
    subversion
    mercurial
    gh
    glab
    hub
    lazygit
    tig
    gitui
    delta

    # Development editors
    neovim
    vim
    emacs
    vscode
    zed-editor
    micro

    # Terminal utilities
    tmux
    screen
    zellij

    # Code quality
    shellcheck
    shfmt

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

    # Cloud tools
    awscli2
    google-cloud-sdk
    azure-cli
    doctl

    # Infrastructure as code
    terraform
    terragrunt
    ansible
    pulumi

    # Kubernetes
    kubectl
    kubectx
    k9s
    kubernetes-helm
    kustomize
    stern
    fluxcd
    argocd

    # Databases
    postgresql
    redis
    sqlite

    # HTTP clients
    httpie
    curlie
    xh

    # Secrets management
    doppler

    # Productivity
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

    # System utilities
    mtr
    speedtest-cli
    iperf
    ncdu
    duf
    dust
    procs
    bandwhich
    sd
    choose
    miller

    # Media tools
    yt-dlp
    ffmpeg
    mpv
    vlc
    imagemagick
    exiftool
    mediainfo

    # GUI Applications (NixOS only)
  ] ++ lib.optionals isNixOS [
    # Linux-only system tools
    iotop
    nethogs
    iftop
    psmisc
    podman-compose
    skopeo
    buildah

    # Desktop environment
    dunst

    # File managers
    ranger
    nnn
    xfce.thunar
    file-roller

    # Browsers
    firefox
    chromium

    # Image viewers
    feh
    imv

    # PDF readers
    zathura
    evince

    # Office
    libreoffice

    # Communication
    discord
    signal-desktop
    telegram-desktop

    # System utilities
    pavucontrol
    alsa-utils
    xclip
    xsel
    wl-clipboard
    flameshot
    neofetch

    # Themes (packages only, configuration in chezmoi)
    dracula-theme

    # GNOME utilities
    gnome-calculator
    gnome-system-monitor
    gnome-disk-utility
  ] ++ lib.optionals isDarwin [
    # macOS specific
    reattach-to-user-namespace
    pinentry_mac
  ];
}
