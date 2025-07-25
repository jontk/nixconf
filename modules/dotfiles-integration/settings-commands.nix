# Settings Management Commands
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  settingsParser = import ./settings-parser.nix { inherit lib; };
  
  # Generate settings report for all enabled modules
  generateSettingsReport = 
    let
      moduleNames = attrNames enabledModules;
      
      generateModuleReport = moduleName:
        let
          moduleConfig = yamlStructure.modulesConfig.modules.${moduleName} or {};
          userSettings = cfg.modules.${moduleName}.settings or {};
          
          # Only generate report if module exists and has settings
          moduleHasSettings = moduleConfig != {} && (moduleConfig.settings or {}) != {};
        in
        if moduleHasSettings then
          settingsParser.generateSettingsReport {
            inherit moduleConfig;
            settings = moduleConfig.settings or {};
            userOverrides = userSettings;
          }
        else null;
      
      moduleReports = filter (report: report != null) (map generateModuleReport moduleNames);
      
      totalModules = length moduleNames;
      modulesWithSettings = length moduleReports;
      validModules = length (filter (report: report.summary == "✅ All settings valid") moduleReports);
      invalidModules = modulesWithSettings - validModules;
      
      overallSummary = 
        if invalidModules == 0 then "✅ All module settings are valid"
        else "⚠️  ${toString invalidModules} modules have invalid settings";
      
    in {
      inherit moduleReports;
      summary = {
        inherit totalModules modulesWithSettings validModules invalidModules;
        status = overallSummary;
      };
    };
  
  # Create shell command to show settings status
  settingsStatusCommand = pkgs.writeShellScriptBin "dotfiles-settings-status" ''
    echo "=== Dotfiles Module Settings Status ==="
    echo ""
    
    ${if cfg != null && cfg.enable then ''
      echo "Profile: ${cfg.user.profile}"
      echo "Platform: ${if pkgs.stdenv.isDarwin then "macOS" else "Linux"}"
      echo ""
      
      echo "=== Module Settings Summary ==="
      ${let
        report = generateSettingsReport;
      in ''
        echo "Total modules: ${toString report.summary.totalModules}"
        echo "Modules with settings: ${toString report.summary.modulesWithSettings}"
        echo "Valid modules: ${toString report.summary.validModules}"
        echo "Invalid modules: ${toString report.summary.invalidModules}"
        echo "Status: ${report.summary.status}"
        echo ""
        
        ${concatStringsSep "\n" (map (moduleReport: ''
          echo "--- ${moduleReport.module} ---"
          echo "${moduleReport.summary}"
          echo "Settings: ${toString moduleReport.totalSettings}"
          echo "User overrides: ${toString moduleReport.userOverrides}"
          ${if moduleReport.summary != "✅ All settings valid" then ''
            echo "Errors:"
            ${concatStringsSep "\n" (map (error: ''
              echo "  - ${error.error}"
            '') moduleReport.details.validation.errors)}
          '' else ""}
          echo ""
        '') report.moduleReports)}
      ''}
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Create command to validate specific module settings
  validateModuleCommand = pkgs.writeShellScriptBin "dotfiles-validate-module" ''
    if [ $# -ne 1 ]; then
      echo "Usage: dotfiles-validate-module <module-name>"
      echo "Available modules: ${concatStringsSep ", " (attrNames enabledModules)}"
      exit 1
    fi
    
    MODULE_NAME="$1"
    
    ${if cfg != null && cfg.enable then ''
      case "$MODULE_NAME" in
        ${concatStringsSep "\n" (mapAttrsToList (moduleName: _: ''
          "${moduleName}")
            echo "=== Validating ${moduleName} module settings ==="
            ${let
              moduleConfig = yamlStructure.modulesConfig.modules.${moduleName} or {};
              userSettings = cfg.modules.${moduleName}.settings or {};
              report = if moduleConfig != {} then
                settingsParser.generateSettingsReport {
                  inherit moduleConfig;
                  settings = moduleConfig.settings or {};
                  userOverrides = userSettings;
                }
              else { summary = "No settings found"; };
            in ''
              echo "Status: ${report.summary}"
              echo "Total settings: ${toString (report.totalSettings or 0)}"
              echo "User overrides: ${toString (report.userOverrides or 0)}"
              ${if report.summary != "✅ All settings valid" && (report.details.validation.errors or []) != [] then ''
                echo ""
                echo "Validation errors:"
                ${concatStringsSep "\n" (map (error: ''
                  echo "  - ${error.error}"
                '') (report.details.validation.errors or []))}
              '' else ""}
            ''}
            ;;
        '') enabledModules)}
        *)
          echo "Unknown module: $MODULE_NAME"
          echo "Available modules: ${concatStringsSep ", " (attrNames enabledModules)}"
          exit 1
          ;;
      esac
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Create command to show available settings for a module
  showModuleSettingsCommand = pkgs.writeShellScriptBin "dotfiles-show-settings" ''
    if [ $# -ne 1 ]; then
      echo "Usage: dotfiles-show-settings <module-name>"
      echo "Available modules: ${concatStringsSep ", " (attrNames enabledModules)}"
      exit 1
    fi
    
    MODULE_NAME="$1"
    
    ${if cfg != null && cfg.enable then ''
      case "$MODULE_NAME" in
        ${concatStringsSep "\n" (mapAttrsToList (moduleName: _: ''
          "${moduleName}")
            echo "=== Available settings for ${moduleName} module ==="
            ${let
              moduleConfig = yamlStructure.modulesConfig.modules.${moduleName} or {};
              settingDefs = if moduleConfig != {} then 
                settingsParser.parseModuleSettings moduleConfig
              else {};
              userSettings = cfg.modules.${moduleName}.settings or {};
            in ''
              ${if settingDefs != {} then ''
                ${concatStringsSep "\n" (mapAttrsToList (name: def: ''
                  echo ""
                  echo "Setting: ${name}"
                  echo "  Type: ${def.type}"
                  echo "  Default: ${toString (def.default or "none")}"
                  echo "  Required: ${toString def.required}"
                  echo "  Description: ${def.description}"
                  ${if def.options != [] then ''
                    echo "  Options: ${concatStringsSep ", " (map toString def.options)}"
                  '' else ""}
                  ${if hasAttr name userSettings then ''
                    echo "  Current value: ${toString userSettings.${name}}"
                  '' else ''
                    echo "  Current value: (using default)"
                  ''}
                '') settingDefs)}
              '' else ''
                echo "No settings available for this module."
              ''}
            ''}
            ;;
        '') enabledModules)}
        *)
          echo "Unknown module: $MODULE_NAME"
          echo "Available modules: ${concatStringsSep ", " (attrNames enabledModules)}"
          exit 1
          ;;
      esac
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';

in
{
  config = mkIf (cfg != null && cfg.enable) {
    home.packages = [
      settingsStatusCommand
      validateModuleCommand
      showModuleSettingsCommand
    ];
  };
}