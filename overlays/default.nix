# Main overlay composition - combines all custom overlays
# This file is imported by flake.nix and applied to nixpkgs

final: prev: 
let
  # Import individual overlay files
  developmentOverlay = import ./development.nix;
  securityOverlay = import ./security.nix;
  desktopOverlay = import ./desktop.nix;
  customPackagesOverlay = import ./custom-packages.nix;
in
{
  # Apply all overlays in sequence
} 
// (developmentOverlay final prev)
// (securityOverlay final prev)
// (desktopOverlay final prev)
// (customPackagesOverlay final prev)