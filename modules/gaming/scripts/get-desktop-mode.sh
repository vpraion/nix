#!/usr/bin/env bash
# Exit 0 if Hyprland Desktop session is active (and not Gamescope TV), 1 otherwise.

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
