{ config, pkgs, lib, ... }:

{
  # Development environment configuration
  # Detailed packages will be configured in subsequent tasks

  environment.systemPackages = with pkgs; [
    # Essential development tools
    git
    vim
    
    # Development tools will be added here
  ];
}