{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dotfiles.rust;
in
{
  options.dotfiles.rust = {
    enable = mkEnableOption "Rust language support";
  };

  config = mkIf cfg.enable {
    # Rust configuration will be implemented here
  };
}