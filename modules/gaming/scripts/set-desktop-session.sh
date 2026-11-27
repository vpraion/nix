#!/usr/bin/env bash
# Switch from TV mode (Gamescope) back to Desktop mode (Hyprland + soundbar audio).

if ! systemctl --user is-active --quiet gamescope-session.target 2>/dev/null && \
   pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1; then
  echo "Already in Desktop mode (Hyprland). Restoring soundbar audio..."
  set-desktop-audio || true
  exit 0
fi

echo "Switching to Desktop mode (Hyprland)..."
exec systemctl start --no-block session-switch@hyprland-uwsm.service
