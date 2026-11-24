{ pkgs, ... }:

{
  # Steam client configuration.
  programs.steam = {
    enable = true;

    # Open firewall ports for local Steam Remote Play streaming.
    remotePlay.openFirewall = true;

    # Enable Gamescope micro-compositor session for nested gaming.
    gamescopeSession.enable = true;

    # Valve Proton compatibility layers.
    # proton-ge-bin provides native Wayland support and HDR video color pipelines.
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Feral Interactive GameMode daemon for dynamic CPU governor and process renice during gameplay.
  programs.gamemode.enable = true;
}
