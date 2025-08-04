# Services Module - Main entry point for all services
{ config, lib, pkgs, ... }:

let
  cfg = config.nixconf.services;
in
{
  imports = [
    ./databases.nix
    ./web-servers.nix
    ./monitoring.nix
  ];
  
  options.nixconf.services = with lib; {
    enable = mkEnableOption "nixconf services" // { 
      default = false;
      description = "Enable all nixconf service modules";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Enable sub-modules when main services are enabled
    nixconf.services = {
      databases.enable = lib.mkDefault true;
      webServers.enable = lib.mkDefault true;
      monitoring.enable = lib.mkDefault true;
    };
  };
}