# =============================================================================
# Seamless Desktop (Hyprland) <-> TV (Gamescope) Session Switching & Audio
# - NO autologin on cold boot (normal SDDM login screen)
# - Passwordless one-shot autologin ONLY during explicit session switches
# - Automatic PipeWire audio routing:
#     * TV mode      -> *hdmi-stereo (waits for HDMI-A-2 init by Gamescope/Steam)
#     * Desktop mode -> *iec958-stereo (soundbar)
# =============================================================================

{ pkgs, ... }:

let
  targetUser = "vini";
  sddmSwitchConf = "/etc/sddm.conf.d/zz-session-switch.conf";

  # ---------------------------------------------------------------------------
  # 1. Audio Routing Scripts (100% Native PipeWire / WirePlumber: pw-dump + wpctl)
  # ---------------------------------------------------------------------------
  setDesktopAudio = pkgs.writeShellApplication {
    name = "set-desktop-audio";
    runtimeInputs = with pkgs; [
      pipewire
      wireplumber
      python3Minimal
      coreutils
    ];
    text = ''
      # Wait up to 5s for PipeWire to expose the soundbar Audio/Sink (*iec958-stereo)
      SINK_ID=""
      SINK_NAME=""
      for _ in $(seq 1 10); do
        read -r SINK_ID SINK_NAME < <(
          pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for obj in data:
    props = (obj.get("info") or {}).get("props") or {}
    if props.get("media.class") == "Audio/Sink":
        name = props.get("node.name") or ""
        if "iec958-stereo" in name:
            print(obj["id"], name)
            break
' || true
        ) || true
        if [[ -n "$SINK_ID" ]]; then
          break
        fi
        sleep 0.5
      done

      if [[ -z "$SINK_ID" ]]; then
        echo "Error: Soundbar (*iec958-stereo) not found in PipeWire." >&2
        exit 1
      fi

      wpctl set-default "$SINK_ID"
      echo "Audio set to soundbar: $SINK_NAME (id $SINK_ID)"
    '';
  };

  setTvAudio = pkgs.writeShellApplication {
    name = "set-tv-audio";
    runtimeInputs = with pkgs; [
      pipewire
      wireplumber
      python3Minimal
      gawk
      gnugrep
      coreutils
    ];
    text = ''
      # 1. Wait up to 25s for the TV (HDMI-A-2 / non-G9 display) to present a valid ALSA HDMI ELD.
      #    This prevents grabbing the Odyssey G9 (LC49G95T) DisplayPort audio sink prematurely.
      TV_ELD=""
      for _ in $(seq 1 50); do
        for eld in /proc/asound/card*/eld*; do
          [[ -r "$eld" ]] || continue
          if grep -qE '^monitor_present[[:space:]]+1$' "$eld" 2>/dev/null && \
             grep -qE '^eld_valid[[:space:]]+1$' "$eld" 2>/dev/null; then
            mon_name=$(awk '/^monitor_name/ { $1=""; sub(/^[[:space:]]+/, ""); print }' "$eld" 2>/dev/null || true)
            if [[ -n "$mon_name" && "$mon_name" != *"LC49G95T"* ]]; then
              TV_ELD="$eld ($mon_name)"
              break
            fi
          fi
        done
        [[ -n "$TV_ELD" ]] && break
        sleep 0.5
      done

      if [[ -n "$TV_ELD" ]]; then
        echo "Detected TV HDMI ELD: $TV_ELD"
      else
        echo "Warning: Timed out waiting for TV ELD; attempting PipeWire HDMI card detection anyway." >&2
      fi

      # 2. Switch the AMD GPU audio device (alsa_card.pci-0000_0d_00.1) to the available TV HDMI
      #    stereo profile via WirePlumber (wpctl set-profile), since WirePlumber may stay on the
      #    Odyssey G9 DP profile (output:hdmi-stereo).
      DEV_ID=""
      CUR_PROF=""
      TARGET_PROF=""
      TARGET_PROF_NAME=""
      read -r DEV_ID CUR_PROF TARGET_PROF TARGET_PROF_NAME < <(
        pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

def parse_route_info(info):
    res = {}
    if isinstance(info, list) and len(info) > 1:
        items = info[1:]
        for i in range(0, len(items) - 1, 2):
            res[str(items[i])] = str(items[i + 1])
    return res

card = None
for obj in data:
    props = (obj.get("info") or {}).get("props") or {}
    if props.get("device.name") == "alsa_card.pci-0000_0d_00.1":
        card = obj
        break
if not card:
    sys.exit(0)

params = (card.get("info") or {}).get("params") or {}
cur_profiles = params.get("Profile") or []
cur_idx = cur_profiles[0].get("index", -1) if cur_profiles else -1

enum_profiles = {p["index"]: p for p in (params.get("EnumProfile") or []) if "index" in p}
enum_routes = params.get("EnumRoute") or []

candidates = []
for r in enum_routes:
    if r.get("direction") != "Output" or r.get("available") != "yes":
        continue
    rinfo = parse_route_info(r.get("info"))
    prod = rinfo.get("device.product.name", "")
    # Rank: 0 = explicit HISENSE, 1 = any non-G9 available HDMI output, 2 = fallback available HDMI
    if "hisense" in prod.lower():
        rank = 0
    elif "lc49g95t" not in prod.lower():
        rank = 1
    else:
        rank = 2
    for pidx in r.get("profiles") or []:
        prof = enum_profiles.get(pidx)
        if prof and (prof.get("name") or "").startswith("output:hdmi-stereo"):
            candidates.append((rank, pidx, prof["name"]))
            break

if candidates:
    candidates.sort(key=lambda x: x[0])
    _, target_idx, target_name = candidates[0]
    print(card["id"], cur_idx, target_idx, target_name)
' || true
      ) || true

      if [[ -n "$DEV_ID" && -n "$TARGET_PROF" && "$TARGET_PROF" != "$CUR_PROF" ]]; then
        echo "Switching GPU audio device $DEV_ID to profile $TARGET_PROF ($TARGET_PROF_NAME)"
        wpctl set-profile "$DEV_ID" "$TARGET_PROF"
        sleep 0.5
      fi

      apply_tv_sink() {
        local sink_id=""
        local sink_name=""
        for _ in $(seq 1 20); do
          read -r sink_id sink_name < <(
            pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
primary = None
fallback = None
for obj in data:
    props = (obj.get("info") or {}).get("props") or {}
    if props.get("media.class") == "Audio/Sink":
        name = props.get("node.name") or ""
        if "pci-0000_0d_00.1" in name and "hdmi-stereo" in name:
            primary = (obj["id"], name)
            break
        elif "hdmi-stereo" in name and fallback is None:
            fallback = (obj["id"], name)
chosen = primary or fallback
if chosen:
    print(chosen[0], chosen[1])
' || true
          ) || true
          [[ -n "$sink_id" ]] && break
          sleep 0.5
        done

        if [[ -z "$sink_id" ]]; then
          echo "Error: TV audio output (*hdmi-stereo) not found in PipeWire." >&2
          return 1
        fi

        wpctl set-default "$sink_id"
        echo "Audio set to TV: $sink_name (id $sink_id)"
      }

      apply_tv_sink

      # 3. Re-assert default sink once Steam UI finishes initializing
      sleep 4
      apply_tv_sink || true
    '';
  };

  # ---------------------------------------------------------------------------
  # 2. Privileged Root Helper (runs inside session-switch@.service)
  # Survives graphical session teardown cleanly without race conditions.
  # ---------------------------------------------------------------------------
  sessionSwitchHelper = pkgs.writeShellApplication {
    name = "session-switch-helper";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      util-linux
      procps
    ];
    text = ''
      TARGET_SESSION="''${1:-}"
      case "$TARGET_SESSION" in
        gamescope-session|hyprland-uwsm) ;;
        *)
          echo "Error: Unsupported target session '$TARGET_SESSION'" >&2
          exit 1
          ;;
      esac

      USER_UID="$(id -u "${targetUser}")"
      RUNTIME_DIR="/run/user/$USER_UID"
      USER_ENV=(
        "XDG_RUNTIME_DIR=$RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"
        "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${targetUser}/bin"
      )

      run_as_user() {
        runuser -u "${targetUser}" -- env "''${USER_ENV[@]}" "$@"
      }

      # 1. Gracefully tear down the currently active graphical session
      if [[ "$TARGET_SESSION" == "gamescope-session" ]]; then
        # Leaving Desktop (Hyprland / UWSM) -> cleanly close Hyprland and its child apps
        if run_as_user systemctl --user is-active --quiet graphical-session.target 2>/dev/null; then
          run_as_user uwsm stop 2>/dev/null || true
          for _ in $(seq 1 25); do
            if ! pgrep -u "${targetUser}" -x Hyprland >/dev/null 2>&1; then
              break
            fi
            sleep 0.2
          done
        fi
      else
        # Leaving TV (Gamescope) -> gracefully shut down Steam, then stop gamescope-session.target
        if run_as_user systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
          run_as_user steam -shutdown 2>/dev/null || true
          sleep 1
          run_as_user systemctl --user stop gamescope-session.target 2>/dev/null || true
          for _ in $(seq 1 40); do
            if ! run_as_user systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
              break
            fi
            sleep 0.2
          done
        fi
      fi

      # 2. Write one-shot SDDM autologin drop-in (Relogin=false prevents loops on manual logout)
      mkdir -p "$(dirname "${sddmSwitchConf}")"
      cat <<EOF > "${sddmSwitchConf}"
      [Autologin]
      User=${targetUser}
      Session=''${TARGET_SESSION}.desktop
      Relogin=false
      EOF

      # 3. Restart SDDM so it picks up the one-shot autologin drop-in immediately
      systemctl restart display-manager.service
    '';
  };

  # ---------------------------------------------------------------------------
  # 3. User-Facing Mode Detection & Switching CLI Tools
  # ---------------------------------------------------------------------------
  getTvMode = pkgs.writeShellApplication {
    name = "get-tv-mode";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      if systemctl --user is-active --quiet gamescope-session.target 2>/dev/null || \
         systemctl --user is-active --quiet gamescope-session.service 2>/dev/null; then
        echo "TV mode active (Gamescope Session)"
        exit 0
      fi
      echo "TV mode inactive"
      exit 1
    '';
  };

  getDesktopMode = pkgs.writeShellApplication {
    name = "get-desktop-mode";
    runtimeInputs = with pkgs; [ systemd procps ];
    text = ''
      if systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
        echo "Desktop mode inactive (Gamescope TV active)"
        exit 1
      fi
      if pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1; then
        echo "Desktop mode active (Hyprland)"
        exit 0
      fi
      echo "Desktop mode inactive"
      exit 1
    '';
  };

  setTvSession = pkgs.writeShellApplication {
    name = "set-tv-session";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      if systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
        echo "Already in TV mode (Gamescope)."
        exit 0
      fi
      echo "Switching to TV mode (Gamescope - HDMI-A-2)..."
      exec systemctl start --no-block session-switch@gamescope-session.service
    '';
  };

  setDesktopSession = pkgs.writeShellApplication {
    name = "set-desktop-session";
    runtimeInputs = with pkgs; [ systemd procps setDesktopAudio ];
    text = ''
      if ! systemctl --user is-active --quiet gamescope-session.target 2>/dev/null && \
         pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1; then
        echo "Already in Desktop mode (Hyprland). Restoring soundbar audio..."
        set-desktop-audio || true
        exit 0
      fi
      echo "Switching to Desktop mode (Hyprland)..."
      exec systemctl start --no-block session-switch@hyprland-uwsm.service
    '';
  };

  # Intercepts Steam's built-in "Switch to Desktop" Power menu action
  steamosSessionSelect = pkgs.writeShellApplication {
    name = "steamos-session-select";
    runtimeInputs = [ setDesktopSession setTvSession ];
    text = ''
      case "''${1:-plasma}" in
        plasma|desktop|hyprland|hyprland-uwsm|"")
          exec set-desktop-session
          ;;
        gamescope|gamescope-session|tv)
          exec set-tv-session
          ;;
        *)
          echo "Usage: steamos-session-select {desktop|plasma|gamescope|tv}" >&2
          exit 1
          ;;
      esac
    '';
  };

  # Convenience CLI aliases & desktop launchers
  sessionAliases = pkgs.runCommand "session-switch-aliases" {} ''
    mkdir -p "$out/bin" "$out/share/applications"

    ln -s ${setTvSession}/bin/set-tv-session "$out/bin/mode-tv"
    ln -s ${setTvSession}/bin/set-tv-session "$out/bin/switch-to-tv"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/mode-desktop"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/mode-bureau"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/switch-to-desktop"
    ln -s ${setDesktopAudio}/bin/set-desktop-audio "$out/bin/set-audio-soundbar"
    ln -s ${setTvAudio}/bin/set-tv-audio "$out/bin/set-audio-tv"

    cat <<EOF > "$out/share/applications/mode-tv.desktop"
    [Desktop Entry]
    Name=Mode TV (Steam)
    Comment=Basculer vers la session Steam Gaming Mode sur la TV (HDMI-A-2)
    Exec=${setTvSession}/bin/set-tv-session
    Icon=video-television
    Terminal=false
    Type=Application
    Categories=Game;
    EOF

    cat <<EOF > "$out/share/applications/mode-desktop.desktop"
    [Desktop Entry]
    Name=Mode Bureau (Hyprland)
    Comment=Basculer vers le bureau Hyprland
    Exec=${setDesktopSession}/bin/set-desktop-session
    Icon=video-display
    Terminal=false
    Type=Application
    Categories=System;
    EOF
  '';
