# Installation Hooks System
{ lib, pkgs }:

with lib;

let
  # Hook execution framework
  executeHook = { hookConfig, environment ? {}, workingDir ? null }:
    let
      # Hook types: pre_install, post_install, pre_uninstall, post_uninstall
      hookType = hookConfig.type or "unknown";
      commands = hookConfig.commands or [];
      shell = hookConfig.shell or "bash";
      timeout = hookConfig.timeout or 30;
      continueOnError = hookConfig.continue_on_error or false;
      platforms = hookConfig.platforms or ["linux" "macos"];
      
      currentPlatform = if pkgs.stdenv.isDarwin then "macos" else "linux";
      platformSupported = elem currentPlatform platforms;
      
      # Environment variables for hook execution
      hookEnv = environment // {
        DOTFILES_HOOK_TYPE = hookType;
        DOTFILES_HOOK_PLATFORM = currentPlatform;
        DOTFILES_HOOK_TIMEOUT = toString timeout;
      };
      
      # Generate environment variable export statements
      envExports = concatStringsSep "\n" (mapAttrsToList (name: value:
        "export ${name}=\"${toString value}\""
      ) hookEnv);
      
      # Execute individual command with error handling
      executeCommand = cmd:
        let
          cmdTimeout = hookConfig.command_timeout or timeout;
        in
        ''
          echo "Executing hook command: ${cmd}"
          ${if continueOnError then ''
            if ! timeout ${toString cmdTimeout} ${shell} -c "${cmd}"; then
              echo "Hook command failed (continuing): ${cmd}"
              echo "Error code: $?"
            fi
          '' else ''
            if ! timeout ${toString cmdTimeout} ${shell} -c "${cmd}"; then
              echo "Hook command failed: ${cmd}"
              echo "Error code: $?"
              exit 1
            fi
          ''}
        '';
      
    in
    {
      inherit hookType platforms platformSupported continueOnError;
      isValid = commands != [] && platformSupported;
      
      # Generate hook execution script
      executionScript = ''
        echo "=== Executing ${hookType} hook ==="
        ${if workingDir != null then "cd \"${workingDir}\"" else ""}
        
        # Set hook environment
        ${envExports}
        
        # Execute hook commands
        ${if platformSupported then
          concatStringsSep "\n" (map executeCommand commands)
        else
          ''echo "Hook not supported on platform: ${currentPlatform}"''
        }
        
        echo "=== Hook ${hookType} completed ==="
      '';
      
      # Validation information
      validation = {
        hasCommands = commands != [];
        supportsPlatform = platformSupported;
        validShell = elem shell ["bash" "sh" "zsh"];
        reasonableTimeout = timeout > 0 && timeout <= 300;
      };
    };
  
  # Process hooks from module configuration
  processModuleHooks = { moduleConfig, dotfilesPath }:
    let
      hooks = moduleConfig.hooks or {};
      
      # Process each hook type
      processHookType = hookType: hookConfig:
        if hookConfig == null then null
        else executeHook {
          hookConfig = hookConfig // { type = hookType; };
          environment = {
            DOTFILES_MODULE_NAME = moduleConfig.name;
            DOTFILES_MODULE_PATH = "${dotfilesPath}/modules/${moduleConfig.name}";
            DOTFILES_MODULE_VERSION = moduleConfig.version or "unknown";
          };
          workingDir = "${dotfilesPath}/modules/${moduleConfig.name}";
        };
      
      # Standard hook types
      preInstall = processHookType "pre_install" (hooks.pre_install or null);
      postInstall = processHookType "post_install" (hooks.post_install or null);
      preUninstall = processHookType "pre_uninstall" (hooks.pre_uninstall or null);
      postUninstall = processHookType "post_uninstall" (hooks.post_uninstall or null);
      
      # Custom hooks
      customHooks = filterAttrs (name: _: 
        !(elem name ["pre_install" "post_install" "pre_uninstall" "post_uninstall"])
      ) hooks;
      
      processedCustomHooks = mapAttrs (name: config: 
        processHookType name config
      ) customHooks;
      
      allHooks = filterAttrs (name: hook: hook != null) ({
        inherit preInstall postInstall preUninstall postUninstall;
      } // processedCustomHooks);
      
      validHooks = filterAttrs (name: hook: hook.isValid) allHooks;
      
    in
    {
      inherit allHooks validHooks customHooks;
      hasHooks = allHooks != {};
      validHookCount = length (attrNames validHooks);
      totalHookCount = length (attrNames allHooks);
    };
  
  # Hook execution manager
  createHookManager = { modules, dotfilesPath }:
    let
      # Process hooks for all modules
      moduleHooks = mapAttrs (name: moduleConfig:
        processModuleHooks { inherit moduleConfig dotfilesPath; }
      ) modules;
      
      # Get hooks by type across all modules
      getHooksByType = hookType:
        let
          extractHook = moduleName: moduleHookInfo:
            if hasAttr hookType moduleHookInfo.validHooks then
              { inherit moduleName; hook = moduleHookInfo.validHooks.${hookType}; }
            else null;
          
          allModuleHooks = mapAttrsToList extractHook moduleHooks;
          validModuleHooks = filter (h: h != null) allModuleHooks;
        in
        validModuleHooks;
      
      # Execute hooks of a specific type
      executeHooksOfType = { hookType, dryRun ? false }:
        let
          hooksToExecute = getHooksByType hookType;
        in
        ''
          echo "=== Executing ${hookType} hooks for ${toString (length hooksToExecute)} modules ==="
          
          ${if dryRun then ''
            echo "DRY RUN MODE - hooks will not be executed"
            ${concatStringsSep "\n" (map (hookInfo: ''
              echo "Would execute ${hookType} hook for module: ${hookInfo.moduleName}"
              echo "Commands: ${toString (length hookInfo.hook.hookConfig.commands)}"
            '') hooksToExecute)}
          '' else ''
            ${concatStringsSep "\n" (map (hookInfo: ''
              echo "--- ${hookInfo.moduleName} ${hookType} hook ---"
              ${hookInfo.hook.executionScript}
              echo ""
            '') hooksToExecute)}
          ''}
          
          echo "=== Completed ${hookType} hooks ==="
        '';
      
      # Validate all hooks
      validateAllHooks = 
        let
          allValidationResults = mapAttrs (moduleName: moduleHookInfo:
            mapAttrs (hookType: hook: hook.validation) moduleHookInfo.validHooks
          ) moduleHooks;
          
          flatValidations = flatten (mapAttrsToList (moduleName: moduleValidations:
            mapAttrsToList (hookType: validation: {
              inherit moduleName hookType validation;
            }) moduleValidations
          ) allValidationResults);
          
          invalidHooks = filter (v: 
            !v.validation.hasCommands || 
            !v.validation.supportsPlatform || 
            !v.validation.validShell || 
            !v.validation.reasonableTimeout
          ) flatValidations;
          
        in
        {
          totalHooks = length flatValidations;
          invalidHooks = invalidHooks;
          hasInvalidHooks = invalidHooks != [];
          invalidHookCount = length invalidHooks;
        };
      
    in
    {
      inherit moduleHooks getHooksByType executeHooksOfType validateAllHooks;
      
      # Convenience methods for common hook operations
      executePreInstallHooks = { dryRun ? false }: executeHooksOfType { hookType = "preInstall"; inherit dryRun; };
      executePostInstallHooks = { dryRun ? false }: executeHooksOfType { hookType = "postInstall"; inherit dryRun; };
      executePreUninstallHooks = { dryRun ? false }: executeHooksOfType { hookType = "preUninstall"; inherit dryRun; };
      executePostUninstallHooks = { dryRun ? false }: executeHooksOfType { hookType = "postUninstall"; inherit dryRun; };
      
      # Hook information
      getHookSummary = 
        let
          totalModulesWithHooks = length (filter (info: info.hasHooks) (attrValues moduleHooks));
          totalValidHooks = foldl' (acc: info: acc + info.validHookCount) 0 (attrValues moduleHooks);
          validation = validateAllHooks;
        in
        {
          modulesWithHooks = totalModulesWithHooks;
          totalValidHooks = totalValidHooks;
          inherit (validation) totalHooks invalidHookCount hasInvalidHooks;
        };
    };

in
{
  inherit executeHook processModuleHooks createHookManager;
}