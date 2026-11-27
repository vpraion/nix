#!/usr/bin/env bash
# Entrypoint invoked by SDDM (gamescope-session.desktop).
# Starts the systemd user gamescope-session.target and waits until it exits.

# Clean up any leftovers from an abruptly terminated previous session
systemctl --user stop gamescope-session.target || true
systemctl --user stop graphical-session-pre.target || true
systemctl --user reset-failed || true

# Propagate DESKTOP_SESSION and XDG_* variables to systemd user manager
mapfile -t xdg_vars < <(env | grep '^XDG_' | cut -d= -f1 || true)
dbus-update-activation-environment --systemd DESKTOP_SESSION "${xdg_vars[@]}"

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
