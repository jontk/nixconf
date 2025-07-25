# Enhanced YAML Parser with Error Handling
{ lib }:

with lib;

let
  # Error types for better error reporting
  errorTypes = {
    FILE_NOT_FOUND = "FILE_NOT_FOUND";
    PARSE_ERROR = "PARSE_ERROR";
    INVALID_FORMAT = "INVALID_FORMAT";
    MISSING_REQUIRED = "MISSING_REQUIRED";
    TYPE_MISMATCH = "TYPE_MISMATCH";
  };
  
  # Create an error result
  makeError = { type, message, path ? null, details ? {} }:
    {
      success = false;
      error = {
        inherit type message path details;
      };
      data = null;
    };
  
  # Create a success result
  makeSuccess = data:
    {
      success = true;
      error = null;
      inherit data;
    };
  
  # Safe file reading with error handling
  safeReadFile = path:
    let
      exists = builtins.pathExists path;
    in
    if !exists then
      makeError {
        type = errorTypes.FILE_NOT_FOUND;
        message = "File not found: ${path}";
        inherit path;
      }
    else
      let
        content = builtins.tryEval (builtins.readFile path);
      in
      if content.success then
        makeSuccess content.value
      else
        makeError {
          type = errorTypes.FILE_NOT_FOUND;
          message = "Failed to read file: ${path}";
          inherit path;
          details.error = "File exists but cannot be read";
        };
  
  # Enhanced YAML parsing with error handling
  parseYamlSafe = content:
    let
      # Try to parse YAML-like content
      parseAttempt = builtins.tryEval (
        let
          lines = splitString "\n" content;
          
          # Parse a YAML value (handles strings, numbers, booleans, lists)
          parseValue = value:
            let
              trimmed = trim value;
              # Check for list notation
              isList = hasPrefix "[" trimmed && hasSuffix "]" trimmed;
              # Check for quoted string
              isQuoted = (hasPrefix "\"" trimmed && hasSuffix "\"" trimmed) ||
                        (hasPrefix "'" trimmed && hasSuffix "'" trimmed);
              # Check for boolean
              isBoolean = elem trimmed ["true" "false" "yes" "no" "on" "off"];
              # Check for number
              isNumber = builtins.match "^[0-9]+(\\.[0-9]+)?$" trimmed != null;
            in
            if trimmed == "" || trimmed == "~" || trimmed == "null" then null
            else if isList then
              # Parse list items
              let
                listContent = substring 1 (stringLength trimmed - 2) trimmed;
                items = splitString "," listContent;
              in
              map (item: parseValue (trim item)) items
            else if isQuoted then
              # Remove quotes
              substring 1 (stringLength trimmed - 2) trimmed
            else if isBoolean then
              elem trimmed ["true" "yes" "on"]
            else if isNumber then
              if hasInfix "." trimmed then
                toFloat trimmed
              else
                toInt trimmed
            else
              trimmed;
          
          # Parse YAML lines into a structure
          parseLines = lines: currentIndent: index:
            if index >= length lines then {}
            else
              let
                line = elemAt lines index;
                # Count leading spaces
                indentLevel = 
                  let
                    spaces = match "^( *)[^ ].*" line;
                  in
                  if spaces != null then stringLength (head spaces) else 0;
                
                # Skip empty lines and comments
                isEmpty = line == "" || hasPrefix "#" (trim line);
                
                # Parse key-value pairs
                keyValueMatch = match "^( *)([^:]+):(.*)$" line;
                
              in
              if isEmpty then
                parseLines lines currentIndent (index + 1)
              else if keyValueMatch != null then
                let
                  key = trim (elemAt keyValueMatch 1);
                  valueStr = trim (elemAt keyValueMatch 2);
                  hasValue = valueStr != "";
                  
                  # If no value on this line, check for nested content
                  nextResult = 
                    if !hasValue && index + 1 < length lines then
                      let
                        nextLine = elemAt lines (index + 1);
                        nextIndent = 
                          let spaces = match "^( *)[^ ].*" nextLine;
                          in if spaces != null then stringLength (head spaces) else 0;
                      in
                      if nextIndent > indentLevel then
                        # Parse nested structure
                        parseLines lines nextIndent (index + 1)
                      else
                        { value = null; nextIndex = index + 1; }
                    else
                      { value = parseValue valueStr; nextIndex = index + 1; };
                  
                in
                { ${key} = nextResult.value; } // 
                parseLines lines currentIndent nextResult.nextIndex
              else
                parseLines lines currentIndent (index + 1);
          
        in
        parseLines lines 0 0
      );
    in
    if parseAttempt.success then
      makeSuccess parseAttempt.value
    else
      makeError {
        type = errorTypes.PARSE_ERROR;
        message = "Failed to parse YAML content";
        details.error = "Invalid YAML syntax or structure";
      };
  
  # Validate required fields with proper error messages
  validateRequiredFields = { data, requiredFields, path }:
    let
      missingFields = filter (field: !hasAttr field data) requiredFields;
    in
    if missingFields == [] then
      makeSuccess data
    else
      makeError {
        type = errorTypes.MISSING_REQUIRED;
        message = "Missing required fields: ${concatStringsSep ", " missingFields}";
        inherit path;
        details.missingFields = missingFields;
      };
  
  # Type validation with error handling
  validateType = { value, expectedType, fieldName }:
    let
      actualType = 
        if isList value then "list"
        else if isAttrs value then "attrs"
        else if isString value then "string"
        else if isInt value then "int"
        else if isFloat value then "float"
        else if isBool value then "bool"
        else "unknown";
      
      typeMatches = 
        if expectedType == "any" then true
        else if expectedType == "number" then isInt value || isFloat value
        else actualType == expectedType;
    in
    if typeMatches then
      makeSuccess value
    else
      makeError {
        type = errorTypes.TYPE_MISMATCH;
        message = "Type mismatch for field '${fieldName}'";
        details = {
          expected = expectedType;
          actual = actualType;
          inherit fieldName;
        };
      };
  
  # Read and parse a module configuration with full error handling
  readModuleConfigSafe = modulePath:
    let
      # Read the file
      fileResult = safeReadFile modulePath;
    in
    if !fileResult.success then
      fileResult
    else
      let
        # Parse YAML content
        parseResult = parseYamlSafe fileResult.data;
      in
      if !parseResult.success then
        parseResult
      else
        let
          # Validate required fields
          validationResult = validateRequiredFields {
            data = parseResult.data;
            requiredFields = ["name" "description"];
            path = modulePath;
          };
        in
        if !validationResult.success then
          validationResult
        else
          # Add default values for optional fields
          makeSuccess (validationResult.data // {
            version = validationResult.data.version or "1.0.0";
            platforms = validationResult.data.platforms or ["linux" "macos"];
            dependencies = validationResult.data.dependencies or [];
            conflicts = validationResult.data.conflicts or [];
            settings = validationResult.data.settings or {};
            files = validationResult.data.files or [];
            hooks = validationResult.data.hooks or {};
          });
  
  # Wrapper functions that handle errors gracefully
  readModuleConfig = modulePath:
    let
      result = readModuleConfigSafe modulePath;
    in
    if result.success then
      result.data
    else
      # Return a default configuration on error
      trace "Warning: ${result.error.message}" {
        name = baseNameOf (dirOf modulePath);
        description = "Module configuration could not be loaded";
        version = "unknown";
        platforms = ["linux" "macos"];
        dependencies = [];
        conflicts = [];
        settings = {};
        files = [];
        hooks = {};
        error = result.error;
      };
  
  # Read modules configuration with error handling
  readModulesConfigSafe = modulesYamlPath:
    let
      fileResult = safeReadFile modulesYamlPath;
    in
    if !fileResult.success then
      fileResult
    else
      let
        parseResult = parseYamlSafe fileResult.data;
      in
      if !parseResult.success then
        parseResult
      else
        makeSuccess (parseResult.data // {
          version = parseResult.data.version or "1.0";
          modules = parseResult.data.modules or {};
        });
  
  # Read profiles configuration with error handling
  readProfilesConfigSafe = profilesYamlPath:
    let
      fileResult = safeReadFile profilesYamlPath;
    in
    if !fileResult.success then
      fileResult
    else
      let
        parseResult = parseYamlSafe fileResult.data;
      in
      if !parseResult.success then
        parseResult
      else
        makeSuccess (parseResult.data // {
          version = parseResult.data.version or "1.0";
          baseProfiles = parseResult.data.baseProfiles or {};
          profiles = parseResult.data.profiles or {};
          defaultProfile = parseResult.data.defaultProfile or "minimal";
        });
  
  # Error recovery wrappers
  readModulesConfig = modulesYamlPath:
    let
      result = readModulesConfigSafe modulesYamlPath;
    in
    if result.success then
      result.data
    else
      trace "Warning: ${result.error.message}" {
        version = "1.0";
        modules = {};
        error = result.error;
      };
  
  readProfilesConfig = profilesYamlPath:
    let
      result = readProfilesConfigSafe profilesYamlPath;
    in
    if result.success then
      result.data
    else
      trace "Warning: ${result.error.message}" {
        version = "1.0";
        baseProfiles = {};
        profiles = {};
        defaultProfile = "minimal";
        error = result.error;
      };

in
{
  # Export both safe and regular versions
  inherit errorTypes makeError makeSuccess;
  inherit safeReadFile parseYamlSafe;
  inherit validateRequiredFields validateType;
  inherit readModuleConfigSafe readModulesConfigSafe readProfilesConfigSafe;
  inherit readModuleConfig readModulesConfig readProfilesConfig;
  
  # Utility function to check if a result is successful
  isSuccess = result: result.success or false;
  
  # Get error message from result
  getError = result: 
    if result.error or null != null then
      result.error.message
    else
      "Unknown error";
}