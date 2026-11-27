# =============================================================================
# Steam, Gamescope & GameMode Core Configuration
# =============================================================================

{ pkgs, ... }:

{
  # Steam client configuration.
  programs.steam = {
    enable = true;

    # Open firewall ports for local Steam Remote Play streaming.
    remotePlay.openFirewall = true;

    # Disabled in favor of our full SteamOS-like systemd session in ./tv-mode.nix
    # to avoid duplicate SDDM Wayland session entries.
    gamescopeSession.enable = false;

    # Valve Proton compatibility layers.
    # proton-ge-bin provides native Wayland support and HDR video color pipelines.
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Gamescope micro-compositor with CAP_SYS_NICE wrapper (/run/wrappers/bin/gamescope)
  # for low-latency frame pacing in TV mode and nested desktop gaming.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Feral Interactive GameMode daemon for dynamic CPU governor and process renice during gameplay.
  programs.gamemode.enable = true;

  # Performance overlay & Gamescope QAM integration (provides mangoapp).
  environment.systemPackages = with pkgs; [
    mangohud
  ];
}
