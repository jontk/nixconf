# File Management Commands
{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

# Add find function that's missing from lib
let
  find = pred: list: 
    let result = filter pred list;
    in if result == [] then null else head result;
  cfg = userDotfilesConfig;
  fileManager = import ./file-manager.nix { inherit lib pkgs; };
  yamlParser = import ./yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Create backup system
  backupSystem = fileManager.createBackupSystem { 
    backupDir = cfg.fileManagement.backupDirectory or "~/.dotfiles-backups";
  };
  
  # Process file mappings for all enabled modules
  processAllModules = 
    let
      moduleNames = attrNames enabledModules;
      
      processModule = moduleName:
        let
          modulePath = "${dotfilesPath}/modules/${moduleName}/module.yml";
          moduleConfig = if builtins.pathExists modulePath then
            yamlParser.readModuleConfig modulePath
          else
            { name = moduleName; files = []; };
          
          fileMapping = fileManager.processFileMapping {
            inherit moduleConfig dotfilesPath;
          };
          
          conflicts = fileManager.detectFileConflicts { inherit fileMapping; };
          
          commands = fileManager.generateFileCommands {
            inherit moduleConfig fileMapping backupSystem dotfilesPath;
          };
        in
        {
          inherit moduleName moduleConfig fileMapping conflicts commands;
          hasFiles = fileMapping.moduleHasFiles;
        };
      
      moduleResults = map processModule moduleNames;
      modulesWithFiles = filter (m: m.hasFiles) moduleResults;
      totalConflicts = foldl' (acc: m: acc + m.conflicts.conflictCount) 0 modulesWithFiles;
      
    in
    {
      inherit moduleResults modulesWithFiles totalConflicts;
      allModules = moduleNames;
    };
  
  # File management commands
  fileStatusCommand = pkgs.writeShellScriptBin "dotfiles-file-status" ''
    echo "=== Dotfiles File Management Status ==="
    echo ""
    
    ${if cfg != null && cfg.enable then ''
      echo "Backup directory: ${backupSystem.backupDirectory}"
      echo "Total enabled modules: ${toString (length (attrNames enabledModules))}"
      
      ${let
        moduleInfo = processAllModules;
      in ''
        echo "Modules with files: ${toString (length moduleInfo.modulesWithFiles)}"
        echo "Total conflicts detected: ${toString moduleInfo.totalConflicts}"
        echo ""
        
        ${concatStringsSep "\n" (map (module: ''
          echo "--- ${module.moduleName} ---"
          echo "Files: ${toString module.fileMapping.validFilesCount}/${toString module.fileMapping.totalFiles}"
          ${if module.conflicts.hasConflicts then ''
            echo "Conflicts: ${toString module.conflicts.conflictCount}"
          '' else ''
            echo "No conflicts detected"
          ''}
          echo ""
        '') moduleInfo.modulesWithFiles)}
      ''}
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';
  
  # Install files for a specific module
  installModuleFilesCommand = pkgs.writeShellScriptBin "dotfiles-install-files" ''
    if [ $# -lt 1 ]; then
      echo "Usage: dotfiles-install-files <module-name> [--force|--interactive]"
      echo "Available modules: ${concatStringsSep ", " (attrNames enabledModules)}"
      exit 1
    fi
    
    MODULE_NAME="$1"
    MODE="''${2:-safe}"
    
    ${if cfg != null && cfg.enable then ''
      case "$MODULE_NAME" in
        ${concatStringsSep "\n" (mapAttrsToList (moduleName: _: ''
          "${moduleName}")
            echo "Installing files for ${moduleName} module..."
            ${let
              moduleInfo = find (m: m.moduleName == moduleName) processAllModules.moduleResults;
            in
              if moduleInfo != null then
                ''
                  case "$MODE" in
                    --force) ${moduleInfo.commands.installForce} ;;
                    --interactive) ${moduleInfo.commands.installInteractive} ;;
                    *) ${moduleInfo.commands.installSafe} ;;
                  esac
                ''
              else ''
                echo "No file configuration found for ${moduleName}"
              ''
            }
            ;;
        '') enabledModules)}
        "all")
          echo "Installing files for all modules..."
          ${concatStringsSep "\n" (map (module: ''
            echo "Processing ${module.moduleName}..."
            case "$MODE" in
              --force) ${module.commands.installForce} ;;
              --interactive) ${module.commands.installInteractive} ;;
              *) ${module.commands.installSafe} ;;
            esac
            echo ""
          '') processAllModules.modulesWithFiles)}
          ;;
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
  
  # Backup management command
  backupManagementCommand = pkgs.writeShellScriptBin "dotfiles-backup" ''
    case "''${1:-list}" in
      list)
        ${backupSystem.listBackups}
        ;;
      clean)
        KEEP_COUNT="''${2:-5}"
        ${backupSystem.cleanBackups { keepCount = 5; }}
        ;;
      restore)
        if [ $# -lt 3 ]; then
          echo "Usage: dotfiles-backup restore <original-path> <backup-path>"
          exit 1
        fi
        ORIGINAL_PATH="$2"
        BACKUP_PATH="$3"
        ${backupSystem.restoreFile { originalPath = "$ORIGINAL_PATH"; backupPath = "$BACKUP_PATH"; }}
        ;;
      *)
        echo "Usage: dotfiles-backup [list|clean|restore]"
        echo "  list                    - List available backups"
        echo "  clean [keep-count]      - Clean old backups (default: keep 5)"
        echo "  restore <orig> <backup> - Restore file from backup"
        exit 1
        ;;
    esac
  '';
  
  # File conflict resolution command
  resolveConflictsCommand = pkgs.writeShellScriptBin "dotfiles-resolve-conflicts" ''
    echo "=== Dotfiles File Conflict Resolution ==="
    echo ""
    
    ${if cfg != null && cfg.enable then ''
      ${let
        moduleInfo = processAllModules;
      in ''
        if [ ${toString moduleInfo.totalConflicts} -eq 0 ]; then
          echo "No file conflicts detected."
          exit 0
        fi
        
        echo "Total conflicts: ${toString moduleInfo.totalConflicts}"
        echo ""
        
        ${concatStringsSep "\n" (map (module: 
          if module.conflicts.hasConflicts then ''
            echo "--- Conflicts in ${module.moduleName} ---"
            ${concatStringsSep "\n" (map (conflict: ''
              if [ "${toString conflict.hasConflict}" = "true" ]; then
                echo "File: ${conflict.name}"
                echo "  Source: ${conflict.sourcePath}"
                echo "  Target: ${conflict.expandedTargetPath}"
                echo "  Exists: ${toString conflict.targetExists}"
                echo "  Symlink: ${toString conflict.isSymlink}"
                echo ""
              fi
            '') module.conflicts.allChecks)}
          '' else ""
        ) moduleInfo.modulesWithFiles)}
        
        echo "Resolution options:"
        echo "  dotfiles-install-files <module> --force      - Backup and replace"
        echo "  dotfiles-install-files <module> --interactive - Interactive resolution"
        echo "  dotfiles-backup clean                        - Clean old backups"
      ''}
    '' else ''
      echo "Dotfiles integration is not enabled."
    ''}
  '';

in
{
  config = mkIf (cfg != null && cfg.enable) {
    home.packages = [
      fileStatusCommand
      installModuleFilesCommand
      backupManagementCommand
      resolveConflictsCommand
    ];
  };
}