#!/usr/bin/env bash
# Gamescope DRM compositor launcher (Type=notify systemd user service).
# Hardware parameters (TV_CONNECTOR, TV_WIDTH, TV_HEIGHT, TV_REFRESH, IGNORED_CONTROLLERS)
# are injected by gamescope-session.service from nix/modules/gaming/config.nix.

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  echo >&2 "!! XDG_RUNTIME_DIR is not set; cannot create Gamescope sockets"
  exit 1
fi

tmpdir="$(mktemp -p "$XDG_RUNTIME_DIR" -d -t gamescope.XXXXXXX)"
socket="$tmpdir/startup.socket"
stats="$tmpdir/stats.pipe"

# -----------------------------------------------------------------------------
# SteamOS / Gamescope Session Globals
# -----------------------------------------------------------------------------
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
export SDL_GAMECONTROLLER_IGNORE_DEVICES="${IGNORED_CONTROLLERS:-0x31e3/0x1320}"

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
export GAMESCOPE_MODE_SAVE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/modes.cfg"
export GAMESCOPE_PATCHED_EDID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/edid.bin"
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

    # Dump session variables for Steam & MangoApp without clobbering their PATH
    env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | grep -Ev '^(PATH|_)=' > "$XDG_RUNTIME_DIR/gamescope-environment"
    systemd-notify --ready
  else
    echo >&2 "!! Timed out waiting for Gamescope startup socket"
  fi
}

read_gamescope_env &

GAMESCOPE_BIN="$(command -v gamescope)"
if [[ -x /run/wrappers/bin/gamescope ]]; then
  GAMESCOPE_BIN="/run/wrappers/bin/gamescope"
fi

WIDTH="${TV_WIDTH:-3840}"
HEIGHT="${TV_HEIGHT:-2160}"
REFRESH="${TV_REFRESH:-120}"
CONNECTOR="${TV_CONNECTOR:-HDMI-A-2}"

exec "$GAMESCOPE_BIN" \
  --backend drm \
  --hdr-enabled \
  --adaptive-sync \
  -w "$WIDTH" -h "$HEIGHT" \
  -W "$WIDTH" -H "$HEIGHT" -r "$REFRESH" \
  --generate-drm-mode fixed \
  --xwayland-count 2 \
  --default-touch-mode 4 \
  --hide-cursor-delay 3000 \
  --max-scale 2 \
  --fade-out-duration 200 \
  -e -R "$socket" -T "$stats" \
  -O "$CONNECTOR"
