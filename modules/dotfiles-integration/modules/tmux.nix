{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  settingsParser = import ../settings-parser.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for tmux module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.tmux or "merge"
    else
      "merge";
  
  # Read tmux module configuration from module.yml
  tmuxModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/tmux/module.yml";
  
  # Parse and apply module settings
  settingDefinitions = settingsParser.parseModuleSettings tmuxModuleConfig;
  
  # Apply profile-specific settings
  profileTmuxConfig = settingsParser.applyProfileSettings {
    moduleConfig = tmuxModuleConfig;
    profile = cfg.user.profile or "default";
  };
  
  # Get user overrides from Nix configuration
  userOverrides = cfg.modules.tmux.settings or {};
  
  # Apply user overrides to module settings
  overrideResult = settingsParser.applyUserOverrides {
    moduleSettings = profileTmuxConfig.settings;
    userOverrides = userOverrides;
  };
  
  # Final settings after all processing
  profileSettings = overrideResult.settings;
  
  # Tmux configuration files from dotfiles
  tmuxConfFile = "${dotfilesPath}/modules/tmux/tmux.conf";
  tmuxAliasesFile = "${dotfilesPath}/modules/tmux/tmux_aliases";
  tmuxPluginsFile = "${dotfilesPath}/modules/tmux/plugins.txt";
  tmuxThemeFile = "${dotfilesPath}/modules/tmux/themes/${profileSettings.tmux_theme or "default"}.tmux";
  
  # Read tmux configuration
  tmuxConfig = 
    if builtins.pathExists tmuxConfFile then
      builtins.readFile tmuxConfFile
    else
      "";
  
  # Parse TPM plugins from configuration
  parseTmuxPlugins = content:
    let
      # Extract plugin definitions from tmux config
      lines = splitString "\n" content;
      pluginLines = filter (line: hasInfix "set -g @plugin" line) lines;
      
      parsePluginLine = line:
        let
          # Match: set -g @plugin 'user/repo'
          pluginMatch = builtins.match "^.*set -g @plugin ['\"]([^'\"]+)['\"].*$" line;
        in
        if pluginMatch != null then
          let
            pluginSpec = elemAt pluginMatch 0;
            parts = splitString "/" pluginSpec;
          in
          if length parts == 2 then
            {
              user = elemAt parts 0;
              repo = elemAt parts 1;
              full = pluginSpec;
            }
          else null
        else null;
      
      plugins = filter (p: p != null) (map parsePluginLine pluginLines);
    in
    plugins;
  
  # Read plugins list from separate file if it exists
  parsePluginsFile = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      plugins = map (line: 
        let parts = splitString "/" (lib.trim line); in
        if length parts == 2 then
          { user = elemAt parts 0; repo = elemAt parts 1; full = lib.trim line; }
        else null
      ) lines;
    in
    filter (p: p != null) plugins;
  
  # Collect all plugins from both sources
  configPlugins = parseTmuxPlugins tmuxConfig;
  filePlugins = if builtins.pathExists tmuxPluginsFile then
    parsePluginsFile (builtins.readFile tmuxPluginsFile)
  else [];
  
  allPlugins = configPlugins ++ filePlugins;
  
  # Map plugin specs to nixpkgs tmux plugins
  mapPluginToNixpkg = plugin:
    let
      pluginName = plugin.repo;
      # Common plugin mappings
      nixpkgMappings = {
        "tmux-sensible" = pkgs.tmuxPlugins.sensible;
        "tmux-yank" = pkgs.tmuxPlugins.yank;
        "tmux-pain-control" = pkgs.tmuxPlugins.pain-control;
        "tmux-sessionist" = pkgs.tmuxPlugins.sessionist;
        "tmux-continuum" = pkgs.tmuxPlugins.continuum;
        "tmux-resurrect" = pkgs.tmuxPlugins.resurrect;
        "tmux-fzf" = pkgs.tmuxPlugins.fzf-tmux-url;
        "tmux-copycat" = pkgs.tmuxPlugins.copycat;
        "tmux-open" = pkgs.tmuxPlugins.open;
        "tmux-urlview" = pkgs.tmuxPlugins.urlview;
        "tmux-cpu" = pkgs.tmuxPlugins.cpu;
        "tmux-battery" = pkgs.tmuxPlugins.battery;
        "tmux-online-status" = pkgs.tmuxPlugins.online-status;
        "tmux-prefix-highlight" = pkgs.tmuxPlugins.prefix-highlight;
        "tmux-sidebar" = pkgs.tmuxPlugins.sidebar;
        "tmux-fingers" = pkgs.tmuxPlugins.fingers;
        "tmux-fpp" = pkgs.tmuxPlugins.fpp;
        # Theme plugins
        "tmux-themepack" = pkgs.tmuxPlugins.themepack;
        "nord-tmux" = pkgs.tmuxPlugins.nord;
        "tmux-power" = null; # Not available in nixpkgs
        "dracula-tmux" = null; # Not available in nixpkgs
      };
    in
    nixpkgMappings.${pluginName} or null;
  
  # Get available plugins
  availablePlugins = filter (p: p != null) (map mapPluginToNixpkg allPlugins);
  
  # Check for plugin dependencies
  checkPluginDependencies = plugins:
    let
      pluginNames = map (p: p.repo) plugins;
      
      # Define plugin dependencies
      dependencies = {
        "tmux-continuum" = ["tmux-resurrect"];
        "tmux-resurrect" = [];
        "tmux-yank" = [];
        "tmux-sensible" = [];
      };
      
      checkDeps = pluginName:
        let
          deps = dependencies.${pluginName} or [];
          missingDeps = filter (dep: !(elem dep pluginNames)) deps;
        in
        if missingDeps == [] then null
        else { plugin = pluginName; missing = missingDeps; };
      
      depCheckResults = filter (r: r != null) (map checkDeps pluginNames);
    in
    {
      hasMissingDependencies = depCheckResults != [];
      missingDependencies = depCheckResults;
    };
  
  # Check dependencies
  dependencyCheck = checkPluginDependencies allPlugins;
  
  # Generate theme configuration
  generateThemeConfig = 
    let
      theme = profileSettings.tmux_theme or "default";
      customTheme = profileSettings.custom_theme_config or "";
    in
    if theme == "nord" then ''
      # Nord theme configuration
      set -g @nord_tmux_show_status_content "0"
      set -g @nord_tmux_no_patched_font "1"
    ''
    else if theme == "dracula" then ''
      # Dracula theme configuration
      set -g @dracula-plugins "cpu-usage ram-usage"
      set -g @dracula-show-powerline true
      set -g @dracula-show-flags true
      set -g @dracula-show-left-icon session
    ''
    else if theme == "powerline" then ''
      # Powerline theme configuration
      set -g @themepack 'powerline/default/cyan'
    ''
    else if theme == "custom" then
      customTheme
    else
      # Default theme
      ''
        # Default theme configuration
        set -g status-style 'bg=#333333 fg=#ffffff'
        set -g window-status-current-style 'bg=#0087ff fg=#ffffff'
      '';
  
  # Read theme file if it exists
  themeConfig = 
    if builtins.pathExists tmuxThemeFile then
      builtins.readFile tmuxThemeFile
    else
      generateThemeConfig;
  
  # Parse tmux aliases
  parseTmuxAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          match = builtins.match "alias ([^=]+)='([^']+)'.*" line;
        in
        if match != null then
          { name = elemAt match 0; value = elemAt match 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse tmux aliases
  tmuxAliases = 
    if builtins.pathExists tmuxAliasesFile then
      parseTmuxAliases (builtins.readFile tmuxAliasesFile)
    else
      {};
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "tmux" enabledModules)) {
    # Direct file links when priority mode is "dotfiles"
    home.file = mkIf (priorityMode == "dotfiles") {
      ".config/tmux/tmux.conf" = mkIf (builtins.pathExists tmuxConfFile) {
        source = tmuxConfFile;
      };
    };
    
    # Tmux program configuration
    programs.tmux = mkIf (priorityMode != "dotfiles") {
      enable = true;
      
      # Base configuration from settings
      baseIndex = mkDefault (profileSettings.base_index or 1);
      clock24 = mkDefault (profileSettings.clock_24h or true);
      escapeTime = mkDefault (profileSettings.escape_time or 0);
      historyLimit = mkDefault (profileSettings.history_limit or 50000);
      mouse = mkDefault (profileSettings.enable_mouse or true);
      terminal = mkDefault (profileSettings.terminal or "screen-256color");
      
      # Key bindings
      keyMode = mkDefault (profileSettings.key_mode or "emacs");
      prefix = mkDefault (profileSettings.prefix_key or "C-b");
      
      # Extra configuration based on priority mode
      extraConfig = mkMerge [
        # Base dotfiles configuration
        (mkIf (priorityMode != "nixconf")
          (if priorityMode == "separate" then
            ''
              # Source dotfiles tmux configuration
              source-file ${tmuxConfFile}
            ''
          else
            tmuxConfig))
        
        # Theme configuration
        (mkIf (priorityMode != "nixconf" && profileSettings.enable_theming or true)
          themeConfig)
        
        # Plugin configuration warnings
        (mkIf dependencyCheck.hasMissingDependencies
          ''
            # Plugin dependency warnings
            ${concatStringsSep "\n" (map (dep: 
              "# WARNING: Plugin ${dep.plugin} requires: ${concatStringsSep ", " dep.missing}"
            ) dependencyCheck.missingDependencies)}
          '')
        
        # TPM initialization (if plugins are detected but we're using nixpkgs plugins)
        (mkIf (allPlugins != [] && profileSettings.use_tpm or false)
          ''
            # TPM plugin manager initialization
            # Note: Using nixpkgs plugins instead of TPM for better reproducibility
            # Original TPM plugins: ${concatStringsSep ", " (map (p: p.full) allPlugins)}
          '')
      ];
      
      # Enhanced plugin management
      plugins = mkIf (priorityMode != "nixconf" && availablePlugins != []) (
        availablePlugins ++
        # Add theme plugins based on settings
        (if profileSettings.tmux_theme == "nord" && pkgs.tmuxPlugins ? nord then [pkgs.tmuxPlugins.nord] else []) ++
        (if profileSettings.tmux_theme == "powerline" && pkgs.tmuxPlugins ? themepack then [pkgs.tmuxPlugins.themepack] else []) ++
        # Add essential plugins if not explicitly configured
        (if allPlugins == [] && profileSettings.use_default_plugins or true then [
          pkgs.tmuxPlugins.sensible
          pkgs.tmuxPlugins.yank
          pkgs.tmuxPlugins.pain-control
        ] else [])
      );
    };
    
    # Shell aliases for tmux
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      tmuxAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      tmuxAliases;
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_TMUX_MODULE = "active";
      DOTFILES_TMUX_VERSION = tmuxModuleConfig.version or "unknown";
      DOTFILES_TMUX_THEME = profileSettings.tmux_theme or "default";
      DOTFILES_TMUX_PLUGINS_COUNT = toString (length availablePlugins);
      DOTFILES_TMUX_TPM_DETECTED = toString (allPlugins != []);
      DOTFILES_TMUX_DEPENDENCY_ERRORS = toString dependencyCheck.hasMissingDependencies;
    };
  };
}