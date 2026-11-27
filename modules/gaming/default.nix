# =============================================================================
# Gaming & Hybrid Desktop / TV Mode Subsystem
# Aggregates Steam/GameMode, Gamescope TV session, and seamless SDDM switching.
# =============================================================================

{ ... }:

{
  imports = [
    ./steam.nix
    ./tv-mode.nix
    ./session-switch.nix
  ];
}
