# =============================================================================
# Gaming & Hybrid Desktop / TV Mode Subsystem
# Aggregates Steam/GameMode, Gamescope TV session, SDDM switching, and audio.
# =============================================================================

{ ... }:

{
  imports = [
    ./steam.nix
    ./tv-session.nix
    ./session-switch.nix
    ./audio.nix
  ];
}
