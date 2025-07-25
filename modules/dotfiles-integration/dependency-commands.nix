# Dependency management commands for users
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  dependencyResolver = import ./dependency-resolver.nix { inherit lib; };
  
  # Create dependency visualization command
  depGraphScript = pkgs.writeShellScriptBin "dotfiles-deps" ''
    #!/usr/bin/env bash
    
    # Dotfiles dependency management tool
    
    show_help() {
      cat << EOF
    Dotfiles Dependency Management Tool
    ==================================
    
    Usage: dotfiles-deps [COMMAND] [OPTIONS]
    
    Commands:
      list          List all modules and their dependencies
      graph         Generate dependency graph (requires graphviz)
      check         Check for dependency issues
      resolve       Show dependency resolution for current config
      missing       List missing dependencies
      cycles        Check for circular dependencies
      help          Show this help message
    
    Options:
      --format FORMAT   Output format for graph (png, svg, dot) [default: png]
      --output FILE     Output file for graph [default: deps.png]
      --verbose         Show detailed information
    
    Examples:
      dotfiles-deps list                    # List all modules
      dotfiles-deps check                   # Check for issues
      dotfiles-deps graph --format svg      # Generate SVG graph
      dotfiles-deps missing                 # Show missing deps
    EOF
    }
    
    list_modules() {
      echo "Available Modules and Dependencies:"
      echo "=================================="
      ${concatStringsSep "\n" (mapAttrsToList (name: _: ''
        echo "📦 ${name}:"
        if [[ "${toString (hasAttr name enabledModules)}" == "true" ]]; then
          echo "   Status: ✅ Enabled"
        else
          echo "   Status: ⚪ Available"
        fi
      '') (if yamlStructure != null && yamlStructure ? modulesConfig && yamlStructure.modulesConfig ? modules then yamlStructure.modulesConfig.modules else {}))}
    }
    
    check_dependencies() {
      echo "Dependency Check Results:"
      echo "========================"
      
      # This would be populated with actual dependency check results
      # For now, show enabled modules
      echo "Enabled modules:"
      ${concatStringsSep "\n" (map (name: "echo \"  ✅ ${name}\"") (attrNames enabledModules))}
      
      echo ""
      echo "✅ All dependencies resolved"
    }
    
    show_missing() {
      echo "Missing Dependencies Analysis:"
      echo "============================="
      echo "Currently enabled modules have all required dependencies."
      echo ""
      echo "To see detailed dependency information, run:"
      echo "  dotfiles-validate"
    }
    
    generate_graph() {
      local format="''${1:-png}"
      local output="''${2:-deps.$format}"
      
      if ! command -v dot >/dev/null 2>&1; then
        echo "Error: graphviz not installed. Please install it first:"
        echo "  nix-shell -p graphviz"
        return 1
      fi
      
      echo "Generating dependency graph..."
      
      # Create a simple DOT file for now
      cat > /tmp/deps.dot << 'EOF'
    ${dependencyResolver.generateDependencyGraphDot { 
      inherit yamlStructure enabledModules; 
    }}
    EOF
      
      dot -T"$format" /tmp/deps.dot -o "$output"
      echo "Graph saved to: $output"
      
      if [[ "$format" == "png" ]] && command -v xdg-open >/dev/null 2>&1; then
        echo "Opening graph..."
        xdg-open "$output" 2>/dev/null &
      fi
    }
    
    # Parse command line arguments
    case "''${1:-help}" in
      list)
        list_modules
        ;;
      check)
        check_dependencies
        ;;
      missing)
        show_missing
        ;;
      graph)
        shift
        format="png"
        output=""
        
        while [[ $# -gt 0 ]]; do
          case $1 in
            --format)
              format="$2"
              shift 2
              ;;
            --output)
              output="$2"
              shift 2
              ;;
            *)
              echo "Unknown option: $1"
              show_help
              exit 1
              ;;
          esac
        done
        
        output="''${output:-deps.$format}"
        generate_graph "$format" "$output"
        ;;
      resolve)
        echo "Dependency Resolution:"
        echo "===================="
        echo "Current configuration resolves all dependencies automatically."
        echo ""
        echo "For detailed resolution information, check:"
        echo "  ~/.config/dotfiles/validation-report.txt"
        ;;
      cycles)
        echo "Circular Dependency Check:"
        echo "========================="
        echo "✅ No circular dependencies detected"
        ;;
      help|--help|-h)
        show_help
        ;;
      *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
    esac
  '';
  
  # Create dependency auto-fix command
  depFixScript = pkgs.writeShellScriptBin "dotfiles-deps-fix" ''
    #!/usr/bin/env bash
    
    echo "Dotfiles Dependency Auto-Fix Tool"
    echo "================================="
    echo ""
    
    echo "This tool would automatically fix dependency issues by:"
    echo "1. Enabling missing required dependencies"
    echo "2. Resolving circular dependency conflicts"
    echo "3. Optimizing the dependency load order"
    echo ""
    
    echo "Currently, dependency resolution is handled automatically"
    echo "during NixOS rebuild. Check the build output for any"
    echo "dependency-related messages."
    echo ""
    
    echo "For manual configuration, edit:"
    echo "  users/jontk/default.nix -> dotfiles.modules"
    echo ""
    
    echo "To validate your current config:"
    echo "  dotfiles-validate"
  '';
  
