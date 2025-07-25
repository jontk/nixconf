# Module Settings Parser and Integration System
{ lib }:

with lib;

let
  # Parse and validate module settings from YAML
  parseModuleSettings = moduleConfig:
    let
      rawSettings = moduleConfig.settings or {};
      
      # Parse setting definition
      parseSetting = name: settingDef:
        if isAttrs settingDef then
          {
            inherit name;
            type = settingDef.type or "string";
            default = settingDef.default or null;
            description = settingDef.description or "";
            options = settingDef.options or [];
            required = settingDef.required or false;
            validation = settingDef.validation or null;
          }
        else
          {
            inherit name;
            type = "string";
            default = settingDef;
            description = "";
            options = [];
            required = false;
            validation = null;
          };
      
      # Parse all settings
      parsedSettings = mapAttrs parseSetting rawSettings;
    in
    parsedSettings;

  # Apply profile-specific settings
  applyProfileSettings = { moduleConfig, profile }:
    let
      profileSettings = 
        if hasAttr "profile_settings" moduleConfig && hasAttr profile moduleConfig.profile_settings then
          moduleConfig.profile_settings.${profile}
        else
          {};
      
      defaultSettings = moduleConfig.settings or {};
      
      # Merge profile settings with defaults
      mergedSettings = defaultSettings // profileSettings;
    in
    moduleConfig // {
      settings = mergedSettings;
      appliedProfile = profile;
    };

  # Validate setting values against their definitions
  validateSettings = { settings, settingDefinitions }:
    let
      validateSetting = name: value: settingDef:
        let
          expectedType = settingDef.type;
          hasOptions = settingDef.options != [];
          
          # Type validation
          typeValid = 
            if expectedType == "string" then isString value
            else if expectedType == "integer" || expectedType == "int" then isInt value
            else if expectedType == "boolean" || expectedType == "bool" then isBool value
            else if expectedType == "list" then isList value
            else if expectedType == "attrs" then isAttrs value
            else true; # Unknown types pass validation
          
          # Options validation (enum-like)
          optionValid = !hasOptions || elem value settingDef.options;
          
          # Required field validation
          requiredValid = !settingDef.required || value != null;
          
          # Custom validation (if provided)
          customValid = 
            if settingDef.validation != null then
              # This would need to be implemented based on validation syntax
              true
            else
              true;
          
          errors = []
            ++ (if !typeValid then [{ 
                 error = "Invalid type for '${name}': expected ${expectedType}, got ${typeOf value}"; 
                 field = name; 
               }] else [])
            ++ (if !optionValid then [{ 
                 error = "Invalid value for '${name}': must be one of ${concatStringsSep ", " (map toString settingDef.options)}"; 
                 field = name; 
               }] else [])
            ++ (if !requiredValid then [{ 
                 error = "Required setting '${name}' is missing or null"; 
                 field = name; 
               }] else []);
          
        in
        {
          field = name;
          value = value;
          definition = settingDef;
          isValid = errors == [];
          errors = errors;
        };
      
      # Validate all settings
      validationResults = mapAttrs (name: value:
        if hasAttr name settingDefinitions then
          validateSetting name value settingDefinitions.${name}
        else
          {
            field = name;
            value = value;
            definition = null;
            isValid = false;
            errors = [{ error = "Unknown setting '${name}'"; field = name; }];
          }
      ) settings;
      
      # Check for missing required settings
      missingRequired = filter (name:
        let settingDef = settingDefinitions.${name}; in
        settingDef.required && !(hasAttr name settings)
      ) (attrNames settingDefinitions);
      
      allErrors = flatten (map (result: result.errors) (attrValues validationResults))
                ++ (map (name: { error = "Required setting '${name}' is missing"; field = name; }) missingRequired);
      
    in
    {
      isValid = allErrors == [];
      errors = allErrors;
      results = validationResults;
      missingRequired = missingRequired;
    };

  # Apply user overrides to module settings
  applyUserOverrides = { moduleSettings, userOverrides ? {} }:
    let
      # Merge user overrides with module settings
      mergedSettings = moduleSettings // userOverrides;
      
      # Keep track of what was overridden
      overriddenKeys = intersectLists (attrNames moduleSettings) (attrNames userOverrides);
    in
    {
      settings = mergedSettings;
      overriddenKeys = overriddenKeys;
      hasOverrides = overriddenKeys != [];
    };

  # Convert settings to environment variables
  settingsToEnvironment = { settings, modulePrefix ? "DOTFILES" }:
    let
      # Convert setting name to environment variable name
      toEnvName = name: "${modulePrefix}_${toUpper (replaceStrings ["-"] ["_"] name)}";
      
      # Convert setting value to string
      toEnvValue = value: 
        if isBool value then (if value then "true" else "false")
        else if isList value then concatStringsSep ":" (map toString value)
        else toString value;
      
      envVars = mapAttrs' (name: value:
        nameValuePair (toEnvName name) (toEnvValue value)
      ) settings;
    in
    envVars;

  # Convert settings to shell aliases
  settingsToAliases = { settings, modulePrefix ? "" }:
    let
      # Only convert settings that make sense as aliases
      aliasableSettings = filterAttrs (name: value: 
        isString value && value != ""
      ) settings;
      
      # Create aliases with optional prefix
      aliases = mapAttrs' (name: value:
        let aliasName = if modulePrefix != "" then "${modulePrefix}_${name}" else name; in
        nameValuePair aliasName value
      ) aliasableSettings;
    in
    aliases;

  # Generate configuration based on settings
  generateConfigFromSettings = { moduleConfig, settings, platform ? "linux" }:
    let
      settingDefs = parseModuleSettings moduleConfig;
      
      # Apply settings to generate platform-specific config
      platformConfig = 
        if hasAttr "platform_settings" moduleConfig && hasAttr platform moduleConfig.platform_settings then
          moduleConfig.platform_settings.${platform}
        else
          {};
      
      # Merge all settings: defaults -> platform -> user settings
      finalSettings = (moduleConfig.settings or {}) // platformConfig // settings;
      
      # Generate environment variables
      environmentVars = settingsToEnvironment { 
        settings = finalSettings; 
        modulePrefix = "DOTFILES_${toUpper moduleConfig.name}";
      };
      
      # Generate conditional configuration
      conditionalConfig = {
        # Enable/disable features based on settings
        enableFeatures = filterAttrs (name: value: 
          hasPrefix "enable_" name && value == true
        ) finalSettings;
        
        disableFeatures = filterAttrs (name: value: 
          hasPrefix "enable_" name && value == false
        ) finalSettings;
        
        # Path configurations
        pathSettings = filterAttrs (name: value: 
          hasSuffix "_path" name || hasSuffix "_dir" name
        ) finalSettings;
        
        # Tool configurations
        toolSettings = filterAttrs (name: value: 
          hasPrefix "tool_" name || hasSuffix "_tool" name
        ) finalSettings;
      };
    in
    {
      settings = finalSettings;
      environment = environmentVars;
      conditional = conditionalConfig;
      moduleConfig = moduleConfig // { resolvedSettings = finalSettings; };
    };

  # Create settings validation report
  generateSettingsReport = { moduleConfig, settings, userOverrides ? {} }:
    let
      settingDefs = parseModuleSettings moduleConfig;
      validation = validateSettings { inherit settings; settingDefinitions = settingDefs; };
      overrides = applyUserOverrides { moduleSettings = settings; inherit userOverrides; };
      
      report = {
        module = moduleConfig.name or "unknown";
        totalSettings = length (attrNames settingDefs);
        validSettings = length (filter (result: result.isValid) (attrValues validation.results));
        invalidSettings = length validation.errors;
        userOverrides = length overrides.overriddenKeys;
        
        summary = 
          if validation.isValid then "✅ All settings valid"
          else "❌ ${toString (length validation.errors)} validation errors";
        
        details = {
          inherit validation overrides;
          settingDefinitions = settingDefs;
        };
      };
    in
    report;

in
{
  inherit parseModuleSettings applyProfileSettings validateSettings;
  inherit applyUserOverrides settingsToEnvironment settingsToAliases;
  inherit generateConfigFromSettings generateSettingsReport;
}