{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration;
  
  # Profile definitions mapping to module sets
  profileDefinitions = {
    minimal = {
      description = "Minimal profile with essential tools only";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = false;
          editors = false;
        };
        development = {
          docker = false;
          golang = false;
          python = false;
          nodejs = false;
          rust = false;
          kubernetes = false;
        };
      };
    };
    
    developer = {
      description = "Developer profile with common development tools";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = true;
          editors = true;
        };
        development = {
          docker = true;
          golang = true;
          python = true;
          nodejs = true;
          rust = false;
          kubernetes = false;
        };
      };
    };
    
    full = {
      description = "Full profile with all available modules";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = true;
          editors = true;
        };
        development = {
          docker = true;
          golang = true;
          python = true;
          nodejs = true;
          rust = true;
          kubernetes = true;
        };
      };
    };
    
    devops = {
      description = "DevOps profile focused on infrastructure and operations";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = true;
          editors = true;
        };
        development = {
          docker = true;
          golang = false;
          python = true;
          nodejs = false;
          rust = false;
          kubernetes = true;
        };
      };
    };
    
    backend = {
      description = "Backend developer profile";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = true;
          editors = true;
        };
        development = {
          docker = true;
          golang = true;
          python = true;
          nodejs = false;
          rust = true;
          kubernetes = false;
        };
      };
    };
    
    frontend = {
      description = "Frontend developer profile";
      modules = {
        core = {
          shell = true;
          git = true;
          tmux = true;
          editors = true;
        };
        development = {
          docker = false;
          golang = false;
          python = false;
          nodejs = true;
          rust = false;
          kubernetes = false;
        };
      };
    };
  };
  
  # Helper function to get profile modules
  getProfileModules = profile:
    if hasAttr profile profileDefinitions then
      profileDefinitions.${profile}.modules
    else
      throw "Unknown profile: ${profile}. Available profiles: ${concatStringsSep ", " (attrNames profileDefinitions)}";
  
  # Helper function to merge profile with custom overrides
  mergeProfileWithCustom = profile: customModules:
    recursiveUpdate (getProfileModules profile) customModules;
in
{
  # Export profile definitions for use in other modules
  _module.args = {
    dotfilesProfiles = {
      inherit profileDefinitions;
      inherit getProfileModules;
      inherit mergeProfileWithCustom;
      availableProfiles = attrNames profileDefinitions;
    };
  };
}