{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  dotfilesPath = cfg.dotfilesPath;
  
  # Module metadata and mappings
  moduleDefinitions = {
    # Core modules
    shell = {
      name = "Shell Configuration";
      description = "Bash and Zsh configuration with aliases and functions";
      files = {
        aliases = "${dotfilesPath}/../../modules/shell/shell_aliases";
        functions = "${dotfilesPath}/../../modules/shell/shell_functions";
        bashrc = "${dotfilesPath}/../../modules/shell/bashrc";
        zshrc = "${dotfilesPath}/../../modules/shell/zshrc";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    git = {
      name = "Git Configuration";
      description = "Git configuration with aliases and hooks";
      files = {
        config = "${dotfilesPath}/../../modules/git/gitconfig";
        ignore = "${dotfilesPath}/../../modules/git/gitignore_global";
        aliases = "${dotfilesPath}/../../modules/git/git_aliases";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    tmux = {
      name = "Tmux Configuration";
      description = "Terminal multiplexer configuration";
      files = {
        config = "${dotfilesPath}/../../modules/tmux/tmux.conf";
        plugins = "${dotfilesPath}/../../modules/tmux/plugins.conf";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    editors = {
      name = "Editor Configurations";
      description = "Vim and Neovim configurations";
      files = {
        vim = "${dotfilesPath}/../../modules/editors/vimrc";
        neovim = "${dotfilesPath}/../../modules/editors/init.vim";
      };
      dependencies = [];
      platforms = [ "linux" "darwin" ];
    };
    
    # Development modules
    docker = {
      name = "Docker Configuration";
      description = "Docker aliases and helper functions";
      files = {
        aliases = "${dotfilesPath}/../../modules/docker/docker_aliases";
        functions = "${dotfilesPath}/../../modules/docker/docker_functions";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    golang = {
      name = "Go Development";
      description = "Go development environment configuration";
      files = {
        config = "${dotfilesPath}/../../modules/golang/go_config";
        aliases = "${dotfilesPath}/../../modules/golang/go_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    python = {
      name = "Python Development";
      description = "Python development environment configuration";
      files = {
        config = "${dotfilesPath}/../../modules/python/python_config";
        aliases = "${dotfilesPath}/../../modules/python/python_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    nodejs = {
      name = "Node.js Development";
      description = "Node.js and npm configuration";
      files = {
        npmrc = "${dotfilesPath}/../../modules/nodejs/npmrc";
        aliases = "${dotfilesPath}/../../modules/nodejs/node_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    rust = {
      name = "Rust Development";
      description = "Rust development environment configuration";
      files = {
        config = "${dotfilesPath}/../../modules/rust/cargo_config";
        aliases = "${dotfilesPath}/../../modules/rust/rust_aliases";
      };
      dependencies = [ "shell" ];
      platforms = [ "linux" "darwin" ];
    };
    
    kubernetes = {
      name = "Kubernetes Tools";
      description = "Kubernetes and kubectl configuration";
      files = {
        config = "${dotfilesPath}/../../modules/kubernetes/kube_config";
        aliases = "${dotfilesPath}/../../modules/kubernetes/kube_aliases";
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