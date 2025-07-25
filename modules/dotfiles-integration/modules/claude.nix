{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  settingsParser = import ../settings-parser.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for claude module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.claude or "merge"
    else
      "merge";
  
  # Read claude module configuration from module.yml
  claudeModulePath = "${dotfilesPath}/modules/claude/module.yml";
  claudeModuleConfig = 
    if builtins.pathExists claudeModulePath then
      yamlParser.readModuleConfig claudeModulePath
    else
      {
        name = "claude";
        description = "Claude AI integration commands";
        settings = {};
        files = [];
      };
  
  # Parse and apply module settings
  settingDefinitions = settingsParser.parseModuleSettings claudeModuleConfig;
  
  # Apply profile-specific settings
  profileClaudeConfig = settingsParser.applyProfileSettings {
    moduleConfig = claudeModuleConfig;
    profile = cfg.user.profile or "default";
  };
  
  # Get user overrides from Nix configuration
  userOverrides = cfg.modules.claude.settings or {};
  
  # Apply user overrides to module settings
  overrideResult = settingsParser.applyUserOverrides {
    moduleSettings = profileClaudeConfig.settings;
    userOverrides = userOverrides;
  };
  
  # Final settings after all processing
  profileSettings = overrideResult.settings;
  
  # Claude configuration files from dotfiles
  claudeConfigFile = "${dotfilesPath}/modules/claude/claude.conf";
  claudeCommandsFile = "${dotfilesPath}/modules/claude/claude_commands";
  claudeAliasesFile = "${dotfilesPath}/modules/claude/claude_aliases";
  
  # Parse claude commands configuration
  parseClaudeCommands = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      
      # Parse command definition
      parseCommand = line:
        let
          # Commands are in format: command_name|description|command
          parts = splitString "|" line;
        in
        if length parts >= 3 then
          {
            name = elemAt parts 0;
            description = elemAt parts 1;
            command = concatStringsSep "|" (drop 2 parts);
          }
        else null;
      
      commands = filter (c: c != null) (map parseCommand lines);
    in
    commands;
  
  # Read and parse claude commands
  claudeCommands = 
    if builtins.pathExists claudeCommandsFile then
      parseClaudeCommands (builtins.readFile claudeCommandsFile)
    else
      [];
  
  # Parse claude aliases
  parseClaudeAliases = content:
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
  
  # Read and parse claude aliases
  claudeAliases = 
    if builtins.pathExists claudeAliasesFile then
      parseClaudeAliases (builtins.readFile claudeAliasesFile)
    else
      {};
  
  # Generate claude command wrappers
  generateClaudeCommand = cmd:
    pkgs.writeShellScriptBin "claude-${cmd.name}" ''
      # ${cmd.description}
      ${cmd.command}
    '';
  
  # Claude development workflow integration
  claudeWorkflowCommands = {
    # Code review command
    "claude-review" = pkgs.writeShellScriptBin "claude-review" ''
      echo "=== Claude Code Review ==="
      FILES="''${@:-$(git diff --name-only HEAD)}"
      
      if [ -z "$FILES" ]; then
        echo "No files to review. Specify files or have uncommitted changes."
        exit 1
      fi
      
      echo "Reviewing files:"
      echo "$FILES" | sed 's/^/  - /'
      echo ""
      
      # Use Claude API if configured
      if [ -n "''${CLAUDE_API_KEY:-}" ]; then
        echo "Sending to Claude API for review..."
        # API integration would go here
      else
        echo "Set CLAUDE_API_KEY to enable API integration"
        echo "Opening files for manual review..."
        echo "$FILES" | xargs -I {} echo "Review: {}"
      fi
    '';
    
    # Documentation generation
    "claude-docs" = pkgs.writeShellScriptBin "claude-docs" ''
      echo "=== Claude Documentation Generator ==="
      TARGET="''${1:-.}"
      OUTPUT="''${2:-docs/generated}"
      
      echo "Generating documentation for: $TARGET"
      echo "Output directory: $OUTPUT"
      
      # Find all code files
      find "$TARGET" -type f \( -name "*.nix" -o -name "*.sh" -o -name "*.py" \) | while read -r file; do
        echo "Processing: $file"
        # Documentation generation logic would go here
      done
      
      echo "Documentation generation complete."
    '';
    
    # Test generation
    "claude-test" = pkgs.writeShellScriptBin "claude-test" ''
      echo "=== Claude Test Generator ==="
      FILE="''${1}"
      
      if [ -z "$FILE" ]; then
        echo "Usage: claude-test <file>"
        exit 1
      fi
      
      if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        exit 1
      fi
      
      echo "Generating tests for: $FILE"
      # Test generation logic would go here
      echo "Test generation complete."
    '';
    
    # Refactoring assistant
    "claude-refactor" = pkgs.writeShellScriptBin "claude-refactor" ''
      echo "=== Claude Refactoring Assistant ==="
      PATTERN="''${1}"
      REPLACEMENT="''${2}"
      
      if [ $# -lt 2 ]; then
        echo "Usage: claude-refactor <pattern> <replacement> [files...]"
        exit 1
      fi
      
      shift 2
      FILES="''${@:-$(find . -name "*.nix" -type f)}"
      
      echo "Refactoring pattern: $PATTERN -> $REPLACEMENT"
      echo "Files to process: $(echo "$FILES" | wc -w)"
      
      # Refactoring logic would go here
      echo "Refactoring complete."
    '';
  };
  
  # Claude-specific environment variables
  claudeEnvironment = {
    CLAUDE_COMMANDS_ENABLED = "true";
    CLAUDE_INTEGRATION_VERSION = claudeModuleConfig.version or "1.0.0";
    CLAUDE_DEFAULT_MODEL = profileSettings.default_model or "claude-3-opus-20240229";
    CLAUDE_MAX_TOKENS = toString (profileSettings.max_tokens or 4096);
    CLAUDE_TEMPERATURE = toString (profileSettings.temperature or 0.7);
  } // (if profileSettings.api_key or null != null then {
    CLAUDE_API_KEY = profileSettings.api_key;
  } else {});
  
  # Generate shell functions for claude integration
  claudeShellFunctions = ''
    # Claude quick query function
    claude() {
      local query="$*"
      if [ -z "$query" ]; then
        echo "Usage: claude <query>"
        return 1
      fi
      
      echo "Claude: Processing query..."
      # API call would go here
      echo "Query: $query"
    }
    
    # Claude context function
    claude-context() {
      local action="''${1:-show}"
      case "$action" in
        show)
          echo "Current Claude context:"
          echo "  Model: ''${CLAUDE_DEFAULT_MODEL}"
          echo "  Max tokens: ''${CLAUDE_MAX_TOKENS}"
          echo "  Temperature: ''${CLAUDE_TEMPERATURE}"
          ;;
        clear)
          echo "Clearing Claude context..."
          unset CLAUDE_CONTEXT
          ;;
        set)
          shift
          export CLAUDE_CONTEXT="$*"
          echo "Claude context set."
          ;;
        *)
          echo "Usage: claude-context [show|clear|set <context>]"
          return 1
          ;;
      esac
    }
    
    # Claude explain function
    claude-explain() {
      local file="''${1}"
      if [ -z "$file" ]; then
        echo "Usage: claude-explain <file>"
        return 1
      fi
      
      if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return 1
      fi
      
      echo "Claude: Explaining $file..."
      # Explanation logic would go here
    }
  '';

in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "claude" enabledModules)) {
    # Install claude command packages
    home.packages = 
      # Generated command wrappers
      (map generateClaudeCommand claudeCommands) ++
      # Workflow commands
      (attrValues claudeWorkflowCommands) ++
      # Additional claude tools
      (with pkgs; [
        # Any additional tools needed for claude integration
      ]);
    
    # Shell aliases
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      (claudeAliases // {
        # Additional default aliases
        clr = "claude-review";
        cld = "claude-docs";
        clt = "claude-test";
        clf = "claude-refactor";
      });
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      (claudeAliases // {
        # Additional default aliases
        clr = "claude-review";
        cld = "claude-docs";
        clt = "claude-test";
        clf = "claude-refactor";
      });
    
    # Shell initialization
    programs.bash.initExtra = mkIf (priorityMode != "nixconf" && profileSettings.enable_functions or true) ''
      # Claude shell functions
      ${claudeShellFunctions}
    '';
    
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf" && profileSettings.enable_functions or true) ''
      # Claude shell functions
      ${claudeShellFunctions}
    '';
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf")
      claudeEnvironment;
  };
}