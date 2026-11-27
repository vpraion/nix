# =============================================================================
# TV Mode: SteamOS-Style Gamescope Systemd User Session
# Mirrors gamescope-session-cachyos declaratively for NixOS + SDDM:
# - Dedicated Wayland session (gamescope-session.desktop) on HDMI-A-2 (4K@120Hz HDR VRR)
# - Type=notify Gamescope service exporting %t/gamescope-environment
# - Steam (-steamos3 -gamepadui) kept alive via Upholds= (auto-restarts on crash)
# - MangoApp overlay bound to the Gamescope stats pipe
# - Strict environment isolation (unsets PROTON_ENABLE_WAYLAND / Hyprland vars)
# =============================================================================

{ pkgs, ... }:

let
  # ---------------------------------------------------------------------------
  # 1. Session Entrypoint (invoked by SDDM via gamescope-session.desktop)
  # ---------------------------------------------------------------------------
  startGamescopeSession = pkgs.writeShellApplication {
    name = "start-gamescope-session";
    runtimeInputs = with pkgs; [
      systemd
      dbus
      gnugrep
      coreutils
      util-linux
    ];
    text = ''
      # Clean up any leftovers from an abruptly terminated previous session
      systemctl --user stop gamescope-session.target || true
      systemctl --user stop graphical-session-pre.target || true
      systemctl --user reset-failed || true

      # Propagate DESKTOP_SESSION and XDG_* variables to systemd user manager
      mapfile -t xdg_vars < <(env | grep '^XDG_' | cut -d= -f1 || true)
      dbus-update-activation-environment --systemd DESKTOP_SESSION "''${xdg_vars[@]}"

      # Prevent desktop xdg-desktop-portal backends (hyprland/gtk) from interfering in TV mode
      systemctl --user set-environment XDG_DESKTOP_PORTAL_DIR=""

      cleanup() {
        systemctl --user stop gamescope-session.target || true
        systemctl --user unset-environment XDG_DESKTOP_PORTAL_DIR || true
      }
      trap cleanup HUP INT TERM

      # Launch Gamescope session target and block until it stops
      systemctl --user --wait start gamescope-session.target &
      wait || true

      logger "Gamescope Session Ended - Performing Final Cleanup"
      systemctl --user stop graphical-session-pre.target || true
      systemctl --user unset-environment XDG_DESKTOP_PORTAL_DIR || true
      logger "Gamescope Session Ended - Cleanup Complete"
    '';
  };

  # ---------------------------------------------------------------------------
  # 2. Gamescope Compositor Launcher (Type=notify systemd user service)
  # ---------------------------------------------------------------------------
  gamescopeSessionScript = pkgs.writeShellApplication {
    name = "gamescope-session";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      gnugrep
      systemd
      gamescope
    ];
    text = ''
      # Strictly isolate TV mode from desktop Wayland / Hyprland variables
      unset PROTON_ENABLE_WAYLAND WAYLAND_DISPLAY DISPLAY XAUTHORITY HYPRLAND_INSTANCE_SIGNATURE

      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo >&2 "!! XDG_RUNTIME_DIR is not set; cannot create Gamescope sockets"
        exit 1
      fi

      tmpdir="$(mktemp -p "$XDG_RUNTIME_DIR" -d -t gamescope.XXXXXXX)"
      socket="$tmpdir/startup.socket"
      stats="$tmpdir/stats.pipe"

      # -----------------------------------------------------------------------
      # SteamOS / Gamescope Session Globals
      # -----------------------------------------------------------------------
      export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0

      # Ignore Wooting keyboard analog interface as a Steam/SDL gamepad
      export SDL_GAMECONTROLLER_IGNORE_DEVICES="0x31e3/0x1320"

      # MangoApp overlay integration with Steam Quick Access Menu
      export STEAM_MANGOAPP_PRESETS_SUPPORTED=1
      export STEAM_USE_MANGOAPP=1
      export STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND=1
      export STEAM_MANGOAPP_HORIZONTAL_SUPPORTED=1
      export MANGOHUD_CONFIGFILE="$tmpdir/mangohud.config"
      echo "no_display" > "$MANGOHUD_CONFIGFILE"

      # Dynamic VRS (Mesa RADV)
      export STEAM_USE_DYNAMIC_VRS=1
      RADV_FORCE_VRS_CONFIG_FILE="$(mktemp /tmp/radv_vrs.XXXXXXXX)"
      export RADV_FORCE_VRS_CONFIG_FILE
      echo "1x1" > "$RADV_FORCE_VRS_CONFIG_FILE"

      # Persistent Gamescope display modes & patched EDID paths
      export GAMESCOPE_MODE_SAVE_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/modes.cfg"
      export GAMESCOPE_PATCHED_EDID_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/edid.bin"
      mkdir -p "$(dirname "$GAMESCOPE_MODE_SAVE_FILE")"
      touch "$GAMESCOPE_MODE_SAVE_FILE" "$GAMESCOPE_PATCHED_EDID_FILE"

      # Color management, HDR, VRR, Tearing & Scaling capabilities in Steam UI
      export GAMESCOPE_NV12_COLORSPACE=k_EStreamColorspace_BT601
      export STEAM_GAMESCOPE_HDR_SUPPORTED=1
      export STEAM_GAMESCOPE_FORCE_HDR_DEFAULT=1
      export STEAM_GAMESCOPE_COLOR_MANAGED=1
      export STEAM_GAMESCOPE_VIRTUAL_WHITE=1
      export STEAM_GAMESCOPE_VRR_SUPPORTED=1
      export STEAM_GAMESCOPE_HAS_TEARING_SUPPORT=1
      export STEAM_GAMESCOPE_TEARING_SUPPORTED=1
      export STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1
      export STEAM_GAMESCOPE_NIS_SUPPORTED=1
      export STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT=1
      export STEAM_GAMESCOPE_DYNAMIC_REFRESH_IN_STEAM_SUPPORTED=0
      export ENABLE_GAMESCOPE_WSI=1

      # Frame pacing, XWayland isolation & Steam runtime tuning
      export VKD3D_SWAPCHAIN_LATENCY_FRAMES=3
      export WINEDLLOVERRIDES="dxgi=n"
      export STEAM_MULTIPLE_XWAYLANDS=1
      export STEAM_LAUNCH_WRAPPER_SCOPE=1
      export STEAM_ENABLE_VOLUME_HANDLER=1
      export SRT_URLOPEN_PREFER_STEAM=1
      export STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
      export STEAM_ENABLE_CEC=0
      export vk_xwayland_wait_ready=false
      export GAMESCOPE_DISABLE_ASYNC_FLIPS=1
      GAMESCOPE_LIMITER_FILE="$(mktemp /tmp/gamescope-limiter.XXXXXXXX)"
      export GAMESCOPE_LIMITER_FILE

      ulimit -n 524288 || true

      # Setup Gamescope startup/stats FIFOs and claim global stats symlink
      export GAMESCOPE_STATS="$stats"
      mkfifo -- "$stats"
      mkfifo -- "$socket"

      sessionlink="$XDG_RUNTIME_DIR/gamescope-stats"
      lockfile="$sessionlink.lck"
      exec 9>"$lockfile"
      if flock -n 9 && rm -f "$sessionlink" && ln -sf "$tmpdir" "$sessionlink"; then
        echo >&2 "Claimed global gamescope stats session at \"$sessionlink\""
      else
        echo >&2 "!! Failed to claim global gamescope stats session"
      fi

      # Wait for Gamescope to report its XWayland & Wayland displays, export env, then notify systemd
      read_gamescope_env() {
        if read -r -t 10 response_x_display response_wl_display <> "$socket"; then
          export DISPLAY="$response_x_display"
          export GAMESCOPE_WAYLAND_DISPLAY="$response_wl_display"

          # Write clean single-line KEY=VALUE environment for Steam & MangoApp
          env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' > "$XDG_RUNTIME_DIR/gamescope-environment"
          systemd-notify --ready
        else
          echo >&2 "!! Timed out waiting for Gamescope startup socket"
        fi
      }

      read_gamescope_env &

      # Prefer the CAP_SYS_NICE NixOS wrapper when available
      GAMESCOPE_BIN="${pkgs.gamescope}/bin/gamescope"
      if [[ -x /run/wrappers/bin/gamescope ]]; then
        GAMESCOPE_BIN="/run/wrappers/bin/gamescope"
      fi

      exec "$GAMESCOPE_BIN" \
        --backend drm \
        --hdr-enabled \
        --adaptive-sync \
        -w 3840 -h 2160 \
        -W 3840 -H 2160 -r 120 \
        --generate-drm-mode fixed \
        --xwayland-count 2 \
        --default-touch-mode 4 \
        --hide-cursor-delay 3000 \
        --max-scale 2 \
        --fade-out-duration 200 \
        -e -R "$socket" -T "$stats" \
        -O HDMI-A-2
    '';
  };

  # ---------------------------------------------------------------------------
  # 3. Steam Gaming Mode Launcher
  # ---------------------------------------------------------------------------
  steamLauncherScript = pkgs.writeShellApplication {
    name = "steam-launcher";
    text = ''
      # Ensure system binaries (steam, steamos-session-select, gamemoderun, etc.) are reachable
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"
      unset PROTON_ENABLE_WAYLAND WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE

      exec steam -steamos3 -gamepadui
    '';
  };

  # ---------------------------------------------------------------------------
  # 4. SDDM Wayland Session Desktop Entry
  # ---------------------------------------------------------------------------
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
  # Register gamescope-session.desktop with SDDM
  services.displayManager.sessionPackages = [ gamescopeSessionPkg ];

  # Expose session launcher helper in PATH for diagnostics
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
      # Automatically relaunches Steam if it crashes while TV mode stays active,
      # but does NOT restart it when gamescope-session.target is intentionally stopped.
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
      # Forward SIGTERM to Steam's child process cleanly
      ExecStop = "${pkgs.bash}/bin/bash -c 'kill -TERM $(${pkgs.procps}/bin/pgrep -P $MAINPID || echo $MAINPID) 2>/dev/null || true'";
      KillSignal = "SIGCONT";
      KillMode = "mixed";
      # Explicit crash recovery (works hand-in-hand with Upholds= on gamescope-session.target)
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
