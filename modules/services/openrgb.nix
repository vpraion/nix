{ pkgs, ... }:

{
  # OpenRGB hardware lighting controller.
  services.hardware.openrgb = {
    enable      = true;
    package     = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
  };

  # Direct systemd bind-mount:
  # Overrides the upstream /var/lib/OpenRGB state path to point directly to
  # the Git-tracked user dotfiles at ~/.config/OpenRGB.
  # This enables the system-level daemon to load user lighting profiles on boot
  # and auto-restore profiles upon suspend/resume.
  systemd.services.openrgb = {
    serviceConfig = {
      BindPaths = [
        "/home/vini/.config/OpenRGB:/var/lib/OpenRGB"
      ];
    };
  };

  # Expose I2C / SMBus devnodes to userspace for RAM / motherboard RGB without root.
  hardware.i2c.enable = true;
}
