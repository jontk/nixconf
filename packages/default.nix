{ pkgs, lib, ... }:

let
  packageSets = import ./sets/default.nix { inherit pkgs lib; };
in
{
  # Re-export package sets for easy access
  inherit (packageSets) 
    core cli development 
    languages desktop security 
    sysadmin cloud database 
    network media;

  # Custom package definitions
  # Additional custom packages can be defined here
  
  # Helper function to get packages by category
  getPackageSet = name: packageSets.${name} or [];
  
  # Combined development environment
  fullDevelopment = with packageSets; 
    core ++ cli ++ development ++ 
    languages.rust ++ languages.go ++ 
    languages.python ++ languages.javascript;
    
  # Essential desktop setup
  essentialDesktop = with packageSets;
    core ++ cli ++ desktop;
    
  # Server/headless setup
  serverEssentials = with packageSets;
    core ++ cli ++ sysadmin ++ security ++ network;
}