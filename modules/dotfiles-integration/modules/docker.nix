{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for docker module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.docker or "merge"
    else
      "merge";
  
  # Read docker module configuration from module.yml
  dockerModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/docker/module.yml";
  
  # Use default settings for now
  profileSettings = dockerModuleConfig.settings;
  
  # Docker configuration files from dotfiles
  dockerAliasesFile = "${dotfilesPath}/modules/docker/docker-aliases";
  dockerComposeAliasesFile = "${dotfilesPath}/modules/docker/docker-compose-aliases";
  daemonJsonFile = "${dotfilesPath}/modules/docker/daemon.json";
  
  # Parse docker aliases
  parseDockerAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          match = builtins.match "alias ([^=]+)='([^']+)'.*" line;
        in
        if match != null then
          { name = elemAt match 0; value = elemAt match 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse docker aliases
  dockerAliases = 
    if builtins.pathExists dockerAliasesFile then
      parseDockerAliases (builtins.readFile dockerAliasesFile)
    else
      {};
  
  # Read and parse docker-compose aliases
  dockerComposeAliases = 
    if builtins.pathExists dockerComposeAliasesFile then
      parseDockerAliases (builtins.readFile dockerComposeAliasesFile)
    else
      {};
  
  # Combine all docker aliases
  allDockerAliases = dockerAliases // dockerComposeAliases;
  
  # Read daemon.json configuration
  daemonConfig = 
    if builtins.pathExists daemonJsonFile then
      builtins.fromJSON (builtins.readFile daemonJsonFile)
    else
      {};
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "docker" enabledModules)) {
    # Shell aliases for docker (this is a home-manager module, so no system config)
    programs.bash.shellAliases = mkMerge [
      (mkIf (priorityMode != "nixconf") allDockerAliases)
    ];

    programs.zsh.shellAliases = mkMerge [
      (mkIf (priorityMode != "nixconf") allDockerAliases)
    ];
    
    # Environment variables from module.yml
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_DOCKER_MODULE = "active";
      DOTFILES_DOCKER_VERSION = dockerModuleConfig.version or "unknown";
      DOCKER_BUILDKIT = mkDefault "1";
      COMPOSE_DOCKER_CLI_BUILD = mkDefault "1";
      DOCKER_SCAN_SUGGEST = mkDefault "false";
      DOCKER_CLI_HINTS = mkDefault "false";
    };
    
    # Docker daemon configuration file
    home.file.".docker/daemon.json" = mkIf (priorityMode != "nixconf" && builtins.pathExists daemonJsonFile) {
      source = daemonJsonFile;
    };
    
    # Install useful Docker tools
    home.packages = with pkgs; mkIf (priorityMode != "nixconf") [
      docker-compose
      dive # Docker image analyzer
      ctop # Container metrics
    ];
  };
}