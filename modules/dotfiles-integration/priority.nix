{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  
  # Priority mode definitions
  priorityModes = {
    merge = {
      description = "Merge configurations from both nixconf and dotfiles";
      handler = nixconf: dotfiles: nixconf // dotfiles;
    };
    
    override = {
      description = "Dotfiles completely override nixconf settings";
      handler = nixconf: dotfiles: dotfiles;
    };
    
    nixconf = {
      description = "Use only nixconf configuration, ignore dotfiles";
      handler = nixconf: dotfiles: nixconf;
    };
    
    dotfiles = {
      description = "Use only dotfiles configuration, ignore nixconf";
      handler = nixconf: dotfiles: dotfiles;
    };
    
    separate = {
      description = "Keep configurations separate, source dotfiles directly";
      handler = nixconf: dotfiles: nixconf;
    };
  };
  
  # Get priority mode for a specific module
  getModulePriority = module:
    cfg.priorityMode.${module} or cfg.mode;
  
  # Apply priority mode to configuration
  applyPriority = module: nixconf: dotfiles:
    let
      mode = getModulePriority module;
      handler = priorityModes.${mode}.handler or priorityModes.merge.handler;
    in
    handler nixconf dotfiles;
  
  # Merge configurations based on priority
  mergeConfigs = {
    # For simple attribute sets
    attrs = module: nixconf: dotfiles:
      applyPriority module nixconf dotfiles;
    
    # For lists
    lists = module: nixconf: dotfiles:
      let mode = getModulePriority module;
      in
      if mode == "merge" then unique (nixconf ++ dotfiles)
      else if mode == "override" || mode == "dotfiles" then dotfiles
      else if mode == "nixconf" then nixconf
      else nixconf;  # separate mode
    
    # For strings
    strings = module: nixconf: dotfiles:
      let mode = getModulePriority module;
      in
      if mode == "merge" then ''
        ${nixconf}
        ${dotfiles}
      ''
      else if mode == "override" || mode == "dotfiles" then dotfiles
      else if mode == "nixconf" then nixconf
      else nixconf;  # separate mode
  };
  
  # Conflict resolution strategies
  conflictStrategies = {
    # For shell aliases
    shellAliases = module: existing: new:
      let
        conflicts = intersectLists (attrNames existing) (attrNames new);
        mode = getModulePriority module;
      in
      if length conflicts > 0 then
        if mode == "merge" then
          existing // mapAttrs (name: value: 
            if elem name conflicts then
              "${existing.${name}} && ${value}"
            else value
          ) new
        else
          applyPriority module existing new
      else
        existing // new;
    
    # For environment variables
    envVars = module: existing: new:
      let
        mode = getModulePriority module;
        pathVars = [ "PATH" "NIX_PATH" "MANPATH" "INFOPATH" ];
        isPathVar = name: elem name pathVars;
      in
      mapAttrs (name: value:
        if hasAttr name existing && isPathVar name && mode == "merge" then
          "${existing.${name}}:${value}"
        else if hasAttr name existing then
          applyPriority module existing.${name} value
        else
          value
      ) new // removeAttrs existing (attrNames new);
  };
in
{
  # Export priority system utilities
  _module.args.prioritySystem = {
    inherit priorityModes;
    inherit getModulePriority;
    inherit applyPriority;
    inherit mergeConfigs;
    inherit conflictStrategies;
    
    # Helper to check if mode is valid
    isValidMode = mode: hasAttr mode priorityModes;
    
    # Get available modes
    availableModes = attrNames priorityModes;
  };
}