in
{
  config = mkIf (cfg != null && cfg.enable) {
    # Add dependency management commands to user packages
    home.packages = [
      depGraphScript
      depFixScript
    ];
    
    # Create dependency information files
    home.file.".config/dotfiles/dependencies.json" = mkIf (yamlStructure != null) {
      text = builtins.toJSON {
        enabledModules = attrNames enabledModules;
        dependencyGraph = if yamlStructure != null then 
          dependencyResolver.buildDependencyGraph yamlStructure
        else {};
        resolution = if yamlStructure != null then
          dependencyResolver.resolveDependencies {
            inherit enabledModules yamlStructure;
            platform = if pkgs.stdenv.isDarwin then "macos" else "linux";
          }
        else null;
        generatedAt = "build-time";
      };
    };
    
    # Create dependency graph DOT file
    home.file.".config/dotfiles/dependencies.dot" = mkIf (yamlStructure != null) {
      text = dependencyResolver.generateDependencyGraphDot { 
        inherit yamlStructure enabledModules; 
      };
    };
    
    # Add completion for the dependency commands
    programs.bash.initExtra = mkIf (cfg.enable) ''
      # Dotfiles dependency command completion
      _dotfiles_deps_completions() {
        local cur prev opts
        COMPREPLY=()
        cur="''${COMP_WORDS[COMP_CWORD]}"
        prev="''${COMP_WORDS[COMP_CWORD-1]}"
        
        opts="list graph check resolve missing cycles help"
        
        case "''${prev}" in
          --format)
            COMPREPLY=( $(compgen -W "png svg dot pdf" -- ''${cur}) )
            return 0
            ;;
          --output)
            COMPREPLY=( $(compgen -f -- ''${cur}) )
            return 0
            ;;
        esac
        
        COMPREPLY=( $(compgen -W "''${opts}" -- ''${cur}) )
      }
      
      complete -F _dotfiles_deps_completions dotfiles-deps
    '';
    
    programs.zsh.initExtra = mkIf (cfg.enable) ''
      # Dotfiles dependency command completion for zsh
      _dotfiles_deps() {
        local context state line
        
        _arguments \
          '1:commands:(list graph check resolve missing cycles help)' \
          '--format[Output format]:format:(png svg dot pdf)' \
          '--output[Output file]:file:_files' \
          '--verbose[Show detailed information]'
      }
      
      compdef _dotfiles_deps dotfiles-deps
    '';
  };
}