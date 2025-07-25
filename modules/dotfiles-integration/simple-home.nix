# Simple home-manager integration for dotfiles
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.dotfilesIntegration or {};
in
{
  imports = lib.optionals (cfg.enable or false) [
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/editors.nix
  ];
}