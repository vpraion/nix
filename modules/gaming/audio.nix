# =============================================================================
# Automatic PipeWire / WirePlumber Audio Routing (Desktop Soundbar <-> TV HDMI)
# 100% native PipeWire (pw-dump + wpctl), zero PulseAudio CLI dependency.
# =============================================================================

{ lib, pkgs, ... }:

let
  mkPythonApp = name: src: runtimeInputs:
    pkgs.runCommand name {
      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildInputs = [ pkgs.python3Minimal ];
    } ''
      install -Dm755 ${src} "$out/bin/${name}"
      patchShebangs "$out/bin/${name}"
      ${pkgs.python3Minimal}/bin/python3 -m py_compile "$out/bin/${name}"
      rm -rf "$out/bin/__pycache__"
      wrapProgram "$out/bin/${name}" \
        --prefix PATH : ${lib.makeBinPath runtimeInputs}
    '';

  pipewireTools = with pkgs; [
    pipewire
    wireplumber
  ];

  setDesktopAudio = mkPythonApp "set-desktop-audio" ./scripts/set-desktop-audio.py pipewireTools;
  setTvAudio = mkPythonApp "set-tv-audio" ./scripts/set-tv-audio.py pipewireTools;

  audioAliases = pkgs.runCommand "gaming-audio-aliases" {} ''
    mkdir -p "$out/bin"
    ln -s ${setDesktopAudio}/bin/set-desktop-audio "$out/bin/set-audio-soundbar"
    ln -s ${setTvAudio}/bin/set-tv-audio "$out/bin/set-audio-tv"
  '';
in
{
  environment.systemPackages = [
    setDesktopAudio
    setTvAudio
    audioAliases
  ];

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
      ExecStart = "${setTvAudio}/bin/set-tv-audio";
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
      # Never fire inside Gamescope TV session
      ConditionPathExists = "!%t/gamescope-environment";
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${setDesktopAudio}/bin/set-desktop-audio";
    };
  };
}
