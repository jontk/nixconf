{ config, pkgs, lib, inputs, ... }:

{
  # Hyprland window manager configuration
  config = lib.mkIf config.desktop.enable {
    # Enable Hyprland
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
    
    # Environment variables for the system
    environment.sessionVariables = {
      NIXPKGS_ALLOW_UNFREE = "1";
      # RustDesk Wayland support
      QT_QPA_PLATFORM = "wayland;xcb";
      GDK_BACKEND = "wayland,x11";
      # Enable screensharing support
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      # VM-specific settings
      WLR_RENDERER = "pixman";
      WLR_NO_HARDWARE_CURSORS = "1";
      LIBSEAT_BACKEND = "logind";
    };
    
    # Hyprland-specific packages
    environment.systemPackages = with pkgs; [
      # Core Hyprland utilities
      hyprpaper # Wallpaper utility
      hyprpicker # Color picker
      hypridle # Idle management daemon
      hyprlock # Screen locker
      
      # Status bar
      waybar
      
      # Application launcher
      rofi-wayland
      
      # Terminal emulators
      kitty
      alacritty
      
      # File manager
      nautilus
      
      # Polkit authentication agent
      polkit_gnome
      
      # Network manager applet
      networkmanagerapplet
      
      # Clipboard manager
      cliphist
      
      # System tray support
      libappindicator-gtk3
      
      # Theme and appearance
      gnome-themes-extra
      gtk-engine-murrine
      lxappearance
      
      # Fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      font-awesome
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
    
    # Default Hyprland configuration
    environment.etc."hypr/hyprland.conf".text = ''
      # This is the default Hyprland configuration
      # User-specific configuration should be in ~/.config/hypr/hyprland.conf
      
      # Monitor configuration
      # monitor=,preferred,auto,auto
      monitor=,highres,auto,1
      
      # Execute at launch
      exec-once = waybar
      exec-once = hyprpaper
      exec-once = dunst
      exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
      exec-once = nm-applet --indicator
      exec-once = wl-paste --type text --watch cliphist store
      exec-once = wl-paste --type image --watch cliphist store
      
      # Environment variables
      env = XCURSOR_SIZE,24
      env = WLR_NO_HARDWARE_CURSORS,1
      
      # Input configuration
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options = caps:escape
          kb_rules =
          
          follow_mouse = 1
          
          touchpad {
              natural_scroll = true
              disable_while_typing = true
              tap-to-click = true
          }
          
          sensitivity = 0
      }
      
      # General configuration
      general {
          gaps_in = 5
          gaps_out = 10
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          
          layout = dwindle
          
          allow_tearing = false
      }
      
      # Decoration
      decoration {
          rounding = 10
          
          blur {
              enabled = true
              size = 3
              passes = 1
          }
          
          drop_shadow = true
          shadow_range = 4
          shadow_render_power = 3
          col.shadow = rgba(1a1a1aee)
      }
      
      # Animations
      animations {
          enabled = true
          
          bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          
          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }
      
      # Layouts
      dwindle {
          pseudotile = true
          preserve_split = true
      }
      
      master {
          new_is_master = true
      }
      
      # Gestures
      gestures {
          workspace_swipe = true
          workspace_swipe_fingers = 3
      }
      
      # Misc
      misc {
          force_default_wallpaper = 0
          disable_hyprland_logo = true
      }
      
      # Window rules
      windowrulev2 = float,class:^(pavucontrol)$
      windowrulev2 = float,class:^(nm-connection-editor)$
      windowrulev2 = float,class:^(blueberry.py)$
      windowrulev2 = float,title:^(Picture-in-Picture)$
      windowrulev2 = float,title:^(Volume Control)$
      windowrulev2 = float,title:^(Network Connections)$
      
      # Key bindings
      $mainMod = SUPER
      
      # Core bindings
      bind = $mainMod, Return, exec, kitty
      bind = $mainMod, Q, killactive,
      bind = $mainMod, M, exit,
      bind = $mainMod, E, exec, nautilus
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, D, exec, rofi -show drun
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle
      bind = $mainMod, F, fullscreen,
      bind = $mainMod, L, exec, hyprlock
      
      # Move focus with mainMod + arrow keys
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d
      
      # Move focus with mainMod + vim keys
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d
      
      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10
      
      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10
      
      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1
      
      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow
      
      # Media keys
      bind = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
      bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bind = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bind = , XF86MonBrightnessUp, exec, brightnessctl s +5%
      bind = , XF86MonBrightnessDown, exec, brightnessctl s 5%-
      
      # Screenshot bindings
      bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
      bind = SHIFT, Print, exec, grim - | wl-copy
      bind = CTRL, Print, exec, grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
      bind = CTRL SHIFT, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
      
      # Clipboard history
      bind = $mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy
      
      # Window management
      bind = $mainMod, Tab, cyclenext,
      bind = $mainMod SHIFT, Tab, cyclenext, prev
      bind = $mainMod SHIFT, left, movewindow, l
      bind = $mainMod SHIFT, right, movewindow, r
      bind = $mainMod SHIFT, up, movewindow, u
      bind = $mainMod SHIFT, down, movewindow, d
      bind = $mainMod SHIFT, h, movewindow, l
      bind = $mainMod SHIFT, l, movewindow, r
      bind = $mainMod SHIFT, k, movewindow, u
      bind = $mainMod SHIFT, j, movewindow, d
      
      # Resize mode
      bind = $mainMod, R, submap, resize
      submap = resize
      binde = , right, resizeactive, 10 0
      binde = , left, resizeactive, -10 0
      binde = , up, resizeactive, 0 -10
      binde = , down, resizeactive, 0 10
      binde = , l, resizeactive, 10 0
      binde = , h, resizeactive, -10 0
      binde = , k, resizeactive, 0 -10
      binde = , j, resizeactive, 0 10
      bind = , escape, submap, reset
      bind = $mainMod, R, submap, reset
      submap = reset
    '';
    
    # Waybar configuration
    environment.etc."waybar/config".text = ''
      {
          "layer": "top",
          "position": "top",
          "height": 30,
          "spacing": 4,
          
          "modules-left": ["hyprland/workspaces", "hyprland/mode", "hyprland/window"],
          "modules-center": ["clock"],
          "modules-right": ["pulseaudio", "network", "cpu", "memory", "temperature", "battery", "tray"],
          
          "hyprland/workspaces": {
              "disable-scroll": true,
              "all-outputs": true,
              "format": "{icon}",
              "format-icons": {
                  "1": "",
                  "2": "",
                  "3": "",
                  "4": "",
                  "5": "",
                  "urgent": "",
                  "focused": "",
                  "default": ""
              }
          },
          
          "hyprland/window": {
              "format": "{}",
              "separate-outputs": true
          },
          
          "tray": {
              "spacing": 10
          },
          
          "clock": {
              "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
              "format-alt": "{:%Y-%m-%d}"
          },
          
          "cpu": {
              "format": " {usage}%",
              "tooltip": false
          },
          
          "memory": {
              "format": " {}%"
          },
          
          "temperature": {
              "critical-threshold": 80,
              "format": " {temperatureC}°C"
          },
          
          "battery": {
              "states": {
                  "warning": 30,
                  "critical": 15
              },
              "format": "{icon} {capacity}%",
              "format-charging": " {capacity}%",
              "format-plugged": " {capacity}%",
              "format-alt": "{icon} {time}",
              "format-icons": ["", "", "", "", ""]
          },
          
          "network": {
              "format-wifi": " {essid} ({signalStrength}%)",
              "format-ethernet": " {ipaddr}/{cidr}",
              "tooltip-format": " {ifname} via {gwaddr}",
              "format-linked": " {ifname} (No IP)",
              "format-disconnected": "⚠ Disconnected",
              "format-alt": "{ifname}: {ipaddr}/{cidr}"
          },
          
          "pulseaudio": {
              "format": "{icon} {volume}%",
              "format-bluetooth": "{icon} {volume}% ",
              "format-bluetooth-muted": " {icon}",
              "format-muted": " ",
              "format-icons": {
                  "headphone": "",
                  "hands-free": "",
                  "headset": "",
                  "phone": "",
                  "portable": "",
                  "car": "",
                  "default": ["", "", ""]
              },
              "on-click": "pavucontrol"
          }
      }
    '';
    
    # Waybar style
    environment.etc."waybar/style.css".text = ''
      * {
          font-family: "JetBrains Mono", FontAwesome, sans-serif;
          font-size: 13px;
      }
      
      window#waybar {
          background-color: rgba(26, 27, 38, 0.9);
          color: #cdd6f4;
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
          box-shadow: inset 0 -3px #cdd6f4;
      }
      
      #workspaces button {
          padding: 0 5px;
          background-color: transparent;
          color: #cdd6f4;
      }
      
      #workspaces button:hover {
          background: rgba(0, 0, 0, 0.2);
      }
      
      #workspaces button.focused {
          background-color: #313244;
          box-shadow: inset 0 -3px #cdd6f4;
      }
      
      #workspaces button.urgent {
          background-color: #f38ba8;
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
      #wireplumber,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #scratchpad,
      #power-profiles-daemon,
      #mpd {
          padding: 0 10px;
          color: #cdd6f4;
      }
      
      #window,
      #workspaces {
          margin: 0 4px;
      }
      
      .modules-left > widget:first-child > #workspaces {
          margin-left: 0;
      }
      
      .modules-right > widget:last-child > * {
          margin-right: 0;
      }
      
      #clock {
          background-color: #313244;
      }
      
      #battery {
          background-color: #313244;
      }
      
      #battery.charging, #battery.plugged {
          color: #a6e3a1;
      }
      
      @keyframes blink {
          to {
              background-color: #cdd6f4;
              color: #313244;
          }
      }
      
      #battery.critical:not(.charging) {
          background-color: #f38ba8;
          color: #313244;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: steps(12);
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }
      
      label:focus {
          background-color: #313244;
      }
      
      #cpu {
          background-color: #313244;
      }
      
      #memory {
          background-color: #313244;
      }
      
      #disk {
          background-color: #313244;
      }
      
      #backlight {
          background-color: #313244;
      }
      
      #network {
          background-color: #313244;
      }
      
      #network.disconnected {
          background-color: #f38ba8;
      }
      
      #pulseaudio {
          background-color: #313244;
      }
      
      #pulseaudio.muted {
          background-color: #45475a;
      }
      
      #temperature {
          background-color: #313244;
      }
      
      #temperature.critical {
          background-color: #f38ba8;
      }
      
      #tray {
          background-color: #313244;
      }
      
      #tray > .passive {
          -gtk-icon-effect: dim;
      }
      
      #tray > .needs-attention {
          -gtk-icon-effect: highlight;
          background-color: #f38ba8;
      }
    '';
    
    # Hyprpaper configuration
    environment.etc."hypr/hyprpaper.conf".text = ''
      preload = /usr/share/backgrounds/default.png
      wallpaper = ,/usr/share/backgrounds/default.png
      splash = false
    '';
    
    # Create default wallpaper directory
    system.activationScripts.wallpapers = ''
      mkdir -p /usr/share/backgrounds
      # Default wallpaper would be placed here
    '';
  };
}