{ config, lib, pkgs, inputs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  dotfilesPath = cfg.dotfilesPath;
  dotfilesRoot = if dotfilesPath == null then "/var/empty" else toString dotfilesPath;
  
  # Module metadata and mappings
  moduleDefinitions = {
    # Core modules
    shell = {
      name = "Shell Configuration";
      description = "Bash and Zsh configuration with aliases and functions";
      files = {
        aliases = "${dotfilesRoot}/../../modules/shell/shell_aliases";
        functions = "${dotfilesRoot}/../../modules/shell/shell_functions";
        bashrc = "${dotfilesRoot}/../../modules/shell/bashrc";
        zshrc = "${dotfilesRoot}/../../modules/shell/zshrc";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    git = {
      name = "Git Configuration";
      description = "Git configuration with aliases and hooks";
      files = {
        config = "${dotfilesRoot}/../../modules/git/gitconfig";
        ignore = "${dotfilesRoot}/../../modules/git/gitignore_global";
        aliases = "${dotfilesRoot}/../../modules/git/git_aliases";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    tmux = {
      name = "Tmux Configuration";
      description = "Terminal multiplexer configuration";
      files = {
        config = "${dotfilesRoot}/../../modules/tmux/tmux.conf";
        plugins = "${dotfilesRoot}/../../modules/tmux/plugins.conf";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    editors = {
      name = "Editor Configurations";
      description = "Vim and Neovim configurations";
      files = {
        vim = "${dotfilesRoot}/../../modules/editors/vimrc";
        neovim = "${dotfilesRoot}/../../modules/editors/init.vim";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    # Development modules
    docker = {
      name = "Docker Configuration";
      description = "Docker aliases and helper functions";
      files = {
        aliases = "${dotfilesRoot}/../../modules/docker/docker_aliases";
        functions = "${dotfilesRoot}/../../modules/docker/docker_functions";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    golang = {
      name = "Go Development";
      description = "Go development environment configuration";
      files = {
        config = "${dotfilesRoot}/../../modules/golang/go_config";
        aliases = "${dotfilesRoot}/../../modules/golang/go_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    python = {
      name = "Python Development";
      description = "Python development environment configuration";
      files = {
        config = "${dotfilesRoot}/../../modules/python/python_config";
        aliases = "${dotfilesRoot}/../../modules/python/python_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    nodejs = {
      name = "Node.js Development";
      description = "Node.js and npm configuration";
      files = {
        npmrc = "${dotfilesRoot}/../../modules/nodejs/npmrc";
        aliases = "${dotfilesRoot}/../../modules/nodejs/node_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    rust = {
      name = "Rust Development";
      description = "Rust development environment configuration";
      files = {
        config = "${dotfilesRoot}/../../modules/rust/cargo_config";
        aliases = "${dotfilesRoot}/../../modules/rust/rust_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    kubernetes = {
      name = "Kubernetes Tools";
      description = "Kubernetes and kubectl configuration";
      files = {
        config = "${dotfilesRoot}/../../modules/kubernetes/kube_config";
        aliases = "${dotfilesRoot}/../../modules/kubernetes/kube_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
  };
  
  # Helper function to resolve module dependencies
  resolveDependencies = module: 
    let
      deps = moduleDefinitions.${module}.dependencies or [];
      transitiveDeps = concatMap resolveDependencies deps;
    in
    unique (deps ++ transitiveDeps);
  
  # Helper function to check platform compatibility
  isPlatformCompatible = module:
    let
      supportedPlatforms = moduleDefinitions.${module}.platforms or [ "linux" "darwin" ];
      currentPlatform = if pkgs.stdenv.isDarwin then "darwin" else "linux";
    in
    elem currentPlatform supportedPlatforms;
  
  # Helper function to get enabled modules with dependencies
  getEnabledModules = 
    let
      # Get explicitly enabled modules
      enabledCore = filterAttrs (n: v: v) cfg.modules.core;
      enabledDev = filterAttrs (n: v: v) cfg.modules.development;
      explicitlyEnabled = (attrNames enabledCore) ++ (attrNames enabledDev);
      
      # Add all dependencies
      allEnabled = unique (explicitlyEnabled ++ (concatMap resolveDependencies explicitlyEnabled));
      
      # Filter by platform compatibility
      compatibleModules = filter isPlatformCompatible allEnabled;
    in
    compatibleModules;
  
  # Helper function to check if a file exists
  fileExists = path: builtins.pathExists path;
  
  # Helper function to read file content if it exists
  readFileIfExists = path:
    if fileExists path then
      builtins.readFile path
    else
      "";
in
{
  # Export module definitions and helper functions
  _module.args = {
    dotfilesModules = {
      inherit moduleDefinitions;
      inherit resolveDependencies;
      inherit isPlatformCompatible;
      inherit getEnabledModules;
      inherit fileExists;
      inherit readFileIfExists;
    };
  };
}
