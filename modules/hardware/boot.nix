{ pkgs, inputs, ... }:

{
  # Systemd-boot EFI bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Track the testing kernel (Linux 7.4-rc) for native AMDGPU HDMI 2.1 FRL, HDMI VRR/FreeSync, and ALLM.
  # Switch back to pkgs.linuxPackages_latest once Linux 7.4 stable lands in nixos-unstable.
  boot.kernelPackages = pkgs.linuxPackages_testing;

  # Disable automatic zstd firmware compression to allow raw binary firmware loading.
  hardware.firmwareCompression = "none";

  # Inject custom EDID firmware for the Samsung Odyssey G9 monitor.
  # This resolves display flickering and enables full 5120x1440 @ 240Hz, 10-bit HDR, and FreeSync/VRR.
  hardware.firmware = [
    (pkgs.linkFarm "g9-edid" [
      {
        name = "lib/firmware/edid/LC49G95.bin";
        path = "${inputs.g9-edid}/edids/LC49G95.bin";
      }
    ])
  ];

  # Kernel boot parameters:
  # - drm.edid_firmware: Forces the injected G9 EDID onto the primary DisplayPort-2 output.
  # - acpi_enforce_resources=lax: Allows the it87 hardware monitoring driver to access dual Super I/O chips
  #   despite motherboard ACPI DSDT resource reservation conflicts.
  boot.kernelParams = [
    "drm.edid_firmware=DP-2:edid/LC49G95.bin"
    "acpi_enforce_resources=lax"
  ];
}
