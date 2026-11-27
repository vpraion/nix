#!/usr/bin/env bash
# Launches Steam in SteamOS Gaming Mode inside the active Gamescope session.

# Ensure system binaries (steam, steamos-session-select, gamemoderun, etc.) are reachable
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"
unset PROTON_ENABLE_WAYLAND WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE

exec steam -steamos3 -gamepadui
