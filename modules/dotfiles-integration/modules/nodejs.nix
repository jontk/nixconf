{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dotfiles.nodejs;
in
{
  options.dotfiles.nodejs = {
    enable = mkEnableOption "Node.js language support";
  };

  config = mkIf cfg.enable {
    # Node.js configuration will be implemented here
  };
}