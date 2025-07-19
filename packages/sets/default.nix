# Centralized Package Collections
{ pkgs, lib, ... }:

{
  # Core system packages - always needed
  core = with pkgs; [
    coreutils findutils gawk gnused gnugrep
    curl wget git tree htop btop
    file which unzip zip rsync
  ];

  # CLI productivity tools
  cli = with pkgs; [
    ripgrep fd bat eza fzf
    jq yq tmux zellij
    bottom procs dust
    less most
  ];

  # Development essentials
  development = with pkgs; [
    git gh delta lazygit
    docker-compose kubectl helm
    terraform ansible
    pre-commit shellcheck
  ];

  # Programming languages with stable versions
  languages = {
    rust = with pkgs; [
      rustc cargo clippy rustfmt
      rust-analyzer
      cargo-edit cargo-watch
    ];
    
    go = with pkgs; [
      go_1_22  # Updated to newer stable version
      gopls
      golangci-lint
      delve  # debugger
    ];
    
    python = with pkgs; [
      python312  # Updated to Python 3.12
      python312Packages.pip
      python312Packages.poetry-core
      python312Packages.virtualenv
      pyright
      black isort
    ];
    
    javascript = with pkgs; [
      nodejs_20  # LTS version
      nodePackages.npm
      nodePackages.yarn
      nodePackages.typescript-language-server
      nodePackages.eslint
      deno
    ];

    java = with pkgs; [
      openjdk21  # LTS version
      maven
      gradle
    ];

    cAndCpp = with pkgs; [
      gcc clang
      cmake gnumake
      gdb lldb
      pkg-config
    ];
  };

  # Desktop applications
  desktop = with pkgs; [
    firefox chromium
    alacritty kitty
    discord signal-desktop
    vlc mpv
    obsidian
    libreoffice
    gimp inkscape
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Linux-specific desktop apps
    xfce.thunar
    zathura
    rofi
  ];

  # Security tools
  security = with pkgs; [
    nmap wireshark
    age sops
    gnupg pass
    fail2ban
    lynis  # security audit
    chkrootkit
  ];

  # System administration
  sysadmin = with pkgs; [
    iotop nethogs iftop
    lsof psmisc
    smartmontools
    rsync rclone
    htop btop
    ncdu duf  # disk usage tools
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Linux-specific admin tools
    systemd
    usbutils pciutils
  ];

  # Cloud and DevOps tools
  cloud = with pkgs; [
    awscli2
    google-cloud-sdk
    azure-cli
    doctl  # DigitalOcean CLI
    terraform
    ansible
    packer
    vault
  ];

  # Database tools
  database = with pkgs; [
    postgresql
    redis
    sqlite
    dbeaver-bin
    pgcli
  ];

  # Network tools
  network = with pkgs; [
    nmap netcat
    dig whois
    traceroute
    tcpdump
    wireshark-cli
    curl wget
    httpie
  ];

  # Media and graphics
  media = with pkgs; [
    vlc mpv
    ffmpeg
    imagemagick
    gimp inkscape
    blender  # 3D graphics
  ];
}