# Priority Modes Utilities
# Advanced merge and priority handling for dotfiles integration
{ lib }:

with lib;

let
  # Deep merge two attribute sets, with right taking precedence
  deepMerge = left: right:
    let
      mergeValues = path: leftVal: rightVal:
        if isAttrs leftVal && isAttrs rightVal then
          mapAttrs (name: value:
            if hasAttr name leftVal then
              mergeValues (path ++ [name]) leftVal.${name} value
            else
              value
          ) rightVal //
          mapAttrs (name: value:
            if hasAttr name rightVal then
              mergeValues (path ++ [name]) value rightVal.${name}
            else
              value
          ) leftVal
        else if isList leftVal && isList rightVal then
          # For lists, concatenate and remove duplicates
          unique (leftVal ++ rightVal)
        else
          # For primitive values, right takes precedence
          rightVal;
    in
    mergeValues [] left right;

  # Smart merge for shell aliases
  mergeAliases = nixAliases: dotfilesAliases: priorityMode:
    let
      conflicts = intersectAttrs nixAliases dotfilesAliases;
      conflictNames = attrNames conflicts;
    in
    if priorityMode == "merge" then
      # Default merge: dotfiles take precedence for conflicts
      nixAliases // dotfilesAliases
    else if priorityMode == "nixconf" then
      # NixOS config takes precedence, ignore dotfiles
      nixAliases
    else if priorityMode == "dotfiles" then
      # Dotfiles take full precedence
      dotfilesAliases
    else if priorityMode == "override" then
      # Dotfiles override nixconf, but preserve non-conflicting nixconf
      nixAliases // dotfilesAliases
    else if priorityMode == "separate" then
      # Keep both, prefix dotfiles aliases with 'df-'
      nixAliases // (mapAttrs' (name: value: 
        nameValuePair 
          (if hasAttr name nixAliases then "df-${name}" else name) 
          value
      ) dotfilesAliases)
    else
      # Default fallback
      nixAliases // dotfilesAliases;

  # Merge environment variables with conflict resolution
  mergeEnvironment = nixEnv: dotfilesEnv: priorityMode:
    let
      conflicts = intersectAttrs nixEnv dotfilesEnv;
      
      # Handle PATH-like variables specially
      mergePathVar = nixVal: dotfilesVal:
        if hasPrefix "$" nixVal || hasPrefix "$" dotfilesVal then
          # If either contains variable expansion, concatenate intelligently
          "${dotfilesVal}:${nixVal}"
        else
          # Otherwise, let priority mode decide
          if priorityMode == "nixconf" then nixVal
          else dotfilesVal;
          
      mergeVar = name: nixVal: dotfilesVal:
        if elem name ["PATH" "LD_LIBRARY_PATH" "PKG_CONFIG_PATH" "MANPATH"] then
          mergePathVar nixVal dotfilesVal
        else if priorityMode == "nixconf" then
          nixVal
        else if priorityMode == "merge" || priorityMode == "override" then
          dotfilesVal
        else
          dotfilesVal;
    in
    nixEnv // dotfilesEnv // (mapAttrs (name: _:
      mergeVar name nixEnv.${name} dotfilesEnv.${name}
    ) conflicts);

  # Merge shell init extra content
  mergeShellInit = nixInit: dotfilesInit: priorityMode:
    if priorityMode == "nixconf" then
      nixInit
    else if priorityMode == "dotfiles" then
      dotfilesInit
    else if priorityMode == "override" then
      ''
        ${nixInit}
        # Dotfiles overrides
        ${dotfilesInit}
      ''
    else if priorityMode == "merge" then
      ''
        # NixOS configuration
        ${nixInit}
        
        # Dotfiles integration
        ${dotfilesInit}
      ''
    else if priorityMode == "separate" then
      ''
        ${nixInit}
        
        # Dotfiles (separate namespace)
        if [[ "$DOTFILES_SEPARATE_MODE" == "true" ]]; then
          ${dotfilesInit}
        fi
      ''
    else
      # Default: append dotfiles after nixconf
      ''
        ${nixInit}
        ${dotfilesInit}
      '';

  # Configuration conflict detection
  detectConflicts = nixConfig: dotfilesConfig:
    let
      findConflicts = path: left: right:
        if isAttrs left && isAttrs right then
          let
            commonKeys = intersectLists (attrNames left) (attrNames right);
            keyConflicts = flatten (map (key:
              findConflicts (path ++ [key]) left.${key} right.${key}
            ) commonKeys);
          in
          keyConflicts
        else if left != right then
          [{
            path = concatStringsSep "." path;
            nixValue = left;
            dotfilesValue = right;
            severity = if isString left && isString right then "low" else "medium";
          }]
        else
          [];
    in
    findConflicts [] nixConfig dotfilesConfig;

  # Generate conflict resolution strategies
  generateResolutionStrategies = conflicts:
    map (conflict: conflict // {
      strategies = [
        {
          name = "use-dotfiles";
          description = "Use dotfiles value: ${toString conflict.dotfilesValue}";
          action = "dotfiles";
        }
        {
          name = "use-nixconf";
          description = "Use NixOS value: ${toString conflict.nixValue}";
          action = "nixconf";
        }
        {
          name = "merge";
          description = "Attempt to merge both values";
          action = "merge";
        }
        {
          name = "separate";
          description = "Keep both with prefixes";
          action = "separate";
        }
      ];
    }) conflicts;

  # Apply priority mode with validation
  applyPriorityMode = { nixConfig, dotfilesConfig, priorityMode, moduleName }:
    let
      supportedModes = [ "merge" "override" "nixconf" "dotfiles" "separate" ];
      
      # Validate priority mode
      validatedMode = 
        if elem priorityMode supportedModes then
          priorityMode
        else
          trace "Warning: Invalid priority mode '${priorityMode}' for module '${moduleName}', using 'merge'" "merge";
      
      # Detect conflicts
      conflicts = detectConflicts nixConfig dotfilesConfig;
      
      # Apply mode-specific logic
      result = 
        if validatedMode == "nixconf" then
          { config = nixConfig; conflicts = []; source = "nixconf"; }
        else if validatedMode == "dotfiles" then
          { config = dotfilesConfig; conflicts = []; source = "dotfiles"; }
        else if validatedMode == "merge" then
          { 
            config = deepMerge nixConfig dotfilesConfig; 
            conflicts = conflicts; 
            source = "merged"; 
          }
        else if validatedMode == "override" then
          { 
            config = nixConfig // dotfilesConfig; 
            conflicts = conflicts; 
            source = "override"; 
          }
        else if validatedMode == "separate" then
          {
            config = nixConfig // (mapAttrs' (name: value:
              nameValuePair "dotfiles_${name}" value
            ) dotfilesConfig);
            conflicts = [];
            source = "separate";
          }
        else
          { config = deepMerge nixConfig dotfilesConfig; conflicts = conflicts; source = "fallback"; };
    in
    result // {
      priorityMode = validatedMode;
      moduleName = moduleName;
      resolutionStrategies = if conflicts != [] then generateResolutionStrategies conflicts else [];
    };

  # Logging utilities for priority mode decisions
  logPriorityDecision = { moduleName, priorityMode, conflicts, source }:
    let
      conflictCount = length conflicts;
      conflictMsg = if conflictCount > 0 then " (${toString conflictCount} conflicts detected)" else "";
    in
    trace "Priority mode for ${moduleName}: ${priorityMode} -> ${source}${conflictMsg}" null;

in
{
  inherit deepMerge mergeAliases mergeEnvironment mergeShellInit;
  inherit detectConflicts generateResolutionStrategies applyPriorityMode;
  inherit logPriorityDecision;
}