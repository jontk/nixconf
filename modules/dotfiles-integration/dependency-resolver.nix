# Module Dependency Resolution System
{ lib }:

with lib;

let
  # Build dependency graph from YAML structure
  buildDependencyGraph = yamlStructure:
    let
      modules = if yamlStructure != null && yamlStructure ? modulesConfig && yamlStructure.modulesConfig ? modules 
                then yamlStructure.modulesConfig.modules
                else {};
      
      buildModuleNode = moduleName: moduleConfig:
        {
          name = moduleName;
          dependencies = moduleConfig.depends_on or [];
          optional_dependencies = moduleConfig.optional_depends_on or [];
          platforms = moduleConfig.platforms or [ "linux" "macos" ];
          category = moduleConfig.category or "unknown";
          version = moduleConfig.version or "unknown";
        };
      
      moduleList = attrNames modules;
      graph = listToAttrs (map (name: 
        nameValuePair name (buildModuleNode name modules.${name})
      ) moduleList);
    in
    graph;

  # Topological sort for dependency ordering
  topologicalSort = graph:
    let
      # Kahn's algorithm for topological sorting
      moduleNames = attrNames graph;
      
      # Calculate in-degrees
      calculateInDegrees = 
        let
          initDegrees = listToAttrs (map (name: nameValuePair name 0) moduleNames);
          addDependency = degrees: from: to:
            if hasAttr to degrees then
              degrees // { ${to} = degrees.${to} + 1; }
            else
              degrees;
          
          processDependencies = degrees: moduleName:
            let
              deps = graph.${moduleName}.dependencies or [];
            in
            foldl' (acc: dep: addDependency acc moduleName dep) degrees deps;
        in
        foldl' processDependencies initDegrees moduleNames;
      
      # Sort algorithm
      sortStep = { remaining, sorted, inDegrees }:
        let
          # Find nodes with in-degree 0
          readyNodes = filter (name: inDegrees.${name} == 0) remaining;
          
          # If no ready nodes but remaining nodes exist, we have a cycle
          hasCycle = readyNodes == [] && remaining != [];
        in
        if remaining == [] then
          { success = true; result = sorted; cycles = []; }
        else if hasCycle then
          { success = false; result = sorted; cycles = remaining; }
        else
          let
            # Take first ready node
            current = head readyNodes;
            newRemaining = filter (name: name != current) remaining;
            newSorted = sorted ++ [current];
            
            # Update in-degrees by removing edges from current node
            currentDeps = graph.${current}.dependencies or [];
            updateInDegree = degrees: dep:
              if hasAttr dep degrees then
                degrees // { ${dep} = degrees.${dep} - 1; }
              else
                degrees;
            newInDegrees = foldl' updateInDegree inDegrees currentDeps;
          in
          sortStep {
            remaining = newRemaining;
            sorted = newSorted;
            inDegrees = newInDegrees;
          };
      
      initialInDegrees = calculateInDegrees;
    in
    sortStep {
      remaining = moduleNames;
      sorted = [];
      inDegrees = initialInDegrees;
    };

  # Resolve dependencies for a set of enabled modules
  resolveDependencies = { enabledModules, yamlStructure, platform ? "linux" }:
    let
      graph = buildDependencyGraph yamlStructure;
      enabledModuleList = attrNames enabledModules;
      
      # Recursively collect all dependencies
      collectDependencies = visited: moduleName:
        if elem moduleName visited then
          # Avoid infinite recursion
          []
        else if !hasAttr moduleName graph then
          # Module not found in graph
          []
        else
          let
            node = graph.${moduleName};
            newVisited = visited ++ [moduleName];
            
            # Check platform compatibility
            isPlatformSupported = elem platform node.platforms;
            
            # Get direct dependencies
            directDeps = if isPlatformSupported then node.dependencies else [];
            
            # Recursively get dependencies of dependencies
            indirectDeps = flatten (map (dep: collectDependencies newVisited dep) directDeps);
          in
          if isPlatformSupported then
            unique (directDeps ++ indirectDeps)
          else
            [];
      
      # Collect all required dependencies
      allRequiredDeps = unique (flatten (map (module: collectDependencies [] module) enabledModuleList));
      
      # Find missing dependencies
      missingDeps = filter (dep: !hasAttr dep enabledModules) allRequiredDeps;
      
      # Find modules with missing dependencies
      modulesWithMissingDeps = filter (module:
        let
          moduleDeps = collectDependencies [] module;
          moduleMissingDeps = filter (dep: !hasAttr dep enabledModules) moduleDeps;
        in
        moduleMissingDeps != []
      ) enabledModuleList;
      
      # Generate auto-enable suggestions
      autoEnableModules = listToAttrs (map (dep: nameValuePair dep {
        enabled = "auto";
        reason = "Required dependency";
        requiredBy = filter (module: elem dep (collectDependencies [] module)) enabledModuleList;
      }) missingDeps);
      
      # Check for circular dependencies
      sortResult = topologicalSort (filterAttrs (name: _: hasAttr name enabledModules || elem name allRequiredDeps) graph);
      
    in
    {
      graph = graph;
      enabledModules = enabledModuleList;
      requiredDependencies = allRequiredDeps;
      missingDependencies = missingDeps;
      modulesWithMissingDeps = modulesWithMissingDeps;
      autoEnableModules = autoEnableModules;
      hasCycles = !sortResult.success;
      cycles = if sortResult.success then [] else sortResult.cycles;
      loadOrder = if sortResult.success then sortResult.result else [];
      
      # Resolution status
      isResolved = missingDeps == [] && sortResult.success;
      
      # Suggestions for user
      suggestions = 
        (if missingDeps != [] then [
          {
            type = "enable-dependencies";
            message = "Enable missing dependencies: ${concatStringsSep ", " missingDeps}";
            action = "Add these modules to your configuration";
          }
        ] else []) ++
        (if !sortResult.success then [
          {
            type = "resolve-cycles";
            message = "Resolve circular dependencies: ${concatStringsSep " -> " sortResult.cycles}";
            action = "Remove one or more dependencies to break the cycle";
          }
        ] else []);
    };

  # Auto-resolve dependencies by enabling required modules
  autoResolveDependencies = { userModules, yamlStructure, platform ? "linux" }:
    let
      # Get current enabled modules
      currentEnabled = filterAttrs (name: config: 
        config.enabled == "enabled" || config.enabled == "auto"
      ) userModules;
      
      # Resolve dependencies for current modules
      resolution = resolveDependencies { 
        enabledModules = currentEnabled; 
        inherit yamlStructure platform; 
      };
      
      # Auto-enable missing dependencies
      autoEnabled = resolution.autoEnableModules;
      
      # Merge with existing configuration
      resolvedModules = userModules // autoEnabled;
      
      # Re-check resolution with auto-enabled modules
      finalResolution = resolveDependencies {
        enabledModules = filterAttrs (name: config: 
          config.enabled == "enabled" || config.enabled == "auto"
        ) resolvedModules;
        inherit yamlStructure platform;
      };
      
    in
    {
      originalModules = userModules;
      resolvedModules = resolvedModules;
      autoEnabledModules = autoEnabled;
      resolution = finalResolution;
      changesApplied = autoEnabled != {};
    };

  # Validate module configuration for dependencies
  validateModuleDependencies = { userConfig, yamlStructure, platform ? "linux" }:
    let
      userModules = userConfig.modules or {};
      resolution = resolveDependencies {
        enabledModules = filterAttrs (name: config: 
          config.enabled == "enabled" || config.enabled == "auto"
        ) userModules;
        inherit yamlStructure platform;
      };
      
      # Generate detailed validation report
      errors = 
        (if resolution.missingDependencies != [] then [{
          type = "missing-dependencies";
          severity = "error";
          message = "Missing required dependencies: ${concatStringsSep ", " resolution.missingDependencies}";
          modules = resolution.modulesWithMissingDeps;
          dependencies = resolution.missingDependencies;
        }] else []) ++
        (if resolution.hasCycles then [{
          type = "circular-dependencies";
          severity = "error";
          message = "Circular dependencies detected: ${concatStringsSep " -> " resolution.cycles}";
          cycles = resolution.cycles;
        }] else []);
      
      warnings = [];
      
    in
    {
      isValid = resolution.isResolved;
      errors = errors;
      warnings = warnings;
      resolution = resolution;
      suggestions = resolution.suggestions;
    };

  # Generate dependency graph visualization (DOT format)
  generateDependencyGraphDot = { yamlStructure, enabledModules ? {} }:
    let
      graph = buildDependencyGraph yamlStructure;
      enabledList = attrNames enabledModules;
      
      # Generate node definitions
      nodeColor = moduleName:
        if elem moduleName enabledList then "lightblue"
        else "white";
      
      nodes = concatMapStringsSep "\n" (name:
        let node = graph.${name}; in
        "  \"${name}\" [label=\"${name}\\n(${node.category})\" fillcolor=\"${nodeColor name}\" style=\"filled\"];"
      ) (attrNames graph);
      
      # Generate edge definitions
      edges = concatMapStringsSep "\n" (name:
        let
          node = graph.${name};
          deps = node.dependencies;
        in
        concatMapStringsSep "\n" (dep:
          "  \"${name}\" -> \"${dep}\";"
        ) deps
      ) (attrNames graph);
      
    in
    ''
      digraph module_dependencies {
        rankdir=TB;
        node [shape=box];
        
        // Nodes
      ${nodes}
        
        // Dependencies
      ${edges}
        
        // Legend
        subgraph cluster_legend {
          label="Legend";
          style=filled;
          fillcolor=lightgray;
          
          enabled [fillcolor=lightblue style=filled label="Enabled"];
          available [fillcolor=white style=filled label="Available"];
        }
      }
    '';

in
{
  inherit buildDependencyGraph topologicalSort resolveDependencies;
  inherit autoResolveDependencies validateModuleDependencies;
  inherit generateDependencyGraphDot;
}