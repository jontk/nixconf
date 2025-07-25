{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for golang module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.golang or "merge"
    else
      "merge";
  
  # Read golang module configuration from module.yml
  golangModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/golang/module.yml";
  
  # Use default settings for now
  profileSettings = golangModuleConfig.settings;
  
  # Golang configuration files from dotfiles
  goAliasesFile = "${dotfilesPath}/modules/golang/go_aliases";
  goEnvFile = "${dotfilesPath}/modules/golang/goenv";
  golangciConfigFile = "${dotfilesPath}/modules/golang/golangci.yml";
  
  # Parse golang aliases
  parseGoAliases = content:
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
  
  # Read and parse go aliases
  goAliases = 
    if builtins.pathExists goAliasesFile then
      parseGoAliases (builtins.readFile goAliasesFile)
    else
      {};
  
  # Parse environment variables from goenv file
  parseGoEnv = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l) && (hasPrefix "export " l)) (splitString "\n" content);
      parseEnvVar = line:
        let
          # Remove 'export ' prefix and split on '='
          withoutExport = removePrefix "export " line;
          match = builtins.match "([^=]+)=\"?([^\"]*)\"?.*" withoutExport;
        in
        if match != null then
          { name = elemAt match 0; value = elemAt match 1; }
        else null;
      envVars = filter (e: e != null) (map parseEnvVar lines);
    in
    listToAttrs (map (e: nameValuePair e.name e.value) envVars);
  
  # Read and parse go environment variables
  goEnvVars = 
    if builtins.pathExists goEnvFile then
      parseGoEnv (builtins.readFile goEnvFile)
    else
      {};
  
  # Default Go environment variables with user overrides
  defaultGoEnv = {
    GOPATH = "\${HOME}/go";
    GOBIN = "\${GOPATH}/bin";
    GO111MODULE = "on";
    GOPROXY = "https://proxy.golang.org,direct";
    GOSUMDB = "sum.golang.org";
    GOPRIVATE = "";
    CGO_ENABLED = "1";
    GOLANGCI_LINT_CACHE = "\${HOME}/.cache/golangci-lint";
  };
  
  # Combine default and parsed environment variables
  allGoEnv = defaultGoEnv // goEnvVars;
  
  # Essential Go tools to install
  goTools = with pkgs; [
    go
    gopls            # Language server
    delve            # Debugger (dlv)
    golangci-lint    # Linter
    goimports        # Import formatter
    gotestsum        # Test runner with better output
  ];
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "golang" enabledModules)) {
    # Shell aliases for Go development
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      goAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      goAliases;
    
    # Go environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") (allGoEnv // {
      DOTFILES_GOLANG_MODULE = "active";
      DOTFILES_GOLANG_VERSION = golangModuleConfig.version or "unknown";
    });
    
    # Add GOBIN to PATH
    home.sessionPath = mkIf (priorityMode != "nixconf") [
      "\${GOBIN}"
    ];
    
    # Install Go and essential development tools
    home.packages = mkIf (priorityMode != "nixconf") goTools;
    
    # Copy golangci-lint configuration
    home.file.".golangci.yml" = mkIf (priorityMode != "nixconf" && builtins.pathExists golangciConfigFile) {
      source = golangciConfigFile;
    };
    
    # Set up Go workspace structure via activation script
    home.activation.setupGoWorkspace = mkIf (priorityMode != "nixconf") (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p "$HOME/go"/{bin,pkg,src}
        $DRY_RUN_CMD mkdir -p "$HOME/go/src/github.com/$(whoami)" 2>/dev/null || true
      ''
    );
    
    # Go-specific shell functions (embedded directly)
    programs.bash.initExtra = mkIf (priorityMode != "nixconf") ''
      # Go project creation helper
      gonew() {
        local name=''${1:-"go-project"}
        local module=''${2:-"github.com/username/$name"}
        
        mkdir -p "$name"
        cd "$name"
        go mod init "$module"
        
        cat > main.go << EOF
      package main
      
      import "fmt"
      
      func main() {
          fmt.Println("Hello, $name!")
      }
      EOF
        
        echo "Go project '$name' created with module '$module'"
      }
      
      # Go tools installation
      gotools() {
        echo "Installing essential Go tools..."
        go install golang.org/x/tools/gopls@latest
        go install github.com/go-delve/delve/cmd/dlv@latest
        go install golang.org/x/tools/cmd/goimports@latest
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
        go install gotest.tools/gotestsum@latest
        go install github.com/cosmtrek/air@latest
        echo "Go tools installed successfully!"
      }
      
      # Test coverage helper
      gotest-coverage() {
        go test -coverprofile=coverage.out ./...
        go tool cover -html=coverage.out -o coverage.html
        echo "Coverage report generated: coverage.html"
      }
      
      # Go environment info
      goinfo() {
        echo "Go Environment Information:"
        echo "=========================="
        echo "Go Version: $(go version)"
        echo "GOPATH: $GOPATH"
        echo "GOBIN: $GOBIN"
        echo "GO111MODULE: $GO111MODULE"
        echo "GOPROXY: $GOPROXY"
        echo "GOPRIVATE: $GOPRIVATE"
      }
    '';
    
    # Same functions for zsh
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf") ''
      # Go project creation helper
      gonew() {
        local name=''${1:-"go-project"}
        local module=''${2:-"github.com/username/$name"}
        
        mkdir -p "$name"
        cd "$name"
        go mod init "$module"
        
        cat > main.go << EOF
      package main
      
      import "fmt"
      
      func main() {
          fmt.Println("Hello, $name!")
      }
      EOF
        
        echo "Go project '$name' created with module '$module'"
      }
      
      # Go tools installation
      gotools() {
        echo "Installing essential Go tools..."
        go install golang.org/x/tools/gopls@latest
        go install github.com/go-delve/delve/cmd/dlv@latest
        go install golang.org/x/tools/cmd/goimports@latest
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
        go install gotest.tools/gotestsum@latest
        go install github.com/cosmtrek/air@latest
        echo "Go tools installed successfully!"
      }
      
      # Test coverage helper
      gotest-coverage() {
        go test -coverprofile=coverage.out ./...
        go tool cover -html=coverage.out -o coverage.html
        echo "Coverage report generated: coverage.html"
      }
      
      # Go environment info
      goinfo() {
        echo "Go Environment Information:"
        echo "=========================="
        echo "Go Version: $(go version)"
        echo "GOPATH: $GOPATH"
        echo "GOBIN: $GOBIN"
        echo "GO111MODULE: $GO111MODULE"
        echo "GOPROXY: $GOPROXY"
        echo "GOPRIVATE: $GOPRIVATE"
      }
    '';
  };
}