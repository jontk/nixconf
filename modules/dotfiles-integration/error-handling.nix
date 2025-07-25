# Error Handling Utilities
{ lib }:

with lib;

let
  # Error severity levels
  severity = {
    ERROR = "ERROR";
    WARNING = "WARNING";
    INFO = "INFO";
    DEBUG = "DEBUG";
  };
  
  # Create an error record
  createError = { 
    module ? "unknown",
    operation ? "unknown", 
    message, 
    severity ? severity.ERROR,
    details ? {},
    recoverable ? false 
  }:
    {
      inherit module operation message severity details recoverable;
      timestamp = "runtime";
    };
  
  # Error accumulator for collecting multiple errors
  createErrorAccumulator = {
    errors = [];
    warnings = [];
    hasErrors = false;
    hasWarnings = false;
    
    # Add an error
    addError = acc: error:
      acc // {
        errors = acc.errors ++ [error];
        hasErrors = true;
      };
    
    # Add a warning
    addWarning = acc: warning:
      acc // {
        warnings = acc.warnings ++ [warning];
        hasWarnings = true;
      };
    
    # Get all messages
    getAllMessages = acc:
      (map (e: "[${e.severity}] ${e.module}:${e.operation} - ${e.message}") acc.errors) ++
      (map (w: "[${w.severity}] ${w.module}:${w.operation} - ${w.message}") acc.warnings);
    
    # Check if critical errors exist
    hasCriticalErrors = acc:
      any (e: e.severity == severity.ERROR && !e.recoverable) acc.errors;
  };
  
  # Try-catch style error handling
  tryOp = { operation, fallback ? null, onError ? null }:
    let
      result = builtins.tryEval operation;
    in
    if result.success then
      { success = true; value = result.value; error = null; }
    else
      let
        errorResult = {
          success = false;
          value = fallback;
          error = createError {
            operation = "tryOp";
            message = "Operation failed";
            severity = severity.ERROR;
            recoverable = fallback != null;
          };
        };
      in
      if onError != null then
        onError errorResult
      else
        errorResult;
  
  # Safe attribute access with default
  safeGetAttr = attrs: path: default:
    let
      pathList = if isList path then path else [path];
      
      getValue = attrs: remainingPath:
        if remainingPath == [] then
          attrs
        else if attrs == null || !isAttrs attrs then
          default
        else
          let
            key = head remainingPath;
            remaining = tail remainingPath;
          in
          if hasAttr key attrs then
            getValue attrs.${key} remaining
          else
            default;
    in
    getValue attrs pathList;
  
  # Validate function with error collection
  validateWithErrors = validators: value:
    let
      runValidator = validator:
        let
          result = validator value;
        in
        if isString result then
          createError {
            module = "validation";
            operation = validator.name or "validate";
            message = result;
            severity = severity.ERROR;
            recoverable = false;
          }
        else if isBool result && !result then
          createError {
            module = "validation";
            operation = validator.name or "validate";
            message = "Validation failed";
            severity = severity.ERROR;
            recoverable = false;
          }
        else
          null;
      
      errors = filter (e: e != null) (map runValidator validators);
    in
    {
      isValid = errors == [];
      errors = errors;
      value = value;
    };
  
  # Safe file operations
  safeFileOps = {
    # Read file with error handling
    readFile = path:
      tryOp {
        operation = builtins.readFile path;
        fallback = "";
        onError = result:
          result // {
            error = createError {
              module = "fileOps";
              operation = "readFile";
              message = "Failed to read file: ${path}";
              severity = severity.ERROR;
              details.path = path;
              recoverable = true;
            };
          };
      };
    
    # Check file existence safely
    pathExists = path:
      tryOp {
        operation = builtins.pathExists path;
        fallback = false;
      };
    
    # Parse JSON with error handling
    parseJSON = content:
      tryOp {
        operation = builtins.fromJSON content;
        fallback = {};
        onError = result:
          result // {
            error = createError {
              module = "fileOps";
              operation = "parseJSON";
              message = "Failed to parse JSON content";
              severity = severity.ERROR;
              recoverable = true;
            };
          };
      };
  };
  
  # Module loading with error handling
  loadModuleWithErrors = { modulePath, requiredExports ? [] }:
    let
      # Try to import the module
      importResult = tryOp {
        operation = import modulePath;
        onError = result:
          result // {
            error = createError {
              module = "moduleLoader";
              operation = "import";
              message = "Failed to import module: ${modulePath}";
              severity = severity.ERROR;
              details.path = modulePath;
            };
          };
      };
    in
    if !importResult.success then
      importResult
    else
      let
        module = importResult.value;
        
        # Check required exports
        missingExports = filter (export: !hasAttr export module) requiredExports;
      in
      if missingExports != [] then
        {
          success = false;
          value = null;
          error = createError {
            module = "moduleLoader";
            operation = "validateExports";
            message = "Module missing required exports: ${concatStringsSep ", " missingExports}";
            severity = severity.ERROR;
            details = {
              path = modulePath;
              missingExports = missingExports;
            };
          };
        }
      else
        importResult;
  
  # Error formatting utilities
  formatError = error:
    let
      detailsStr = 
        if error.details != {} then
          " (${concatStringsSep ", " (mapAttrsToList (k: v: "${k}: ${toString v}") error.details)})"
        else
          "";
    in
    "[${error.severity}] ${error.module}:${error.operation} - ${error.message}${detailsStr}";
  
  # Create error report
  createErrorReport = { errors, title ? "Error Report" }:
    ''
      === ${title} ===
      Total errors: ${toString (length errors)}
      
      ${concatStringsSep "\n" (map formatError errors)}
    '';
  
  # Error recovery strategies
  recoveryStrategies = {
    # Use default value
    useDefault = default: error: {
      strategy = "useDefault";
      value = default;
      applied = true;
      originalError = error;
    };
    
    # Skip operation
    skip = error: {
      strategy = "skip";
      value = null;
      applied = true;
      originalError = error;
    };
    
    # Retry with modifications
    retryWith = modifier: value: error: {
      strategy = "retry";
      value = modifier value;
      applied = true;
      originalError = error;
    };
    
    # Fail gracefully
    failGracefully = message: error: {
      strategy = "fail";
      value = null;
      applied = false;
      message = message;
      originalError = error;
    };
  };

in
{
  inherit severity createError createErrorAccumulator;
  inherit tryOp safeGetAttr validateWithErrors;
  inherit safeFileOps loadModuleWithErrors;
  inherit formatError createErrorReport recoveryStrategies;
  
  # Convenience functions
  isError = value: value.error or null != null;
  isSuccess = value: value.success or false;
  getErrorMessage = value: 
    if value.error or null != null then
      value.error.message
    else
      "No error";
}