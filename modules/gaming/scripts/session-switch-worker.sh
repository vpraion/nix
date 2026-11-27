#!/usr/bin/env bash
# Privileged root worker executed inside session-switch@.service.
# Gracefully stops the outgoing graphical session, writes a one-shot SDDM
# autologin drop-in (Relogin=false), and restarts display-manager.service.

TARGET_SESSION="${1:-}"

if [[ "$TARGET_SESSION" != "$TV_SESSION_NAME" && "$TARGET_SESSION" != "$DESKTOP_SESSION_NAME" ]]; then
  echo "Error: Unsupported target session '$TARGET_SESSION'" >&2
  exit 1
fi

USER_UID="$(id -u "$TARGET_USER")"
RUNTIME_DIR="/run/user/$USER_UID"
USER_ENV=(
  "XDG_RUNTIME_DIR=$RUNTIME_DIR"
  "DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"
  "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$TARGET_USER/bin"
)

run_as_user() {
  runuser -u "$TARGET_USER" -- env "${USER_ENV[@]}" "$@"
}

is_tv_active() {
  run_as_user systemctl --user is-active --quiet gamescope-session.target 2>/dev/null || \
  run_as_user systemctl --user is-active --quiet gamescope-session.service 2>/dev/null
}

is_desktop_active() {
  ! is_tv_active && pgrep -u "$TARGET_USER" -x Hyprland >/dev/null 2>&1
}

# Guard against redundant switches if invoked directly via systemctl
if [[ "$TARGET_SESSION" == "$TV_SESSION_NAME" ]] && is_tv_active; then
  echo "Already in TV mode (Gamescope)."
  exit 0
fi
if [[ "$TARGET_SESSION" == "$DESKTOP_SESSION_NAME" ]] && is_desktop_active; then
  echo "Already in Desktop mode (Hyprland)."
  exit 0
fi

# 1. Gracefully tear down the currently active graphical session
if [[ "$TARGET_SESSION" == "$TV_SESSION_NAME" ]]; then
  # Leaving Desktop (Hyprland / UWSM) -> cleanly close Hyprland and its child apps
  if run_as_user systemctl --user is-active --quiet graphical-session.target 2>/dev/null; then
    run_as_user uwsm stop 2>/dev/null || true
    for _ in $(seq 1 25); do
      if ! pgrep -u "$TARGET_USER" -x Hyprland >/dev/null 2>&1; then
        break
      fi
      sleep 0.2
    done
  fi
else
  # Leaving TV (Gamescope) -> gracefully shut down Steam, then stop gamescope-session.target
  # and wait until gamescope-session.service fully releases DRM before restarting SDDM.
  if is_tv_active; then
    run_as_user steam -shutdown 2>/dev/null || true
    sleep 1
    run_as_user systemctl --user stop gamescope-session.target 2>/dev/null || true
    for _ in $(seq 1 40); do
      if ! run_as_user systemctl --user is-active --quiet gamescope-session.service 2>/dev/null; then
        break
      fi
      sleep 0.2
    done
  fi
fi

# 2. Write one-shot SDDM autologin drop-in (Relogin=false prevents loops on manual logout)
mkdir -p "$(dirname "$SDDM_SWITCH_CONF")"
cat <<EOF > "$SDDM_SWITCH_CONF"
[Autologin]
User=${TARGET_USER}
Session=${TARGET_SESSION}.desktop
Relogin=false
EOF

# 3. Restart SDDM so it picks up the one-shot autologin drop-in immediately
systemctl restart display-manager.service
