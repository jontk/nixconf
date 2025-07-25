# User-level dotfiles integration options
# Mirrors the structure of enabled-modules.yml but in native Nix
{ lib, ... }:

with lib;

{
  options.dotfiles = {
    enable = mkEnableOption "dotfiles integration for this user";
    
    # User configuration (mirrors enabled-modules.yml user section)
    user = {
      profile = mkOption {
        type = types.str;
        default = "minimal";
        description = ''
          Profile to use from profiles.yml. Common profiles:
          - minimal: Basic shell and git
          - personal: Personal development environment
          - work: Work environment
          - server: Server environment
          - experimental: Cutting-edge tools
        '';
      };
      
      platform = mkOption {
        type = types.enum [ "auto" "macos" "linux" ];
        default = "auto";
        description = "Platform detection mode";
      };
      
      shell = mkOption {
        type = types.enum [ "auto" "bash" "zsh" "fish" ];
        default = "auto";
        description = "Shell detection mode";
      };
    };
    
    # Module enablement (mirrors enabled-modules.yml modules section)
    modules = {
      # Core modules
      shell = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable shell configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
        
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = ''
            Module-specific settings that override defaults from module.yml.
            Common settings:
            - enable_aliases: Enable shell aliases
            - enable_functions: Enable shell functions
            - enable_prompt: Enable custom prompt
            - shell_theme: Theme to use for shell customization
            - custom_prompt: Prompt style (minimal, powerline, git-aware)
            - enable_git_prompt: Show git branch in prompt
            - enable_time_prompt: Show time in prompt
            - enable_history: Enable command history
            - history_size: Number of commands to remember
            - enable_completion: Enable tab completion
          '';
          example = {
            enable_aliases = true;
            enable_functions = true;
            shell_theme = "powerline";
            custom_prompt = "git-aware";
            enable_git_prompt = true;
            enable_time_prompt = false;
            enable_history = true;
            history_size = 50000;
            enable_completion = true;
          };
        };
      };
      
      git = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable git configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
        
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = ''
            Module-specific settings that override defaults from module.yml.
            Common settings:
            - user_name: Git user name
            - user_email: Git user email
            - default_branch: Default branch name
            - enable_signing: Enable commit signing
            - signing_key: GPG signing key
          '';
          example = {
            user_name = "John Doe";
            user_email = "john.doe@example.com";
            default_branch = "main";
            enable_signing = true;
            signing_key = "ABC123DEF";
          };
        };
      };
      
      tmux = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable tmux configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
        
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = ''
            Module-specific settings that override defaults from module.yml.
            Common settings:
            - tmux_theme: Theme to use (default, nord, dracula, powerline, custom)
            - base_index: Starting index for windows and panes
            - clock_24h: Use 24-hour clock format
            - escape_time: Escape sequence delay in milliseconds
            - history_limit: Number of lines in history buffer
            - enable_mouse: Enable mouse support
            - terminal: Terminal type
            - key_mode: Key binding mode (emacs, vi)
            - prefix_key: Prefix key combination
            - enable_theming: Enable theme configuration
            - use_tpm: Use Tmux Plugin Manager
            - use_default_plugins: Use default plugin set
            - custom_theme_config: Custom theme configuration
          '';
          example = {
            tmux_theme = "nord";
            base_index = 1;
            clock_24h = true;
            escape_time = 0;
            history_limit = 100000;
            enable_mouse = true;
            terminal = "screen-256color";
            key_mode = "vi";
            prefix_key = "C-a";
            enable_theming = true;
            use_tpm = false;
            use_default_plugins = true;
          };
        };
      };
      
      editors = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable editor configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      # Development modules
      docker = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable docker configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
        
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = ''
            Module-specific settings that override defaults from module.yml.
            Common settings:
            - enable_compose: Enable docker-compose integration
            - default_registry: Default Docker registry
            - buildkit_enabled: Enable BuildKit
            - experimental_features: Enable experimental features
          '';
          example = {
            enable_compose = true;
            default_registry = "docker.io";
            buildkit_enabled = true;
            experimental_features = false;
          };
        };
      };
      
      golang = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable golang configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      python = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable python configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      nodejs = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable nodejs configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      rust = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable rust configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      kubernetes = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable kubernetes configuration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
      };
      
      # Claude AI integration module
      claude = {
        enabled = mkOption {
          type = types.enum [ "enabled" "disabled" "auto" ];
          default = "auto";
          description = "Enable Claude AI integration module";
        };
        
        autoEnable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable automatically based on profile";
        };
        
        reason = mkOption {
          type = types.str;
          default = "";
          description = "Reason for enabling/disabling this module";
        };
        
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = ''
            Module-specific settings that override defaults from module.yml.
            Common settings:
            - api_key: Claude API key (optional, can use env var)
            - default_model: Default Claude model to use
            - max_tokens: Maximum tokens for responses
            - temperature: Response creativity (0.0-1.0)
            - enable_functions: Enable shell functions
            - enable_workflow: Enable development workflow commands
            - cache_responses: Cache API responses
            - response_format: Output format (text, json, markdown)
          '';
          example = {
            default_model = "claude-3-opus-20240229";
            max_tokens = 4096;
            temperature = 0.7;
            enable_functions = true;
            enable_workflow = true;
            cache_responses = true;
            response_format = "markdown";
          };
        };
      };
    };
    
    # File management configuration
    fileManagement = {
      backupDirectory = mkOption {
        type = types.str;
        default = "~/.dotfiles-backups";
        description = "Directory to store file backups";
      };
      
      defaultConflictResolution = mkOption {
        type = types.enum [ "skip" "backup" "overwrite" "interactive" ];
        default = "backup";
        description = "Default strategy for resolving file conflicts";
      };
      
      enableAutoBackup = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically backup files before overwriting";
      };
      
      backupRetentionCount = mkOption {
        type = types.int;
        default = 5;
        description = "Number of backup files to retain per file";
      };
    };
    
    # Installation preferences (mirrors enabled-modules.yml installation section)
    installation = {
      backupExisting = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to backup existing files before installing";
      };
      
      useSymlinks = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use symlinks or copy files";
      };
      
      dryRun = mkOption {
        type = types.bool;
        default = false;
        description = "Test mode without making actual changes";
      };
    };
    
    # Logging configuration
    logging = {
      level = mkOption {
        type = types.enum [ "debug" "info" "warn" "error" ];
        default = "info";
        description = "Logging level for dotfiles integration";
      };
      
      enableVerbose = mkOption {
        type = types.bool;
        default = false;
        description = "Enable verbose logging";
      };
    };
    
    # Priority modes for individual modules
    priorityModes = mkOption {
      type = types.attrsOf (types.enum [ "merge" "override" "nixconf" "dotfiles" "separate" ]);
      default = {};
      example = {
        shell = "merge";
        git = "dotfiles";
        tmux = "nixconf";
      };
      description = ''
        Per-module priority configuration:
        - merge: Combine configurations
        - override: Module-specific override
        - nixconf: Use nixconf configuration
        - dotfiles: Use dotfiles configuration
        - separate: Keep configurations separate
      '';
    };
  };
}