#!/usr/bin/env bash
# Switch from Desktop (Hyprland) to TV mode (Gamescope on HDMI-A-2).

if systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
  echo "Already in TV mode (Gamescope)."
  exit 0
fi

echo "Switching to TV mode (Gamescope - HDMI-A-2)..."
exec systemctl start --no-block session-switch@gamescope-session.service
