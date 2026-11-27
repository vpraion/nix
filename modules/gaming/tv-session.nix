# =============================================================================
# TV Mode: SteamOS-Style Gamescope Systemd User Session
# - Registers gamescope-session.desktop with SDDM
# - Type=notify Gamescope compositor exporting %t/gamescope-environment
# - Steam (-steamos3 -gamepadui) kept alive via Upholds= (auto-restarts on crash)
# - Strict After=/Requires= ordering so Steam & MangoApp stop before Gamescope
# =============================================================================

{ config, lib, pkgs, ... }:

let
  cfg = import ./config.nix;
  readBash = file: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile file);

  startGamescopeSession = pkgs.writeShellApplication {
    name = "start-gamescope-session";
    runtimeInputs = with pkgs; [
      systemd
      dbus
      gnugrep
      coreutils
      util-linux
    ];
    text = readBash ./scripts/start-gamescope-session.sh;
  };

  gamescopeSessionScript = pkgs.writeShellApplication {
    name = "gamescope-session";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      gnugrep
      systemd
      gamescope
    ];
    text = readBash ./scripts/gamescope-session.sh;
  };

  gamescopeSessionPkg = pkgs.runCommand "gamescope-tv-session" {
    passthru.providedSessions = [ cfg.sessions.tv ];
  } ''
    mkdir -p "$out/share/wayland-sessions"
    cat <<EOF > "$out/share/wayland-sessions/${cfg.sessions.tv}.desktop"
    [Desktop Entry]
    Encoding=UTF-8
    Name=Gamescope TV (Steam)
    Comment=Steam Big Picture session on TV (${cfg.tv.connector})
    Exec=${startGamescopeSession}/bin/start-gamescope-session
    Icon=steam
    Type=Application
    DesktopNames=gamescope
    EOF
  '';
in
{
  services.displayManager.sessionPackages = [ gamescopeSessionPkg ];

  systemd.user.targets.gamescope-session = {
    description = "Gamescope TV Session";
    requires = [
      "graphical-session.target"
      "gamescope-session.service"
    ];
    bindsTo = [
      "graphical-session.target"
      "gamescope-session.service"
    ];
    after = [ "graphical-session.target" ];
    wants = [
      "gamescope-mangoapp.service"
      "gamescope-audio-tv.service"
      "sddm-switch-cleanup.service"
    ];
    unitConfig = {
      PropagatesStopTo = "graphical-session.target";
      Upholds = "steam-launcher.service";
    };
  };

  systemd.user.services.gamescope-session = {
    description = "Gamescope TV Compositor (${cfg.tv.connector} ${toString cfg.tv.width}x${toString cfg.tv.height}@${toString cfg.tv.refresh}Hz HDR VRR)";
    before = [
      "graphical-session.target"
      "xdg-desktop-portal.service"
    ];
    partOf = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
    unitConfig.RefuseManualStart = true;

    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      TimeoutStartSec = 15;
      TimeoutStopSec = 10;
      ExecStart = "${gamescopeSessionScript}/bin/gamescope-session";
      ExecStopPost = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/rm -rf \"$XDG_RUNTIME_DIR\"/gamescope{.,-}* \"$XDG_RUNTIME_DIR\"/gamescope-environment /tmp/gamescope-limiter* /tmp/radv_vrs.*'";
      Environment = [
        "SRT_LOG_TO_JOURNAL=1"
        "XDG_SESSION_TYPE=x11"
        "TV_CONNECTOR=${cfg.tv.connector}"
        "TV_WIDTH=${toString cfg.tv.width}"
        "TV_HEIGHT=${toString cfg.tv.height}"
        "TV_REFRESH=${toString cfg.tv.refresh}"
        "IGNORED_CONTROLLERS=${cfg.input.ignoredControllers}"
      ];
      UnsetEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XAUTHORITY"
      ];
      Slice = "session.slice";
    };
  };

  systemd.user.services.steam-launcher = {
    description = "Steam Gaming Mode";
    after = [
      "graphical-session.target"
      "xdg-desktop-portal.service"
    ];
    partOf = [ "graphical-session.target" ];
    path = [
      "/run/wrappers"
      "/run/current-system/sw"
      "/etc/profiles/per-user/${cfg.user}"
    ];

    serviceConfig = {
      Type = "exec";
      ExecStart = "${config.programs.steam.package}/bin/steam -steamos3 -gamepadui";
      ExecStop = "${pkgs.bash}/bin/bash -c 'kill -TERM $(${pkgs.procps}/bin/pgrep -P $MAINPID || echo $MAINPID) 2>/dev/null || true'";
      KillSignal = "SIGCONT";
      KillMode = "mixed";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 60;
      EnvironmentFile = "%t/gamescope-environment";
      Slice = "session.slice";
    };
  };

  systemd.user.services.gamescope-mangoapp = {
    description = "MangoApp Performance Overlay for Gamescope";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.mangohud}/bin/mangoapp";
      Restart = "always";
      RestartSec = 1;
      EnvironmentFile = "%t/gamescope-environment";
      TimeoutStopSec = 5;
      Slice = "session.slice";
    };
  };
}
