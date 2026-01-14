# File Management and Backup System
{ lib, pkgs }:

with lib;

let
  # File mapping and backup functionality
  processFileMapping = { moduleConfig, dotfilesPath, targetPath ? null }:
    let
      files = moduleConfig.files or [];
      
      # Process individual file mapping
      processFile = fileConfig:
        let
          sourcePath = "${dotfilesPath}/modules/${moduleConfig.name}/${fileConfig.name}";
          
          # Determine target path
          defaultTargetPath =
            if hasAttr "target" fileConfig then
              fileConfig.target
            else if hasAttr "link_path" fileConfig then
              fileConfig.link_path
            else
              "~/.${fileConfig.name}";

          finalTargetPath = defaultTargetPath;
          
          # File type and handling
          fileType = fileConfig.type or "file";
          linkType = fileConfig.link_type or "symbolic";
          backup = fileConfig.backup or true;
          overwrite = fileConfig.overwrite or false;
          
          # Platform-specific handling
          platforms = fileConfig.platforms or ["linux" "macos"];
          currentPlatform = if pkgs.stdenv.isDarwin then "macos" else "linux";
          platformSupported = elem currentPlatform platforms;
          
        in
        {
          inherit sourcePath finalTargetPath fileType linkType backup overwrite;
          inherit platforms platformSupported;
          name = fileConfig.name;
          exists = builtins.pathExists sourcePath;
          config = fileConfig;
        };
      
      processedFiles = map processFile files;
      validFiles = filter (f: f.exists && f.platformSupported) processedFiles;
      
    in
    {
      inherit processedFiles validFiles;
      totalFiles = length processedFiles;
      validFilesCount = length validFiles;
      moduleHasFiles = files != [];
    };
  
  # Backup functionality
  createBackupSystem = { backupDir ? "~/.dotfiles-backups" }:
    let
      # Generate backup filename with timestamp
      generateBackupName = filePath:
        let
          timestamp = "$(date +%Y%m%d_%H%M%S)";
          baseName = baseNameOf filePath;
        in
        "${backupDir}/${baseName}.backup.${timestamp}";
      
      # Create backup of existing file
      backupFile = filePath:
        let
          backupPath = generateBackupName filePath;
        in
        ''
          if [ -f "${filePath}" ] || [ -L "${filePath}" ]; then
            echo "Creating backup: ${filePath} -> ${backupPath}"
            mkdir -p "$(dirname "${backupPath}")"
            cp -P "${filePath}" "${backupPath}" || echo "Failed to backup ${filePath}"
          fi
        '';
      
      # Restore file from backup
      restoreFile = { originalPath, backupPath }:
        ''
          if [ -f "${backupPath}" ]; then
            echo "Restoring: ${backupPath} -> ${originalPath}"
            cp "${backupPath}" "${originalPath}" || echo "Failed to restore ${originalPath}"
          else
            echo "Backup not found: ${backupPath}"
          fi
        '';
      
      # List available backups
      listBackups = ''
        echo "Available backups in ${backupDir}:"
        if [ -d "${backupDir}" ]; then
          find "${backupDir}" -name "*.backup.*" -type f | sort
        else
          echo "No backup directory found."
        fi
      '';
      
      # Clean old backups (keep last N)
      cleanBackups = { keepCount ? 5 }:
        ''
          if [ -d "${backupDir}" ]; then
            echo "Cleaning old backups (keeping ${toString keepCount})..."
            find "${backupDir}" -name "*.backup.*" -type f | \
              sort -r | tail -n +$((${toString keepCount} + 1)) | \
              xargs -r rm -f
          fi
        '';
      
    in
    {
      inherit generateBackupName backupFile restoreFile listBackups cleanBackups;
      backupDirectory = backupDir;
    };
  
  # File conflict detection and resolution
  detectFileConflicts = { fileMapping, homeDirectory ? "~" }:
    let
      checkConflict = fileInfo:
        let
          targetPath = fileInfo.finalTargetPath;
          expandedPath = replaceStrings ["~"] [homeDirectory] targetPath;
        in
        {
          inherit (fileInfo) name sourcePath finalTargetPath;
          targetExists = builtins.pathExists expandedPath;
          isSymlink = builtins.pathExists expandedPath && (builtins.readFileType expandedPath == "symlink");
          hasConflict = builtins.pathExists expandedPath && !fileInfo.overwrite;
          expandedTargetPath = expandedPath;
        };
      
      conflicts = map checkConflict fileMapping.validFiles;
      hasConflicts = any (c: c.hasConflict) conflicts;
      conflictCount = length (filter (c: c.hasConflict) conflicts);
      
    in
    {
      inherit conflicts hasConflicts conflictCount;
      allChecks = conflicts;
    };
  
  # Resolution strategies for file conflicts
  createResolutionStrategies = { fileConflicts, backupSystem }:
    let
      # Strategy: Backup and replace
      backupAndReplace = conflictInfo:
        ''
          echo "Resolving conflict for ${conflictInfo.name}: backup and replace"
          ${backupSystem.backupFile conflictInfo.expandedTargetPath}
          rm -f "${conflictInfo.expandedTargetPath}"
        '';
      
      # Strategy: Skip conflicting file
      skipFile = conflictInfo:
        ''
          echo "Skipping conflicting file: ${conflictInfo.name}"
          echo "  Target exists: ${conflictInfo.expandedTargetPath}"
          echo "  Use --force to overwrite or --backup to create backup"
        '';
      
      # Strategy: Interactive prompt
      interactiveResolve = conflictInfo:
        ''
          echo "File conflict detected: ${conflictInfo.name}"
          echo "  Source: ${conflictInfo.sourcePath}"
          echo "  Target: ${conflictInfo.expandedTargetPath}"
          read -p "Resolution [b]ackup, [s]kip, [o]verwrite: " choice
          case "$choice" in
            b|B) ${backupAndReplace conflictInfo} ;;
            s|S) ${skipFile conflictInfo} ;;
            o|O) rm -f "${conflictInfo.expandedTargetPath}" ;;
            *) echo "Invalid choice, skipping..."; ${skipFile conflictInfo} ;;
          esac
        '';
      
    in
    {
      inherit backupAndReplace skipFile interactiveResolve;
    };
  
  # Generate shell commands for file management
  generateFileCommands = { moduleConfig, fileMapping, backupSystem, dotfilesPath }:
    let
      # Install files command
      installFiles = mode:
        let
          conflicts = detectFileConflicts { inherit fileMapping; };
          strategies = createResolutionStrategies { fileConflicts = conflicts; inherit backupSystem; };
          
          installFile = fileInfo:
            let
              sourcePath = fileInfo.sourcePath;
              targetPath = fileInfo.finalTargetPath;
              linkType = fileInfo.linkType;
            in
            ''
              # Install ${fileInfo.name}
              echo "Installing: ${sourcePath} -> ${targetPath}"
              mkdir -p "$(dirname "${targetPath}")"
              
              ${if linkType == "symbolic" then
                "ln -sf \"${sourcePath}\" \"${targetPath}\""
              else if linkType == "hard" then
                "ln -f \"${sourcePath}\" \"${targetPath}\""
              else
                "cp \"${sourcePath}\" \"${targetPath}\""
              }
            '';
          
          processConflicts = 
            if mode == "force" then
              concatStringsSep "\n" (map strategies.backupAndReplace (filter (c: c.hasConflict) conflicts.allChecks))
            else if mode == "interactive" then
              concatStringsSep "\n" (map strategies.interactiveResolve (filter (c: c.hasConflict) conflicts.allChecks))
            else
              concatStringsSep "\n" (map strategies.skipFile (filter (c: c.hasConflict) conflicts.allChecks));
          
        in
        ''
          echo "Installing files for module: ${moduleConfig.name}"
          echo "Total files: ${toString fileMapping.totalFiles}"
          echo "Valid files: ${toString fileMapping.validFilesCount}"
          
          ${if conflicts.hasConflicts then ''
            echo "Conflicts detected: ${toString conflicts.conflictCount}"
            ${processConflicts}
          '' else ""}
          
          # Install non-conflicting files
          ${concatStringsSep "\n" (map installFile (filter (f: 
            !(any (c: c.name == f.name && c.hasConflict) conflicts.allChecks)
          ) fileMapping.validFiles))}
          
          echo "File installation completed for ${moduleConfig.name}"
        '';
      
      # Uninstall files command
      uninstallFiles = 
        ''
          echo "Uninstalling files for module: ${moduleConfig.name}"
          ${concatStringsSep "\n" (map (fileInfo: ''
            if [ -L "${fileInfo.finalTargetPath}" ]; then
              echo "Removing symlink: ${fileInfo.finalTargetPath}"
              rm -f "${fileInfo.finalTargetPath}"
            elif [ -f "${fileInfo.finalTargetPath}" ]; then
              echo "File exists (not removing): ${fileInfo.finalTargetPath}"
              echo "  Use --force to remove or manually delete"
            fi
          '') fileMapping.validFiles)}
          echo "File uninstallation completed for ${moduleConfig.name}"
        '';
      
    in
    {
      inherit installFiles uninstallFiles;
      installForce = installFiles "force";
      installInteractive = installFiles "interactive";
      installSafe = installFiles "safe";
    };

in
{
  inherit processFileMapping createBackupSystem detectFileConflicts;
  inherit createResolutionStrategies generateFileCommands;
}