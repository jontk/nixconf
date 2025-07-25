# Validation command for dotfiles integration
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  validation = import ./validation.nix { inherit lib; };
  
  # Create validation command
  validationScript = pkgs.writeShellScriptBin "dotfiles-validate" ''
    echo "Dotfiles Integration Configuration Validator"
    echo "==========================================="
    echo
    
    # Basic configuration check
    if [[ "${toString (cfg != null)}" == "true" ]]; then
      echo "✅ Dotfiles configuration found"
    else
      echo "❌ No dotfiles configuration found"
      exit 1
    fi
    
    # Check if enabled
    if [[ "${toString (cfg.enable)}" == "true" ]]; then
      echo "✅ Dotfiles integration enabled"
    else
      echo "⚠️  Dotfiles integration disabled"
    fi
    
    # Show current profile
    echo "📋 Current profile: ${cfg.user.profile or "none"}"
    
    # Show enabled modules
    echo "🔧 Enabled modules:"
    ${concatStringsSep "\n" (mapAttrsToList (name: _: "    echo \"   - ${name}\"") enabledModules)}
    
    # Show priority modes
    echo "🎯 Priority modes:"
    ${concatStringsSep "\n" (mapAttrsToList (module: mode: "    echo \"   - ${module}: ${mode}\"") (cfg.priorityModes or {}))}
    
    echo
    echo "🔍 For detailed validation, rebuild your NixOS configuration"
    echo "   Any validation errors will be shown during the build process"
  '';
  
  # Run validation during evaluation if enabled
  validationResult = 
    if cfg != null && cfg.enable then
      validation.validateConfiguration {
        userConfig = cfg;
        inherit enabledModules yamlStructure;
      }
    else
      { isValid = true; errors = []; warnings = []; summary = { totalErrors = 0; totalWarnings = 0; }; };
  
  # Generate warnings during build if there are validation issues
  validationWarnings = 
    if validationResult.errors != [] then
      map (error: trace "DOTFILES VALIDATION ERROR: ${error.error}") validationResult.errors
    else if validationResult.warnings != [] then
      map (warning: trace "DOTFILES VALIDATION WARNING: ${warning.warning or warning}") validationResult.warnings
    else
      [];

in
{
  config = mkIf (cfg != null && cfg.enable) {
    # Add validation command to user packages
    home.packages = [ validationScript ];
    
    # Add validation report to home files
    home.file.".config/dotfiles/validation-report.txt" = {
      text = validation.generateValidationReport validationResult;
    };
    
    # Trigger validation warnings during build
    warnings = validationWarnings;
    
    # Add assertion for critical errors
    assertions = [{
      assertion = validationResult.isValid || validationResult.summary.totalErrors < 3;
      message = ''
        Dotfiles integration has validation errors:
        ${concatMapStringsSep "\n" (error: "  - ${error.error}") validationResult.errors}
        
        Run 'dotfiles-validate' for more information or check ~/.config/dotfiles/validation-report.txt
      '';
    }];
  };
}