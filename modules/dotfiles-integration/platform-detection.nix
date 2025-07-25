# Platform Detection and Configuration System
{ lib, pkgs }:

with lib;

let
  # Detect current platform
  detectPlatform = 
    if pkgs.stdenv.isDarwin then "macos"
    else if pkgs.stdenv.isLinux then "linux"
    else "unknown";
  
  # Get platform-specific information
  getPlatformInfo = 
    let
      platform = detectPlatform;
    in
    {
      name = platform;
      isLinux = platform == "linux";
      isMacOS = platform == "macos";
      isUnknown = platform == "unknown";
      
      # Platform-specific paths
      paths = {
        home = if platform == "macos" then "/Users" else "/home";
        cache = if platform == "macos" then "~/Library/Caches" else "~/.cache";
        config = if platform == "macos" then "~/Library/Application Support" else "~/.config";
        data = if platform == "macos" then "~/Library/Application Support" else "~/.local/share";
        temp = if platform == "macos" then "/tmp" else "/tmp";
      };
      
      # Platform-specific package managers
      packageManagers = 
        if platform == "macos" then [ "homebrew" "nix" ]
        else if platform == "linux" then [ "nix" "apt" "yum" "pacman" "zypper" ]
        else [ "nix" ];
      
      # Platform-specific shells
      commonShells = 
        if platform == "macos" then [ "zsh" "bash" ]
        else [ "bash" "zsh" "fish" ];
      
      # Platform-specific tools
      platformTools = 
        if platform == "macos" then {
          clipboard = { copy = "pbcopy"; paste = "pbpaste"; };
          open = "open";
          process_viewer = "Activity Monitor";
          terminal = "Terminal.app";
        }
        else {
          clipboard = { copy = "xclip -selection clipboard"; paste = "xclip -selection clipboard -o"; };
          open = "xdg-open";
          process_viewer = "htop";
          terminal = "$TERMINAL";
        };
    };

  # Filter modules by platform compatibility
  filterModulesByPlatform = { modules, platform ? detectPlatform }:
    filterAttrs (name: moduleConfig:
      let
        supportedPlatforms = moduleConfig.platforms or [ "linux" "macos" ];
      in
      elem platform supportedPlatforms
    ) modules;

  # Apply platform-specific settings to module configuration
  applyPlatformSettings = { moduleConfig, platform ? detectPlatform }:
    let
      platformSettings = moduleConfig.platform_settings.${platform} or {};
      defaultSettings = moduleConfig.settings or {};
      
      # Merge platform-specific settings with defaults
      mergedSettings = defaultSettings // platformSettings;
      
      # Apply platform-specific file mappings
      platformFiles = 
        if hasAttr "platform_files" moduleConfig && hasAttr platform moduleConfig.platform_files then
          moduleConfig.platform_files.${platform}
        else
          [];
      
      defaultFiles = moduleConfig.files or [];
      mergedFiles = defaultFiles ++ platformFiles;
      
    in
    moduleConfig // {
      settings = mergedSettings;
      files = mergedFiles;
      platform = platform;
      platformSpecific = platformSettings != {};
    };

  # Generate platform-specific aliases
  generatePlatformAliases = { platform ? detectPlatform }:
    let
      platformInfo = getPlatformInfo;
      tools = platformInfo.platformTools;
    in
    {
      # Clipboard operations
      clip = tools.clipboard.copy;
      paste = tools.clipboard.paste;
      
      # File operations
      open = tools.open;
      
      # System information
      sysinfo = 
        if platform == "macos" then "system_profiler SPSoftwareDataType"
        else "uname -a && lsb_release -a 2>/dev/null || cat /etc/os-release";
      
      # Process management
      processes = 
        if platform == "macos" then "ps aux"
        else "ps aux";
      
      # Network information
      netinfo = 
        if platform == "macos" then "ifconfig"
        else "ip addr show";
      
      # Disk usage
      diskinfo = 
        if platform == "macos" then "df -h"
        else "df -h";
      
      # Memory usage
      meminfo = 
        if platform == "macos" then "vm_stat"
        else "free -h";
      
      # CPU information
      cpuinfo = 
        if platform == "macos" then "sysctl -n machdep.cpu.brand_string"
        else "cat /proc/cpuinfo | grep 'model name' | head -1";
    };

  # Platform-specific environment variables
  generatePlatformEnvironment = { platform ? detectPlatform }:
    let
      platformInfo = getPlatformInfo;
    in
    {
      DOTFILES_PLATFORM = platform;
      DOTFILES_PLATFORM_IS_MACOS = toString platformInfo.isMacOS;
      DOTFILES_PLATFORM_IS_LINUX = toString platformInfo.isLinux;
      
      # Platform-specific paths
      PLATFORM_CACHE_DIR = platformInfo.paths.cache;
      PLATFORM_CONFIG_DIR = platformInfo.paths.config;
      PLATFORM_DATA_DIR = platformInfo.paths.data;
      
    } // (if platform == "macos" then {
      # macOS-specific environment
      BROWSER = "open";
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_AUTO_UPDATE = "1";
    } else {
      # Linux-specific environment  
      BROWSER = "xdg-open";
      XDG_CACHE_HOME = platformInfo.paths.cache;
      XDG_CONFIG_HOME = platformInfo.paths.config;
      XDG_DATA_HOME = platformInfo.paths.data;
    });

  # Platform-specific package suggestions
  getPlatformPackages = { platform ? detectPlatform }:
    if platform == "macos" then {
      essential = [ "coreutils" "findutils" "gnu-sed" "gnu-tar" "gawk" ];
      development = [ "git" "curl" "wget" ];
      utilities = [ "tree" "jq" "ripgrep" "fd" ];
    }
    else {
      essential = [ "coreutils" "findutils" "util-linux" ];
      development = [ "git" "curl" "wget" "build-essential" ];
      utilities = [ "tree" "jq" "ripgrep" "fd" "htop" ];
    };

  # Validate platform compatibility
  validatePlatformCompatibility = { moduleConfig, platform ? detectPlatform }:
    let
      supportedPlatforms = moduleConfig.platforms or [ "linux" "macos" ];
      isSupported = elem platform supportedPlatforms;
      
      errors = if !isSupported then [{
        error = "Module not supported on platform '${platform}'";
        supportedPlatforms = supportedPlatforms;
        currentPlatform = platform;
      }] else [];
      
      warnings = 
        if hasAttr "platform_settings" moduleConfig && !(hasAttr platform moduleConfig.platform_settings) then [{
          warning = "No platform-specific settings found for '${platform}'";
          suggestion = "Using default settings";
        }] else [];
    in
    {
      isSupported = isSupported;
      errors = errors;
      warnings = warnings;
      platform = platform;
      supportedPlatforms = supportedPlatforms;
    };

  # Generate platform-specific shell initialization
  generatePlatformShellInit = { platform ? detectPlatform }:
    let
      platformInfo = getPlatformInfo;
    in
    ''
      # Platform-specific initialization for ${platform}
      export DOTFILES_PLATFORM="${platform}"
      
      ${if platform == "macos" then ''
        # macOS-specific initialization
        export DOTFILES_PLATFORM_IS_MACOS="true"
        export DOTFILES_PLATFORM_IS_LINUX="false"
        
        # Add Homebrew to PATH if it exists
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        # macOS-specific aliases
        alias finder='open -a Finder'
        alias flushdns='sudo dscacheutil -flushcache'
        alias airport='sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'
        
        # Show/hide hidden files in Finder
        alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
        alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
        
      '' else ''
        # Linux-specific initialization
        export DOTFILES_PLATFORM_IS_MACOS="false"
        export DOTFILES_PLATFORM_IS_LINUX="true"
        
        # Set XDG directories
        export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
        export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
        export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
        export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
        
        # Linux-specific aliases
        alias ll='ls -alF'
        alias la='ls -A'
        alias l='ls -CF'
        alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
        
        # System management aliases
        if command -v systemctl >/dev/null 2>&1; then
          alias sc='systemctl'
          alias scu='systemctl --user'
          alias jc='journalctl'
          alias jcu='journalctl --user'
        fi
      ''}
      
      # Common platform utilities
      ${concatStringsSep "\n" (mapAttrsToList (name: value: "alias ${name}='${value}'") (generatePlatformAliases { inherit platform; }))}
    '';

in
{
  inherit detectPlatform getPlatformInfo filterModulesByPlatform;
  inherit applyPlatformSettings generatePlatformAliases generatePlatformEnvironment;
  inherit getPlatformPackages validatePlatformCompatibility generatePlatformShellInit;
}