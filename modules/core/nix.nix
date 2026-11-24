{ config, pkgs, ... }:

{
  # Enable experimental Nix features for Flakes and the modern CLI.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow proprietary/unfree software (e.g. Steam, Discord, Nvidia drivers).
  nixpkgs.config.allowUnfree = true;

  # Compatibility state version. Do not modify after initial installation.
  system.stateVersion = "26.05";
}
