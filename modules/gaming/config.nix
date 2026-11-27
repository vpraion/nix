# =============================================================================
# Centralized Hardware & Session Identifiers for Hybrid Desktop / TV Mode
# Single source of truth consumed by tv-session.nix, session-switch.nix, audio.nix.
# =============================================================================

{
  user = "vini";

  sessions = {
    desktop = "hyprland-uwsm";
    tv      = "gamescope-session";
  };

  sddmSwitchConf = "/etc/sddm.conf.d/zz-session-switch.conf";

  tv = {
    connector = "HDMI-A-2";
    width     = 3840;
    height    = 2160;
    refresh   = 120;
    edidName  = "HISENSE";
  };

  desktop = {
    connector = "DP-2";
    edidName  = "LC49G95T";
  };

  audio = {
    gpuCard      = "alsa_card.pci-0000_0d_00.1";
    gpuSinkMatch = "pci-0000_0d_00.1";
    soundbarSink = "iec958-stereo";
  };

  input = {
    # Wooting analog keyboard interface ignored as SDL/Steam gamepad
    ignoredControllers = "0x31e3/0x1320";
  };
}