in
{
  environment.systemPackages = [
    setDesktopAudio
    setTvAudio
    getTvMode
    getDesktopMode
    setTvSession
    setDesktopSession
    steamosSessionSelect
    sessionAliases
  ];

  # ---------------------------------------------------------------------------
  # Boot-time Safety: Always remove one-shot autologin drop-in on cold boot
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "R! ${sddmSwitchConf} - - - - -"
  ];

  # ---------------------------------------------------------------------------
  # System Services for Session Switching & Drop-in Cleanup
  # ---------------------------------------------------------------------------
  systemd.services."session-switch@" = {
    description = "Switch SDDM Graphical Session to %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sessionSwitchHelper}/bin/session-switch-helper %i";
    };
  };

  systemd.services.session-switch-cleanup = {
    description = "Remove Temporary SDDM One-Shot Autologin Drop-in";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/rm -f ${sddmSwitchConf}";
    };
  };

  # Allow wheel users to trigger ONLY these 3 session-switching units without password
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")) {
        var unit = action.lookup("unit");
        if (unit == "session-switch@gamescope-session.service" ||
            unit == "session-switch@hyprland-uwsm.service" ||
            unit == "session-switch-cleanup.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';

  # ---------------------------------------------------------------------------
  # Systemd User Hooks: Audio Routing & Temporary SDDM Drop-in Cleanup
  # ---------------------------------------------------------------------------

  # TV Audio: runs once Gamescope & Steam start initializing HDMI-A-2
  systemd.user.services.gamescope-audio-tv = {
    description = "Switch PipeWire Audio to TV (HDMI) in Gamescope Mode";
    after = [
      "gamescope-session.service"
      "steam-launcher.service"
      "pipewire-pulse.service"
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
      "pipewire-pulse.service"
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

  # Clean up temporary SDDM one-shot drop-in right after the target session starts
  systemd.user.services.sddm-switch-cleanup = {
    description = "Clean Up One-Shot SDDM Session Switch Config";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig = {
      ConditionPathExists = sddmSwitchConf;
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block session-switch-cleanup.service";
    };
  };
}
