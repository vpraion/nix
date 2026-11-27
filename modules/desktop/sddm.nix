{ pkgs, ... }:

{
  # X11 server required by SDDM display manager.
  services.xserver.enable = true;

  # Display Manager configuration.
  services.displayManager = {
    sddm = {
      enable  = true;
      theme   = "catppuccin-mocha-mauve";
      package = pkgs.kdePackages.sddm;

      # Restrict the X11 SDDM login greeter to the primary desktop monitor (DP-2)
      # and disable secondary/TV HDMI outputs so the greeter never spans onto the TV.
      setupScript = ''
        PRIMARY=""
        for out in $(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}'); do
          case "$out" in
            DP-2|DisplayPort-1)
              PRIMARY="$out"
              break
              ;;
          esac
        done
        if [ -z "$PRIMARY" ]; then
          PRIMARY=$(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gawk}/bin/awk '/ connected/ && $1 ~ /^(DP|DisplayPort)/ {print $1; exit}')
        fi
        if [ -n "$PRIMARY" ]; then
          ${pkgs.xrandr}/bin/xrandr --output "$PRIMARY" --auto --primary
          for out in $(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}'); do
            if [ "$out" != "$PRIMARY" ]; then
              ${pkgs.xrandr}/bin/xrandr --output "$out" --off
            fi
          done
        fi
      '';
    };

    # Launch into Hyprland wrapped with UWSM by default.
    defaultSession = "hyprland-uwsm";
  };

  # SDDM Catppuccin theme package.
  environment.systemPackages = [
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      font   = "JetBrainsMono Nerd Font";
    })
  ];
}
