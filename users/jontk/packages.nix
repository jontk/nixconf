# User-specific package configuration
# This file can be customized for individual users
# Copy this file to create user-specific package sets

{ pkgs, lib, isDarwin ? false, ... }:

let
  # Personal package preferences
  # Customize these based on your needs
  personalPackages = with pkgs; [
    # === PERSONAL APPLICATIONS ===
    # Add your favorite applications here
    
    # Web Browsers
    # firefox
    # chromium
    # brave
    
    # Communication
    # slack
    # discord
    # signal-desktop
    # telegram-desktop
    
    # Development Tools
    # vscode
    # jetbrains.idea-ultimate
    # jetbrains.webstorm
    # jetbrains.pycharm-professional
    
    # Media & Entertainment
    # spotify
    # vlc
    # obs-studio
    
    # Productivity
    # obsidian
    # notion-app-enhanced
    # todoist-electron
    
    # Design & Graphics
    # figma-linux
    # inkscape
    # gimp
    
    # === PLACEHOLDER ===
    # Remove this comment when you add your packages above
  ];

  # Work-specific packages
  workPackages = with pkgs; [
    # Add work-related tools here
    # Examples:
    # teams-for-linux
    # zoom-us
    # postman
    # dbeaver-bin
    # kubectl
    # terraform
    # ansible
  ];

  # Development environment packages
  # Language-specific tools and environments
  devPackages = with pkgs; [
    # === PROGRAMMING LANGUAGES ===
    
    # Python
    # python3
    # python3Packages.pip
    # python3Packages.virtualenv
    # python3Packages.poetry
    
    # Node.js
    # nodejs
    # yarn
    # pnpm
    
    # Rust
    # rustc
    # cargo
    # rust-analyzer
    
    # Go
    # go
    # gopls
    
    # Java
    # openjdk
    # maven
    # gradle
    
    # === DATABASES ===
    # postgresql
    # redis
    # sqlite
    
    # === ADDITIONAL DEV TOOLS ===
    # docker
    # kubernetes-cli
    # minikube
    # helm
  ];

  # Gaming and entertainment packages
  gamingPackages = with pkgs; [
    # Gaming platforms
    # steam
    # lutris
    # bottles
    
    # Emulation
    # retroarch
    
    # Terminal fun
    # neofetch
    # cowsay
    # fortune
    # lolcat
    
    # Terminal games
    # bastet  # Tetris
    # nudoku  # Sudoku
  ];

  # Research and academic packages
  academicPackages = with pkgs; [
    # Reference management
    # zotero
    
    # Document preparation
    # texlive.combined.scheme-full
    # pandoc
    
    # Data analysis
    # R
    # rstudio
    # jupyter
    
    # Scientific computing
    # octave
    # maxima
  ];

  # Security and privacy packages
  securityPackages = with pkgs; [
    # VPN clients
    # openvpn
    # wireguard-tools
    
    # Password managers
    # keepassxc
    # bitwarden
    
    # Network analysis
    # wireshark
    # nmap
    
    # Encryption
    # gnupg
    # age
  ];

  # Creative packages
  creativePackages = with pkgs; [
    # Video editing
    # kdenlive
    # openshot-qt
    # davinci-resolve
    
    # Audio editing
    # audacity
    # ardour
    
    # 3D modeling
    # blender
    
    # Image editing
    # gimp
    # krita
    # inkscape
    
    # Photography
    # darktable
    # rawtherapee
  ];

  # Platform-specific overrides
  platformPackages = if isDarwin then
    # macOS-specific packages
    with pkgs; [
      # macOS tools
      # mas  # Mac App Store CLI
      # m-cli  # macOS management
    ]
  else
    # Linux/NixOS-specific packages
    with pkgs; [
      # Linux desktop applications
      # flameshot  # Screenshot tool
      # peek  # GIF recorder
      # gpick  # Color picker
    ];

in {
  # Export package sets for use in home.packages
  # Choose which sets to include based on your needs
  
  # Basic personal packages (recommended for everyone)
  basic = personalPackages ++ platformPackages;
  
  # Work environment
  work = personalPackages ++ workPackages ++ platformPackages;
  
  # Full development setup
  development = personalPackages ++ workPackages ++ devPackages ++ platformPackages;
  
  # Gaming setup
  gaming = personalPackages ++ gamingPackages ++ platformPackages;
  
  # Academic/research setup
  academic = personalPackages ++ academicPackages ++ devPackages ++ platformPackages;
  
  # Security-focused setup
  security = personalPackages ++ securityPackages ++ devPackages ++ platformPackages;
  
  # Creative professional setup
  creative = personalPackages ++ creativePackages ++ devPackages ++ platformPackages;
  
  # Full setup (everything enabled)
  full = personalPackages ++ workPackages ++ devPackages ++ gamingPackages 
         ++ academicPackages ++ securityPackages ++ creativePackages ++ platformPackages;
  
  # Individual package sets (for custom combinations)
  sets = {
    personal = personalPackages;
    work = workPackages;
    development = devPackages;
    gaming = gamingPackages;
    academic = academicPackages;
    security = securityPackages;
    creative = creativePackages;
    platform = platformPackages;
  };
}