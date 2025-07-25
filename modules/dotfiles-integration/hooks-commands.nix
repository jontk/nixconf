# Installation Hooks Commands
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  hooksSystem = import ./hooks-system.nix { inherit lib pkgs; };
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Load module configurations
  loadModuleConfigs = 
    let
      moduleNames = attrNames enabledModules;
      
      loadModule = moduleName:
        let
          modulePath = "${dotfilesPath}/modules/${moduleName}/module.yml";
          moduleConfig = if builtins.pathExists modulePath then
            yamlParser.readModuleConfig modulePath
          else
            { name = moduleName; hooks = {}; };
        in
        nameValuePair moduleName moduleConfig;
      
    in
    listToAttrs (map loadModule moduleNames);
  
  # Create hook manager
  hookManager = hooksSystem.createHookManager {
    modules = loadModuleConfigs;
    inherit dotfilesPath;
  };
  
  # Hooks status command
  hooksStatusCommand = pkgs.writeShellScriptBin "dotfiles-hooks-status" ''
    echo "=== Dotfiles Installation Hooks Status ==="
    echo ""
    
    ${if cfg != null && cfg.enable then ''
      ${let
        summary = hookManager.getHookSummary;
      in ''
        echo "Modules with hooks: ${toString summary.modulesWithHooks}"
        echo "Total valid hooks: ${toString summary.totalValidHooks}"
        echo "Total hooks: ${toString summary.totalHooks}"
        ${if summary.hasInvalidHooks then ''
          echo "Invalid hooks: ${toString summary.invalidHookCount}"
        '' else ''
          echo "All hooks are valid"
        ''}
        echo ""
        
        echo "=== Module Hook Details ==="
        ${concatStringsSep "\n" (mapAttrsToList (moduleName: moduleHookInfo: ''
          if [ "${toString moduleHookInfo.hasHooks}" = "true" ]; then
            echo "--- ${moduleName} ---"
            echo "Valid hooks: ${toString moduleHookInfo.validHookCount}"
            echo "Total hooks: ${toString moduleHookInfo.totalHookCount}"
            ${concatStringsSep "\n" (mapAttrsToList (hookType: hook: ''
              echo "  ${hookType}: ${toString (length hook.hookConfig.commands)} commands"
            '') moduleHookInfo.validHooks)}
            echo ""
          fi
        '') hookManager.moduleHooks)}
      ''}
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Execute hooks command
  executeHooksCommand = pkgs.writeShellScriptBin "dotfiles-execute-hooks" ''
    if [ $# -lt 1 ]; then
      echo "Usage: dotfiles-execute-hooks <hook-type> [--dry-run]"
      echo "Hook types: pre-install, post-install, pre-uninstall, post-uninstall"
      exit 1
    fi
    
    HOOK_TYPE="$1"
    DRY_RUN="''${2:-}"
    
    ${if cfg != null && cfg.enable then ''
      case "$HOOK_TYPE" in
        pre-install)
          echo "Executing pre-install hooks..."
          ${if cfg.installation.dryRun or false then
            hookManager.executePreInstallHooks { dryRun = true; }
          else ''
            if [ "$DRY_RUN" = "--dry-run" ]; then
              ${hookManager.executePreInstallHooks { dryRun = true; }}
            else
              ${hookManager.executePreInstallHooks { dryRun = false; }}
            fi
          ''}
          ;;
        post-install)
          echo "Executing post-install hooks..."
          ${if cfg.installation.dryRun or false then
            hookManager.executePostInstallHooks { dryRun = true; }
          else ''
            if [ "$DRY_RUN" = "--dry-run" ]; then
              ${hookManager.executePostInstallHooks { dryRun = true; }}
            else
              ${hookManager.executePostInstallHooks { dryRun = false; }}
            fi
          ''}
          ;;
        pre-uninstall)
          echo "Executing pre-uninstall hooks..."
          ${if cfg.installation.dryRun or false then
            hookManager.executePreUninstallHooks { dryRun = true; }
          else ''
            if [ "$DRY_RUN" = "--dry-run" ]; then
              ${hookManager.executePreUninstallHooks { dryRun = true; }}
            else
              ${hookManager.executePreUninstallHooks { dryRun = false; }}
            fi
          ''}
          ;;
        post-uninstall)
          echo "Executing post-uninstall hooks..."
          ${if cfg.installation.dryRun or false then
            hookManager.executePostUninstallHooks { dryRun = true; }
          else ''
            if [ "$DRY_RUN" = "--dry-run" ]; then
              ${hookManager.executePostUninstallHooks { dryRun = true; }}
            else
              ${hookManager.executePostUninstallHooks { dryRun = false; }}
            fi
          ''}
          ;;
        *)
          echo "Unknown hook type: $HOOK_TYPE"
          echo "Available types: pre-install, post-install, pre-uninstall, post-uninstall"
          exit 1
          ;;
      esac
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Validate hooks command
  validateHooksCommand = pkgs.writeShellScriptBin "dotfiles-validate-hooks" ''
    echo "=== Dotfiles Hooks Validation ==="
    echo ""
    
    ${if cfg != null && cfg.enable then ''
      ${let
        validation = hookManager.validateAllHooks;
      in ''
        echo "Total hooks: ${toString validation.totalHooks}"
        ${if validation.hasInvalidHooks then ''
          echo "Invalid hooks: ${toString validation.invalidHookCount}"
          echo ""
          echo "=== Invalid Hook Details ==="
          ${concatStringsSep "\n" (map (invalid: ''
            echo "Module: ${invalid.moduleName}"
            echo "Hook: ${invalid.hookType}"
            echo "Issues:"
            ${if !invalid.validation.hasCommands then ''
              echo "  - No commands defined"
            '' else ""}
            ${if !invalid.validation.supportsPlatform then ''
              echo "  - Platform not supported"
            '' else ""}
            ${if !invalid.validation.validShell then ''
              echo "  - Invalid shell specified"
            '' else ""}
            ${if !invalid.validation.reasonableTimeout then ''
              echo "  - Unreasonable timeout value"
            '' else ""}
            echo ""
          '') validation.invalidHooks)}
        '' else ''
          echo "✅ All hooks are valid"
        ''}
      ''}
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Hook execution wrapper for integration with other commands
  hookExecutionWrapper = pkgs.writeShellScriptBin "dotfiles-with-hooks" ''
    if [ $# -lt 2 ]; then
      echo "Usage: dotfiles-with-hooks <operation> <command> [args...]"
      echo "Operations: install, uninstall"
      echo "Example: dotfiles-with-hooks install dotfiles-install-files shell"
      exit 1
    fi
    
    OPERATION="$1"
    shift
    COMMAND="$@"
    
    ${if cfg != null && cfg.enable then ''
      case "$OPERATION" in
        install)
          echo "=== Running installation with hooks ==="
          
          # Execute pre-install hooks
          echo "Step 1: Pre-install hooks..."
          dotfiles-execute-hooks pre-install
          if [ $? -ne 0 ]; then
            echo "Pre-install hooks failed. Aborting installation."
            exit 1
          fi
          
          # Execute main command
          echo "Step 2: Main installation..."
          $COMMAND
          MAIN_EXIT_CODE=$?
          
          # Execute post-install hooks (even if main command failed)
          echo "Step 3: Post-install hooks..."
          dotfiles-execute-hooks post-install
          
          if [ $MAIN_EXIT_CODE -ne 0 ]; then
            echo "Main installation command failed with exit code: $MAIN_EXIT_CODE"
            exit $MAIN_EXIT_CODE
          fi
          ;;
        uninstall)
          echo "=== Running uninstallation with hooks ==="
          
          # Execute pre-uninstall hooks
          echo "Step 1: Pre-uninstall hooks..."
          dotfiles-execute-hooks pre-uninstall
          if [ $? -ne 0 ]; then
            echo "Pre-uninstall hooks failed. Aborting uninstallation."
            exit 1
          fi
          
          # Execute main command
          echo "Step 2: Main uninstallation..."
          $COMMAND
          MAIN_EXIT_CODE=$?
          
          # Execute post-uninstall hooks (even if main command failed)
          echo "Step 3: Post-uninstall hooks..."
          dotfiles-execute-hooks post-uninstall
          
          if [ $MAIN_EXIT_CODE -ne 0 ]; then
            echo "Main uninstallation command failed with exit code: $MAIN_EXIT_CODE"
            exit $MAIN_EXIT_CODE
          fi
          ;;
        *)
          echo "Unknown operation: $OPERATION"
          echo "Available operations: install, uninstall"
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
      hooksStatusCommand
      executeHooksCommand
      validateHooksCommand
      hookExecutionWrapper
    ];
  };
}