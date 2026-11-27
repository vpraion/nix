# =============================================================================
# TV Mode: SteamOS-Style Gamescope Systemd User Session
# - Registers gamescope-session.desktop with SDDM (HDMI-A-2, 4K@120Hz HDR VRR)
# - Type=notify Gamescope compositor exporting %t/gamescope-environment
# - Steam (-steamos3 -gamepadui) kept alive via Upholds= (auto-restarts on crash)
# - MangoApp performance overlay bound to Gamescope stats pipe
# =============================================================================

{ lib, pkgs, ... }:

let
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

  steamLauncherScript = pkgs.writeShellApplication {
    name = "steam-launcher";
    text = readBash ./scripts/steam-launcher.sh;
  };

  gamescopeSessionPkg = pkgs.runCommand "gamescope-tv-session" {
    passthru.providedSessions = [ "gamescope-session" ];
  } ''
    mkdir -p "$out/share/wayland-sessions"
    cat <<EOF > "$out/share/wayland-sessions/gamescope-session.desktop"
    [Desktop Entry]
    Encoding=UTF-8
    Name=Gamescope TV (Steam)
    Comment=Steam Big Picture session on TV (HDMI-A-2)
    Exec=${startGamescopeSession}/bin/start-gamescope-session
    Icon=steam
    Type=Application
    DesktopNames=gamescope
    EOF
  '';
in
{
  services.displayManager.sessionPackages = [ gamescopeSessionPkg ];
  environment.systemPackages = [ startGamescopeSession ];

  # ---------------------------------------------------------------------------
  # Systemd User Target & Services (TV Mode)
  # ---------------------------------------------------------------------------
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
      # Auto-restarts Steam on crash while TV mode stays active,
      # without restarting it when gamescope-session.target is intentionally stopped.
      Upholds = "steam-launcher.service";
    };
  };

  systemd.user.services.gamescope-session = {
    description = "Gamescope TV Compositor (HDMI-A-2 4K@120Hz HDR VRR)";
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
        "TV_OUTPUT_CONNECTOR=HDMI-A-2"
      ];
      UnsetEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XAUTHORITY"
        "PROTON_ENABLE_WAYLAND"
        "HYPRLAND_INSTANCE_SIGNATURE"
      ];
      Slice = "session.slice";
    };
  };

  systemd.user.services.steam-launcher = {
    description = "Steam Gaming Mode Launcher";
    after = [
      "graphical-session.target"
      "xdg-desktop-portal.service"
    ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "exec";
      ExecStart = "${steamLauncherScript}/bin/steam-launcher";
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
