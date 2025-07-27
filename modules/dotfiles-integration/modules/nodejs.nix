{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for nodejs module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.nodejs or "merge"
    else
      "merge";
  
  # Read nodejs module configuration from module.yml
  nodejsModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/nodejs/module.yml";
  
  # Use default settings for now
  profileSettings = nodejsModuleConfig.settings;
  
  # Node.js configuration files from dotfiles
  nodeAliasesFile = "${dotfilesPath}/modules/nodejs/node_aliases";
  npmrcFile = "${dotfilesPath}/modules/nodejs/npmrc";
  nvmrcFile = "${dotfilesPath}/modules/nodejs/nvmrc";
  yarnrcFile = "${dotfilesPath}/modules/nodejs/yarnrc.yml";
  
  # Parse nodejs aliases
  parseNodeAliases = content:
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
  
  # Read and parse node aliases
  nodeAliases = 
    if builtins.pathExists nodeAliasesFile then
      parseNodeAliases (builtins.readFile nodeAliasesFile)
    else
      {};
  
  # Essential Node.js packages and tools
  nodePackages = with pkgs; [
    nodejs_22        # Node.js runtime
    npm             # Package manager
    yarn            # Alternative package manager
    pnpm            # Fast package manager
    nodePackages.nodemon      # Development server
    nodePackages.typescript   # TypeScript compiler
    nodePackages.ts-node      # TypeScript execution
    nodePackages.eslint       # Linter
    nodePackages.prettier     # Code formatter
    nodePackages.http-server  # Simple HTTP server
    nodePackages.json-server  # Mock API server
    nodePackages.concurrently # Run multiple commands
  ];
  
  # Default npmrc configuration
  defaultNpmrcConfig = ''
    # NPM Configuration
    registry=https://registry.npmjs.org/
    audit-level=moderate
    fund=false
    progress=true
    loglevel=warn
    cache-max=86400000
    save-exact=false
    save-prefix=^
    package-lock=true
    init-author-name="User"
    init-license="MIT"
    init-version="1.0.0"
  '';
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "nodejs" enabledModules)) {
    # Shell aliases for Node.js development
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      nodeAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      nodeAliases;
    
    # Node.js environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_NODEJS_MODULE = "active";
      DOTFILES_NODEJS_VERSION = nodejsModuleConfig.version or "unknown";
      NODE_ENV = "development";
      NPM_CONFIG_CACHE = "$HOME/.cache/npm";
      NODE_OPTIONS = "--max-old-space-size=4096";
    };
    
    # Install Node.js and essential development tools
    home.packages = mkIf (priorityMode != "nixconf") nodePackages;
    
    # NPM configuration
    home.file.".npmrc" = mkIf (priorityMode != "nixconf") {
      text = if builtins.pathExists npmrcFile then
        builtins.readFile npmrcFile
      else
        defaultNpmrcConfig;
    };
    
    # Yarn configuration
    home.file.".yarnrc.yml" = mkIf (priorityMode != "nixconf" && builtins.pathExists yarnrcFile) {
      source = yarnrcFile;
    };
    
    # Default Node version for NVM
    home.file.".nvmrc" = mkIf (priorityMode != "nixconf" && builtins.pathExists nvmrcFile) {
      source = nvmrcFile;
    };
    
    # Node.js-specific shell functions (embedded directly)
    programs.bash.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create new Node.js project
      node-init() {
        local name="''${1:-my-app}"
        mkdir -p "$name"
        cd "$name"
        npm init -y
        
        # Create basic structure
        echo "console.log('Hello, World!');" > index.js
        echo "node_modules/\n.env\n*.log" > .gitignore
        
        echo "Created Node.js project: $name"
      }
      
      # Clean install (remove node_modules and reinstall)
      npm-clean() {
        echo "Cleaning node_modules and package-lock.json..."
        rm -rf node_modules package-lock.json
        echo "Reinstalling dependencies..."
        npm install
      }
      
      # List globally installed packages
      npm-global() {
        npm list -g --depth=0
      }
      
      # Find and remove node_modules directories
      clean-node-modules() {
        echo "Finding node_modules directories..."
        local dirs=$(find . -name 'node_modules' -type d -prune)
        if [ -n "$dirs" ]; then
          echo "$dirs"
          read -p "Remove all node_modules directories? (y/N) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$dirs" | xargs rm -rf
            echo "Removed all node_modules directories"
          fi
        else
          echo "No node_modules directories found"
        fi
      }
      
      # Quick TypeScript setup
      ts-init() {
        npm init -y
        npm install --save-dev typescript @types/node ts-node nodemon
        npx tsc --init
        
        # Create src directory
        mkdir -p src
        echo "console.log('Hello from TypeScript!');" > src/index.ts
        
        echo "TypeScript project initialized"
      }
      
      # Show package.json scripts
      npm-scripts() {
        if [ -f package.json ]; then
          echo "Available npm scripts:"
          if command -v jq >/dev/null 2>&1; then
            cat package.json | jq -r '.scripts | to_entries[] | "\(.key): \(.value)"'
          else
            echo "jq not available - install jq to view scripts nicely"
          fi
        else
          echo "No package.json found"
        fi
      }
      
      # Create .nvmrc file with current Node version
      nvm-save() {
        node --version > .nvmrc
        echo "Saved Node $(cat .nvmrc) to .nvmrc"
      }
    '';
    
    # Same functions for zsh
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf") ''
      # Create new Node.js project
      node-init() {
        local name="''${1:-my-app}"
        mkdir -p "$name"
        cd "$name"
        npm init -y
        
        # Create basic structure
        echo "console.log('Hello, World!');" > index.js
        echo "node_modules/\n.env\n*.log" > .gitignore
        
        echo "Created Node.js project: $name"
      }
      
      # Clean install (remove node_modules and reinstall)
      npm-clean() {
        echo "Cleaning node_modules and package-lock.json..."
        rm -rf node_modules package-lock.json
        echo "Reinstalling dependencies..."
        npm install
      }
      
      # List globally installed packages
      npm-global() {
        npm list -g --depth=0
      }
      
      # Find and remove node_modules directories
      clean-node-modules() {
        echo "Finding node_modules directories..."
        local dirs=$(find . -name 'node_modules' -type d -prune)
        if [ -n "$dirs" ]; then
          echo "$dirs"
          read -p "Remove all node_modules directories? (y/N) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$dirs" | xargs rm -rf
            echo "Removed all node_modules directories"
          fi
        else
          echo "No node_modules directories found"
        fi
      }
      
      # Quick TypeScript setup
      ts-init() {
        npm init -y
        npm install --save-dev typescript @types/node ts-node nodemon
        npx tsc --init
        
        # Create src directory
        mkdir -p src
        echo "console.log('Hello from TypeScript!');" > src/index.ts
        
        echo "TypeScript project initialized"
      }
      
      # Show package.json scripts
      npm-scripts() {
        if [ -f package.json ]; then
          echo "Available npm scripts:"
          if command -v jq >/dev/null 2>&1; then
            cat package.json | jq -r '.scripts | to_entries[] | "\(.key): \(.value)"'
          else
            echo "jq not available - install jq to view scripts nicely"
          fi
        else
          echo "No package.json found"
        fi
      }
      
      # Create .nvmrc file with current Node version
      nvm-save() {
        node --version > .nvmrc
        echo "Saved Node $(cat .nvmrc) to .nvmrc"
      }
    '';
  };
}