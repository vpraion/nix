#!/usr/bin/env bash
# Exit 0 if Gamescope TV session is active, 1 otherwise.

if systemctl --user is-active --quiet gamescope-session.target 2>/dev/null || \
   systemctl --user is-active --quiet gamescope-session.service 2>/dev/null; then
  echo "TV mode active (Gamescope Session)"
  exit 0
fi

echo "TV mode inactive"
exit 1
