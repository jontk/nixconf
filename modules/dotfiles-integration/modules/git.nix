{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  settingsParser = import ../settings-parser.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for git module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.git or "merge"
    else
      "merge";
  
  # Read git module configuration from module.yml
  gitModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/git/module.yml";
  
  # Parse and apply module settings
  settingDefinitions = settingsParser.parseModuleSettings gitModuleConfig;
  
  # Apply profile-specific settings
  profileGitConfig = settingsParser.applyProfileSettings {
    moduleConfig = gitModuleConfig;
    profile = cfg.user.profile or "default";
  };
  
  # Get user overrides from Nix configuration
  userOverrides = cfg.modules.git.settings or {};
  
  # Apply user overrides to module settings
  overrideResult = settingsParser.applyUserOverrides {
    moduleSettings = profileGitConfig.settings;
    userOverrides = userOverrides;
  };
  
  # Final settings after all processing
  profileSettings = overrideResult.settings;
  
  # Generate configuration from settings
  settingsConfig = settingsParser.generateConfigFromSettings {
    moduleConfig = profileGitConfig;
    settings = profileSettings;
    platform = if pkgs.stdenv.isDarwin then "macos" else "linux";
  };
  
  # Validate settings
  settingsValidation = settingsParser.validateSettings {
    settings = profileSettings;
    settingDefinitions = settingDefinitions;
  };
  
  # Git configuration files from dotfiles
  gitconfigFile = "${dotfilesPath}/modules/git/gitconfig";
  gitAliasesFile = "${dotfilesPath}/modules/git/git_aliases";
  gitignoreFile = "${dotfilesPath}/modules/git/gitignore_global";
  
  # Parse INI-style gitconfig file
  parseGitConfig = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l) && !(hasPrefix ";" l)) (splitString "\n" content);
      
      # Parse section headers [section] or [section "subsection"]
      parseSectionHeader = line:
        let
          # Match [section] or [section "subsection"]
          sectionMatch = builtins.match "^\\[([^]\"]+)( \"([^\"]+)\")?\\]$" (lib.trim line);
        in
        if sectionMatch != null then
          {
            type = "section";
            section = elemAt sectionMatch 0;
            subsection = if (elemAt sectionMatch 2) != null then elemAt sectionMatch 2 else null;
          }
        else null;
      
      # Parse key-value pairs
      parseKeyValue = line:
        let
          # Split on first = sign
          parts = splitString "=" line;
          key = lib.trim (elemAt parts 0);
          value = if length parts > 1 then 
            lib.trim (concatStringsSep "=" (tail parts))
          else "";
        in
        if length parts >= 2 then
          { type = "keyvalue"; inherit key value; }
        else null;
      
      # Parse include directives
      parseInclude = line:
        let
          includeMatch = builtins.match "^\\s*path\\s*=\\s*(.+)$" line;
          includeIfMatch = builtins.match "^\\s*\\[includeIf\\s+\"(.+)\"\\]$" line;
        in
        if includeMatch != null then
          { type = "include"; path = lib.trim (elemAt includeMatch 0); }
        else if includeIfMatch != null then
          { type = "includeIf"; condition = lib.trim (elemAt includeIfMatch 0); }
        else null;
      
      # Process all lines
      processLines = lines: currentSection: currentSubsection: acc:
        if lines == [] then acc
        else
          let
            line = head lines;
            remaining = tail lines;
            
            sectionHeader = parseSectionHeader line;
            keyValue = if sectionHeader == null then parseKeyValue line else null;
            include = if sectionHeader == null && keyValue == null then parseInclude line else null;
            
          in
          if sectionHeader != null then
            processLines remaining sectionHeader.section sectionHeader.subsection acc
          else if keyValue != null then
            let
              sectionName = if currentSubsection != null then 
                "${currentSection}.${currentSubsection}" else currentSection;
              sectionConfig = acc.${sectionName} or {};
              newSectionConfig = sectionConfig // { ${keyValue.key} = keyValue.value; };
            in
            processLines remaining currentSection currentSubsection (acc // { ${sectionName} = newSectionConfig; })
          else if include != null then
            # For now, just record includes without processing them
            let
              includesList = acc._includes or [];
              newIncludes = includesList ++ [ include ];
            in
            processLines remaining currentSection currentSubsection (acc // { _includes = newIncludes; })
          else
            processLines remaining currentSection currentSubsection acc;
      
    in
    processLines lines null null {};
  
  # Parse git aliases file (simple format)
  parseGitAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          # Git aliases are in format: alias_name = command
          parts = splitString " = " line;
        in
        if length parts == 2 then
          { name = elemAt parts 0; value = elemAt parts 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse git configuration
  dotfilesGitConfig = 
    if builtins.pathExists gitconfigFile then
      parseGitConfig (builtins.readFile gitconfigFile)
    else
      {};
  
  # Read and parse git aliases
  dotfilesGitAliases = 
    if builtins.pathExists gitAliasesFile then
      parseGitAliases (builtins.readFile gitAliasesFile)
    else
      {};
  
  # Extract user configuration from parsed git config
  extractUserConfig = gitConfig:
    let
      userSection = gitConfig.user or {};
    in
    {
      name = userSection.name or (profileSettings.user_name or null);
      email = userSection.email or (profileSettings.user_email or null);
      signingkey = userSection.signingkey or (profileSettings.signing_key or null);
    };
  
  # Extract core configuration
  extractCoreConfig = gitConfig:
    let
      coreSection = gitConfig.core or {};
    in
    {
      editor = coreSection.editor or (profileSettings.editor or null);
      autocrlf = if (coreSection.autocrlf or "false") == "true" then true else false;
      filemode = if (coreSection.filemode or "true") == "true" then true else false;
      ignorecase = if (coreSection.ignorecase or "false") == "true" then true else false;
      excludesfile = coreSection.excludesfile or gitignoreFile;
    };
  
  # Extract branch configuration
  extractBranchConfig = gitConfig:
    let
      initSection = gitConfig.init or {};
      branchSection = gitConfig.branch or {};
    in
    {
      defaultBranch = initSection.defaultBranch or (profileSettings.default_branch or "main");
      autosetupmerge = branchSection.autosetupmerge or "true";
      autosetuprebase = branchSection.autosetuprebase or "never";
    };
  
  # Process conditional includes
  processConditionalIncludes = gitConfig:
    let
      includes = gitConfig._includes or [];
      conditionalIncludes = filter (inc: inc.type == "includeIf") includes;
      
      # For now, just return info about conditional includes
      # Full implementation would evaluate conditions like "gitdir:~/work/"
      workIncludes = filter (inc: hasInfix "work" inc.condition) conditionalIncludes;
      personalIncludes = filter (inc: hasInfix "personal" inc.condition) conditionalIncludes;
    in
    {
      hasConditionalIncludes = conditionalIncludes != [];
      workConfig = workIncludes != [];
      personalConfig = personalIncludes != [];
      allIncludes = includes;
    };
  
  # Build final git configuration
  userGitConfig = extractUserConfig dotfilesGitConfig;
  coreGitConfig = extractCoreConfig dotfilesGitConfig;
  branchGitConfig = extractBranchConfig dotfilesGitConfig;
  conditionalConfig = processConditionalIncludes dotfilesGitConfig;
  
  # Read gitignore patterns
  gitignorePatterns = 
    if builtins.pathExists gitignoreFile then
      splitString "\n" (builtins.readFile gitignoreFile)
    else
      [];
  
  # Merge git aliases based on priority mode
  mergeGitAliases = existing: dotfiles:
    if priorityMode == "nixconf" then existing
    else if priorityMode == "dotfiles" || priorityMode == "override" then dotfiles
    else if priorityMode == "merge" then existing // dotfiles
    else existing;  # separate mode
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "git" enabledModules)) {
    # Only configure if we're in home-manager context
    programs.git = {
      enable = true;
      
      # User configuration (let user set these in their config)
      userName = mkDefault config.programs.git.userName or null;
      userEmail = mkDefault config.programs.git.userEmail or null;
      
      # Git aliases
      aliases = mkIf (priorityMode != "separate")
        dotfilesGitAliases;
      
      # Global gitignore
      ignores = mkIf (priorityMode != "nixconf")
        gitignorePatterns;
      
      # Extra configuration
      extraConfig = mkMerge [
        # Existing extra config
        # Skip existing config to avoid recursion
        
        # Core settings from dotfiles gitconfig
        (mkIf (priorityMode != "nixconf" && priorityMode != "separate" && builtins.pathExists gitconfigFile)
          (let
            # Extract key git settings from gitconfig
            # This is a simplified approach - in a real implementation, we'd parse the INI format
          in {
            core = {
              editor = mkDefault "vim";
              whitespace = mkDefault "trailing-space,space-before-tab";
              autocrlf = mkDefault "input";
              filemode = mkDefault true;
            };
            
            init = {
              defaultBranch = mkDefault "main";
            };
            
            pull = {
              rebase = mkDefault true;
            };
            
            push = {
              default = mkDefault "current";
              autoSetupRemote = mkDefault true;
            };
            
            merge = {
              ff = mkDefault false;
              tool = mkDefault "vimdiff";
            };
            
            diff = {
              colorMoved = mkDefault "default";
              algorithm = mkDefault "patience";
            };
            
            color = {
              ui = mkDefault "auto";
              diff = mkDefault "auto";
              status = mkDefault "auto";
              branch = mkDefault "auto";
            };
            
            rerere = {
              enabled = mkDefault true;
            };
          }))
        
        # For separate mode, include the gitconfig path
        (mkIf (priorityMode == "separate")
          {
            include = {
              path = gitconfigFile;
            };
          })
      ];
    };
    
    # Environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_GIT_MODULE = "active";
      DOTFILES_GIT_VERSION = gitModuleConfig.version or "unknown";
    };
  };
}