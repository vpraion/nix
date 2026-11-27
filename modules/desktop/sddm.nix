{ lib, pkgs, ... }:

let
  sddmSetup = pkgs.writeShellApplication {
    name = "sddm-setup";
    runtimeInputs = with pkgs; [ xrandr gawk ];
    text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./scripts/sddm-setup.sh);
  };
in
{
  # X11 server required by SDDM display manager.
  services.xserver.enable = true;

  # Display Manager configuration.
  services.displayManager = {
    sddm = {
      enable      = true;
      theme       = "catppuccin-mocha-mauve";
      package     = pkgs.kdePackages.sddm;
      setupScript = "${sddmSetup}/bin/sddm-setup";
    };

    # Launch into Hyprland wrapped with UWSM by default.
    defaultSession = "hyprland-uwsm";
  };

  # SDDM Catppuccin theme package.
  environment.systemPackages = [
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      font   = "JetBrainsMono Nerd Font";
    })
  ];
}
