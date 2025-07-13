{ config, pkgs, lib, ... }:

{
  # Remote access configuration
  # RustDesk and SSH will be configured here
  
  # Enable SSH
  services.openssh.enable = true;
  
  # RustDesk configuration placeholder
  # Will be implemented in subsequent tasks
}