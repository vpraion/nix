#!/usr/bin/env bash
# Unified user CLI for checking and switching between Desktop (Hyprland) and TV (Gamescope) modes.
# Usage:
#   session-switch {tv|desktop|status}
#   steamos-session-select [plasma|desktop|gamescope|tv]

INVOKED_AS="$(basename "$0")"
if [[ "$INVOKED_AS" == "steamos-session-select" ]]; then
  case "${1:-plasma}" in
    gamescope|tv) ACTION="tv" ;;
    *)            ACTION="desktop" ;;
  esac
else
  ACTION="${1:-status}"
fi

TV_SESSION="${TV_SESSION_NAME:-gamescope-session}"
DESKTOP_SESSION="${DESKTOP_SESSION_NAME:-hyprland-uwsm}"

is_tv_active() {
  systemctl --user is-active --quiet gamescope-session.target 2>/dev/null || \
  systemctl --user is-active --quiet gamescope-session.service 2>/dev/null
}

is_desktop_active() {
  ! is_tv_active && pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1
}

case "$ACTION" in
  tv)
    if is_tv_active; then
      echo "Already in TV mode (Gamescope)."
      exit 0
    fi
    echo "Switching to TV mode (Gamescope)..."
    exec systemctl start --no-block "session-switch@${TV_SESSION}.service"
    ;;

  desktop)
    if is_desktop_active; then
      echo "Already in Desktop mode (Hyprland)."
      exit 0
    fi
    echo "Switching to Desktop mode (Hyprland)..."
    exec systemctl start --no-block "session-switch@${DESKTOP_SESSION}.service"
    ;;

  status)
    if is_tv_active; then
      echo "tv"
    elif is_desktop_active; then
      echo "desktop"
    else
      echo "inactive"
      exit 1
    fi
    ;;

  *)
    echo "Usage: session-switch {tv|desktop|status}" >&2
    exit 1
    ;;
esac
