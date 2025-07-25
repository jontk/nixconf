# Validation utilities for dotfiles integration
{ lib }:

with lib;

let
  dependencyResolver = import ./dependency-resolver.nix { inherit lib; };
  # Valid priority modes
  validPriorityModes = [ "merge" "override" "nixconf" "dotfiles" "separate" ];
  
  # Validate priority mode configuration
  validatePriorityModes = priorityModes:
    let
      invalidModes = filterAttrs (module: mode: !(elem mode validPriorityModes)) priorityModes;
      invalidModules = attrNames invalidModes;
    in
    {
      isValid = invalidModules == [];
      errors = map (module: {
        module = module;
        mode = priorityModes.${module};
        error = "Invalid priority mode '${priorityModes.${module}}' for module '${module}'";
        suggestion = "Use one of: ${concatStringsSep ", " validPriorityModes}";
      }) invalidModules;
      warnings = [];
    };

  # Validate module dependencies (enhanced version using dependency resolver)
  validateModuleDependencies = { enabledModules, yamlStructure }:
    if yamlStructure == null then
      { isValid = true; errors = []; warnings = []; }
    else
      let
        platform = "linux"; # Default platform for validation
        resolution = dependencyResolver.resolveDependencies { 
          inherit enabledModules yamlStructure platform; 
        };
        
        errors = 
          (if resolution.missingDependencies != [] then [{
            error = "Missing required dependencies: ${concatStringsSep ", " resolution.missingDependencies}";
            missingDependencies = resolution.missingDependencies;
            suggestion = "Enable these modules: ${concatStringsSep ", " resolution.missingDependencies}";
          }] else []) ++
          (if resolution.hasCycles then [{
            error = "Circular dependencies detected: ${concatStringsSep " -> " resolution.cycles}";
            cycles = resolution.cycles;
            suggestion = "Remove one of the dependencies to break the cycle";
          }] else []);
        
        warnings = 
          if resolution.autoEnableModules != {} then [{
            warning = "These modules could be auto-enabled: ${concatStringsSep ", " (attrNames resolution.autoEnableModules)}";
            suggestion = "Consider enabling these dependencies automatically";
          }] else [];
      in
      {
        isValid = resolution.isResolved;
        errors = errors;
        warnings = warnings;
        resolution = resolution;
      };

  # Detect circular dependencies
  detectCircularDependencies = { yamlStructure }:
    let
      modules = if yamlStructure != null then yamlStructure.modulesConfig.modules else {};
      
      # Build dependency graph
      buildGraph = moduleName:
        let
          deps = modules.${moduleName}.depends_on or [];
        in
        { name = moduleName; dependencies = deps; };
      
      moduleList = attrNames modules;
      graph = listToAttrs (map (name: nameValuePair name (buildGraph name)) moduleList);
      
      # Find cycles using DFS
      findCycles = visited: path: current:
        if elem current path then
          # Found a cycle
          let
            cycleStart = findFirst (x: x == current) 0 path;
            cycle = drop cycleStart path ++ [current];
          in
          [cycle]
        else if elem current visited then
          # Already processed this node
          []
        else
          # Continue DFS
          let
            deps = graph.${current}.dependencies or [];
            newPath = path ++ [current];
            newVisited = visited ++ [current];
          in
          flatten (map (dep: 
            if hasAttr dep graph then
              findCycles newVisited newPath dep
            else
              []
          ) deps);
      
      allCycles = unique (flatten (map (module: findCycles [] [] module) moduleList));
    in
    {
      hasCycles = allCycles != [];
      cycles = allCycles;
      errors = map (cycle: {
        error = "Circular dependency detected: ${concatStringsSep " -> " cycle}";
        cycle = cycle;
        suggestion = "Remove one of the dependencies to break the cycle";
      }) allCycles;
    };

  # Validate user configuration
  validateUserConfig = userConfig:
    let
      # Check required fields
      hasProfile = userConfig ? user && userConfig.user ? profile;
      hasModules = userConfig ? modules;
      hasPriorityModes = userConfig ? priorityModes;
      
      errors = []
        ++ (if !hasProfile then [{ error = "Missing user.profile configuration"; field = "user.profile"; }] else [])
        ++ (if !hasModules then [{ error = "Missing modules configuration"; field = "modules"; }] else [])
        ++ (if !hasPriorityModes then [] else []);  # Priority modes are optional
      
      warnings = []
        ++ (if !hasPriorityModes then [{ warning = "No priority modes configured, using defaults"; field = "priorityModes"; }] else []);
    in
    {
      isValid = errors == [];
      errors = errors;
      warnings = warnings;
    };

  # Comprehensive validation function
  validateConfiguration = { userConfig, enabledModules, yamlStructure }:
    let
      userValidation = validateUserConfig userConfig;
      priorityValidation = if userConfig ? priorityModes then validatePriorityModes userConfig.priorityModes else { isValid = true; errors = []; warnings = []; };
      dependencyValidation = validateModuleDependencies { inherit enabledModules yamlStructure; };
      circularValidation = detectCircularDependencies { inherit yamlStructure; };
      
      allErrors = userValidation.errors ++ priorityValidation.errors ++ dependencyValidation.errors ++ circularValidation.errors;
      allWarnings = userValidation.warnings ++ priorityValidation.warnings ++ dependencyValidation.warnings;
    in
    {
      isValid = allErrors == [];
      errors = allErrors;
      warnings = allWarnings;
      
      # Detailed results
      user = userValidation;
      priorityModes = priorityValidation;
      dependencies = dependencyValidation;
      circular = circularValidation;
      
      # Summary
      summary = {
        totalErrors = length allErrors;
        totalWarnings = length allWarnings;
        validationsPassed = 
          (if userValidation.isValid then 1 else 0) +
          (if priorityValidation.isValid then 1 else 0) +
          (if dependencyValidation.isValid then 1 else 0) +
          (if !circularValidation.hasCycles then 1 else 0);
        totalValidations = 4;
      };
    };

  # Generate validation report
  generateValidationReport = validationResult:
    let
      errorSection = if validationResult.errors != [] then
        ''
          ERRORS (${toString (length validationResult.errors)}):
          ${concatMapStringsSep "\n" (error: "  - ${error.error}") validationResult.errors}
        ''
      else
        "✅ No errors found";
      
      warningSection = if validationResult.warnings != [] then
        ''
          
          WARNINGS (${toString (length validationResult.warnings)}):
          ${concatMapStringsSep "\n" (warning: "  - ${warning.warning or warning}") validationResult.warnings}
        ''
      else
        "";
      
      summarySection = ''
        
        SUMMARY:
        - Validations passed: ${toString validationResult.summary.validationsPassed}/${toString validationResult.summary.totalValidations}
        - Status: ${if validationResult.isValid then "PASSED ✅" else "FAILED ❌"}
      '';
    in
    ''
      Dotfiles Integration Validation Report
      =====================================
      ${errorSection}${warningSection}${summarySection}
    '';

in
{
  inherit validatePriorityModes validateModuleDependencies detectCircularDependencies;
  inherit validateUserConfig validateConfiguration generateValidationReport;
  inherit validPriorityModes;
}