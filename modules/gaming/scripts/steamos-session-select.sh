#!/usr/bin/env bash
# Intercepts Steam Gaming Mode's built-in "Switch to Desktop" Power menu action.

case "${1:-plasma}" in
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
