# =============================================================================
# Automatic PipeWire / WirePlumber Audio Routing (Desktop Soundbar <-> TV HDMI)
# Unified Python tool (audio-switch {tv|desktop}), 100% native PipeWire.
# =============================================================================

{ lib, pkgs, ... }:

let
  cfg = import ./config.nix;

  audioSwitch = pkgs.runCommand "audio-switch" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    buildInputs = [ pkgs.python3Minimal ];
  } ''
    install -Dm755 ${./scripts/audio-switch.py} "$out/bin/audio-switch"
    patchShebangs "$out/bin/audio-switch"
    ${pkgs.python3Minimal}/bin/python3 -m py_compile "$out/bin/audio-switch"
    rm -rf "$out/bin/__pycache__"
    wrapProgram "$out/bin/audio-switch" \
      --prefix PATH : ${lib.makeBinPath (with pkgs; [ pipewire wireplumber ])} \
      --set-default GPU_AUDIO_CARD "${cfg.audio.gpuCard}" \
      --set-default GPU_SINK_MATCH "${cfg.audio.gpuSinkMatch}" \
      --set-default SOUNDBAR_SINK_MATCH "${cfg.audio.soundbarSink}" \
      --set-default DESKTOP_EDID_NAME "${cfg.desktop.edidName}" \
      --set-default TV_EDID_NAME "${cfg.tv.edidName}"
  '';
in
{
  # TV Audio: runs once Gamescope & Steam start initializing HDMI-A-2
  systemd.user.services.gamescope-audio-tv = {
    description = "Switch PipeWire Audio to TV (HDMI) in Gamescope Mode";
    after = [
      "gamescope-session.service"
      "steam-launcher.service"
      "pipewire.service"
      "wireplumber.service"
    ];
    partOf = [ "gamescope-session.target" ];
    wantedBy = [ "gamescope-session.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${audioSwitch}/bin/audio-switch tv";
    };
  };

  # Desktop Audio: restores soundbar whenever entering Hyprland desktop session
  systemd.user.services.desktop-audio-soundbar = {
    description = "Switch PipeWire Audio to Soundbar in Desktop Mode";
    after = [
      "graphical-session.target"
      "pipewire.service"
      "wireplumber.service"
    ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig = {
      ConditionPathExists = "!%t/gamescope-environment";
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${audioSwitch}/bin/audio-switch desktop";
    };
  };
}
