# Desktop applications and environment overlays

final: prev: {
  # Enhanced terminal emulator with custom configuration
  alacritty-custom = prev.alacritty.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/share/alacritty
      cat > $out/share/alacritty/alacritty.yml << EOF
      # Alacritty configuration
      window:
        opacity: 0.9
        decorations: none
        startup_mode: Maximized
        
      scrolling:
        history: 10000
        multiplier: 3
        
      font:
        normal:
          family: "Fira Code"
          style: Regular
        bold:
          family: "Fira Code"
          style: Bold
        italic:
          family: "Fira Code"
          style: Italic
        size: 12.0
        
      colors:
        primary:
          background: '#1d1f21'
          foreground: '#c5c8c6'
        cursor:
          text: '#1d1f21'
          cursor: '#ffffff'
        normal:
          black:   '#1d1f21'
          red:     '#cc6666'
          green:   '#b5bd68'
          yellow:  '#f0c674'
          blue:    '#81a2be'
          magenta: '#b294bb'
          cyan:    '#8abeb7'
          white:   '#c5c8c6'
        bright:
          black:   '#666666'
          red:     '#d54e53'
          green:   '#b9ca4a'
          yellow:  '#e7c547'
          blue:    '#7aa6da'
          magenta: '#c397d8'
          cyan:    '#70c0b1'
          white:   '#eaeaea'
          
      key_bindings:
        - { key: V,        mods: Control|Shift, action: Paste            }
        - { key: C,        mods: Control|Shift, action: Copy             }
        - { key: Insert,   mods: Shift,         action: PasteSelection   }
        - { key: Key0,     mods: Control,       action: ResetFontSize    }
        - { key: Equals,   mods: Control,       action: IncreaseFontSize }
        - { key: Minus,    mods: Control,       action: DecreaseFontSize }
      EOF
    '';
  });

  # Kitty terminal with custom configuration
  kitty-custom = prev.kitty.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/share/kitty
      cat > $out/share/kitty/kitty.conf << EOF
      # Kitty configuration
      font_family      Fira Code
      bold_font        auto
      italic_font      auto
      bold_italic_font auto
      font_size        12.0
      
      # Cursor
      cursor_shape block
      cursor_blink_interval 0
      
      # Scrollback
      scrollback_lines 10000
      
      # Window
      remember_window_size  yes
      initial_window_width  1200
      initial_window_height 800
      window_padding_width  5
      background_opacity    0.9
      
      # Colors (Gruvbox Dark)
      background #282828
      foreground #ebdbb2
      cursor     #ebdbb2
      
      # Key bindings
      map ctrl+shift+c copy_to_clipboard
      map ctrl+shift+v paste_from_clipboard
      map ctrl+shift+equal increase_font_size
      map ctrl+shift+minus decrease_font_size
      map ctrl+shift+0 restore_font_size
      EOF
    '';
  });

  # Rofi with custom themes
  rofi-custom = prev.rofi.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/share/rofi/themes
      cat > $out/share/rofi/themes/custom.rasi << EOF
      * {
          background-color: transparent;
          text-color: #ebdbb2;
          border-color: #458588;
          width: 512;
      }
      
      window {
          transparency: "real";
          background-color: #282828dd;
          border: 2px;
          border-radius: 10px;
      }
      
      mainbox {
          children: [inputbar, listview];
          spacing: 10px;
          padding: 20px;
      }
      
      inputbar {
          children: [prompt, textbox-prompt-colon, entry];
      }
      
      prompt {
          text-color: #83a598;
      }
      
      textbox-prompt-colon {
          expand: false;
          str: ":";
          margin: 0px 0.3em 0em 0em;
          text-color: #83a598;
      }
      
      listview {
          border: 2px 0px 0px;
          border-color: #458588;
          spacing: 2px;
          scrollbar: false;
      }
      
      element {
          padding: 5px;
          border-radius: 5px;
      }
      
      element selected {
          background-color: #458588;
      }
      EOF
    '';
  });

  # Multimedia bundle with codecs
  multimedia-suite = prev.buildEnv {
    name = "multimedia-suite";
    paths = with final; [
      # Video players
      vlc
      mpv
      
      # Image viewers and editors
      feh
      imv
      gimp
      inkscape
      krita
      
      # Video editing
      kdenlive
      obs-studio
      davinci-resolve
      
      # Audio
      audacity
      ardour
      pavucontrol
      
      # Media utilities
      ffmpeg-full
      imagemagick
      exiftool
      
      # Screen capture
      flameshot
      peek
      
      # Color management
      displaycal
      argyllcms
    ];
  };

  # Office productivity suite
  office-suite = prev.buildEnv {
    name = "office-suite";
    paths = with final; [
      # Office applications
      libreoffice-fresh
      onlyoffice-bin
      
      # PDF tools
      zathura
      evince
      
      # Note taking
      obsidian
      logseq
      zettlr
      
      # Communication
      thunderbird-hardened
      discord
      slack
      zoom-us
      
      # Research and reference
      zotero
      calibre
      
      # Mind mapping
      freeplane
      drawio
    ];
  };

  # Gaming bundle
  gaming-suite = prev.buildEnv {
    name = "gaming-suite";
    paths = with final; [
      # Game launchers
      steam
      lutris
      bottles
      heroic
      
      # Emulation
      retroarch
      dolphin-emu
      pcsx2
      
      # Game development
      godot_4
      blender
      
      # Gaming utilities
      gamemode
      mangohud
      goverlay
      
      # Controllers
      xpadneo
      ds4drv
    ];
  };

  # Font collection with programming fonts
  fonts-enhanced = prev.buildEnv {
    name = "fonts-enhanced";
    paths = with final; [
      # Programming fonts
      fira-code
      fira-code-symbols
      jetbrains-mono
      hack-font
      source-code-pro
      
      # System fonts
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      
      # Nerd fonts
      (nerdfonts.override { fonts = [ 
        "FiraCode" 
        "JetBrainsMono" 
        "Hack" 
        "SourceCodePro" 
        "UbuntuMono"
      ]; })
      
      # Icon fonts
      font-awesome
      material-icons
    ];
  };

  # Development GUI tools
  dev-gui-tools = prev.buildEnv {
    name = "development-gui-tools";
    paths = with final; [
      # IDEs and editors
      vscode
      jetbrains.idea-ultimate
      jetbrains.pycharm-professional
      jetbrains.rust-rover
      
      # Database tools
      dbeaver
      pgadmin4
      
      # API development
      insomnia
      postman
      
      # Git GUIs
      gitg
      github-desktop
      
      # Design and mockup
      figma-linux
      penpot-desktop
      
      # System monitoring
      htop
      btop
      system-monitor
      
      # File managers
      dolphin
      thunar
      nemo
    ];
  };

  # Window manager tools
  wm-tools = prev.buildEnv {
    name = "window-manager-tools";
    paths = with final; [
      # Launchers
      rofi-custom
      dmenu
      wofi
      
      # Bars and panels
      waybar
      polybar
      
      # Notifications
      dunst
      mako
      
      # Wallpapers
      nitrogen
      feh
      swaybg
      
      # Screenshots
      grim
      slurp
      flameshot
      
      # Color pickers
      gcolor3
      
      # System info
      neofetch
      fastfetch
      
      # Clipboard managers
      clipmenu
      wl-clipboard
    ];
  };

  # Creative suite
  creative-suite = prev.buildEnv {
    name = "creative-suite";
    paths = with final; [
      # Graphics
      gimp
      inkscape
      krita
      
      # 3D and modeling
      blender
      freecad
      
      # Video editing
      kdenlive
      openshot-qt
      
      # Audio production
      audacity
      ardour
      lmms
      
      # Photography
      darktable
      rawtherapee
      digikam
      
      # Vector graphics
      inkscape
      
      # CAD
      freecad
      qcad
    ];
  };
}