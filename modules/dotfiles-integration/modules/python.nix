{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for python module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.python or "merge"
    else
      "merge";
  
  # Read python module configuration from module.yml
  pythonModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/python/module.yml";
  
  # Use default settings for now
  profileSettings = pythonModuleConfig.settings;
  
  # Python configuration files from dotfiles
  pythonAliasesFile = "${dotfilesPath}/modules/python/python_aliases";
  pythonrcFile = "${dotfilesPath}/modules/python/pythonrc";
  pipConfigFile = "${dotfilesPath}/modules/python/pip.conf";
  pdbrcFile = "${dotfilesPath}/modules/python/pdbrc";
  
  # Parse python aliases
  parsePythonAliases = content:
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
  
  # Read and parse python aliases
  pythonAliases = 
    if builtins.pathExists pythonAliasesFile then
      parsePythonAliases (builtins.readFile pythonAliasesFile)
    else
      {};
  
  # Essential Python packages and tools
  pythonPackages = with pkgs; [
    python3Full
    python3Packages.pip
    python3Packages.setuptools
    python3Packages.wheel
    python3Packages.virtualenv
    python3Packages.pipenv
    python3Packages.black      # Code formatter
    python3Packages.flake8     # Linter
    python3Packages.mypy       # Type checker
    python3Packages.pytest     # Testing framework
    python3Packages.ipython    # Enhanced REPL
    python3Packages.jupyter    # Jupyter notebooks
    python3Packages.requests   # HTTP library
    python3Packages.click      # CLI library
    poetry                     # Dependency management
  ];
  
  # Default pip configuration
  defaultPipConfig = ''
    [global]
    timeout = 60
    index-url = https://pypi.org/simple/
    trusted-host = pypi.org
                   files.pythonhosted.org
    
    [install]
    user = true
    upgrade-strategy = only-if-needed
    
    [list]
    format = columns
  '';
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "python" enabledModules)) {
    # Shell aliases for Python development
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      pythonAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      pythonAliases;
    
    # Python environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_PYTHON_MODULE = "active";
      DOTFILES_PYTHON_VERSION = pythonModuleConfig.version or "unknown";
      PYTHONSTARTUP = "$HOME/.pythonrc";
      PYTHONDONTWRITEBYTECODE = "1";  # Don't create .pyc files
      PIP_REQUIRE_VIRTUALENV = "false";  # Allow global pip installs
      PIP_CACHE_DIR = "$HOME/.cache/pip";
    };
    
    # Install Python and essential development tools
    home.packages = mkIf (priorityMode != "nixconf") pythonPackages;
    
    # Python startup configuration
    home.file.".pythonrc" = mkIf (priorityMode != "nixconf" && builtins.pathExists pythonrcFile) {
      source = pythonrcFile;
    };
    
    # Pip configuration
    home.file.".pip/pip.conf" = mkIf (priorityMode != "nixconf") {
      text = if builtins.pathExists pipConfigFile then
        builtins.readFile pipConfigFile
      else
        defaultPipConfig;
    };
    
    # Python debugger configuration
    home.file.".pdbrc" = mkIf (priorityMode != "nixconf" && builtins.pathExists pdbrcFile) {
      source = pdbrcFile;
    };
    
    # Python-specific shell functions (embedded directly)
    programs.bash.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create and activate virtual environment
      mkvenv() {
        local name="''${1:-venv}"
        python3 -m venv "$name"
        source "$name/bin/activate"
        pip install --upgrade pip setuptools wheel
        echo "Created and activated virtual environment: $name"
      }
      
      # Remove virtual environment
      rmvenv() {
        local name="''${1:-venv}"
        if [[ -d "$name" ]]; then
          deactivate 2>/dev/null
          rm -rf "$name"
          echo "Removed virtual environment: $name"
        else
          echo "Virtual environment not found: $name"
        fi
      }
      
      # Clean Python cache files
      pyclean() {
        find . -type f -name '*.py[co]' -delete
        find . -type d -name '__pycache__' -exec rm -rf {} +
        find . -type d -name '.pytest_cache' -exec rm -rf {} +
        echo "Python cache files cleaned"
      }
      
      # Python REPL with common imports
      pyrepl() {
        python3 -i -c "
      import os, sys, json, re
      from pathlib import Path
      from pprint import pprint
      print('Loaded: os, sys, json, re, Path, pprint')
      "
      }
      
      # Show Python path information
      pypath() {
        python3 -c "
      import sys
      print('Python version:', sys.version)
      print('\nPython executable:', sys.executable)
      print('\nPython path:')
      for p in sys.path:
          print('  ', p)
      "
      }
      
      # Create requirements.txt from current environment
      pipfreeze() {
        pip freeze > requirements.txt
        echo "Created requirements.txt"
      }
    '';
    
    # Same functions for zsh
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create and activate virtual environment
      mkvenv() {
        local name="''${1:-venv}"
        python3 -m venv "$name"
        source "$name/bin/activate"
        pip install --upgrade pip setuptools wheel
        echo "Created and activated virtual environment: $name"
      }
      
      # Remove virtual environment
      rmvenv() {
        local name="''${1:-venv}"
        if [[ -d "$name" ]]; then
          deactivate 2>/dev/null
          rm -rf "$name"
          echo "Removed virtual environment: $name"
        else
          echo "Virtual environment not found: $name"
        fi
      }
      
      # Clean Python cache files
      pyclean() {
        find . -type f -name '*.py[co]' -delete
        find . -type d -name '__pycache__' -exec rm -rf {} +
        find . -type d -name '.pytest_cache' -exec rm -rf {} +
        echo "Python cache files cleaned"
      }
      
      # Python REPL with common imports
      pyrepl() {
        python3 -i -c "
      import os, sys, json, re
      from pathlib import Path
      from pprint import pprint
      print('Loaded: os, sys, json, re, Path, pprint')
      "
      }
      
      # Show Python path information
      pypath() {
        python3 -c "
      import sys
      print('Python version:', sys.version)
      print('\nPython executable:', sys.executable)
      print('\nPython path:')
      for p in sys.path:
          print('  ', p)
      "
      }
      
      # Create requirements.txt from current environment
      pipfreeze() {
        pip freeze > requirements.txt
        echo "Created requirements.txt"
      }
    '';
  };
}