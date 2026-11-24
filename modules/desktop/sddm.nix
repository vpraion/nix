{ pkgs, ... }:

{
  # X11 server required by SDDM display manager.
  services.xserver.enable = true;

  # Display Manager configuration.
  services.displayManager = {
    sddm = {
      enable  = true;
      theme   = "catppuccin-mocha-mauve";
      package = pkgs.kdePackages.sddm;
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
