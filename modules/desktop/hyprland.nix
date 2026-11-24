{ ... }:

{
  # Hyprland Wayland compositor.
  programs.hyprland = {
    enable = true;

    # Wrap Hyprland in Universal Wayland Session Manager (UWSM)
    # for strict systemd cgroup session tracking, cleaner shutdown, and env propagation.
    withUWSM = true;

    # XWayland compatibility layer for legacy X11 applications (Steam, older games).
    xwayland.enable = true;
  };
}
