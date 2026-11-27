#!/usr/bin/env bash
# SDDM X11 greeter display setup (Xsetup).
# Restricts the login screen to the primary desktop DisplayPort monitor (DP-2)
# and turns off secondary/TV HDMI outputs so the greeter never spans onto the TV.

PRIMARY=""
for out in $(xrandr --query | awk '/ connected/ {print $1}'); do
  case "$out" in
    DP-2|DisplayPort-1)
      PRIMARY="$out"
      break
      ;;
  esac
done

if [[ -z "$PRIMARY" ]]; then
  PRIMARY="$(xrandr --query | awk '/ connected/ && $1 ~ /^(DP|DisplayPort)/ {print $1; exit}')"
fi

if [[ -n "$PRIMARY" ]]; then
  xrandr --output "$PRIMARY" --auto --primary
  for out in $(xrandr --query | awk '/ connected/ {print $1}'); do
    if [[ "$out" != "$PRIMARY" ]]; then
      xrandr --output "$out" --off
    fi
  done
fi
