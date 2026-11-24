{ ... }:

{
  # Dual-GPU PCIe Slot Priority:
  # The system houses both an AMD Radeon RX 6900 XT (PCIe slot 1, 0000:0d:00.0)
  # and an Nvidia GeForce GTX 1050 Ti (PCIe slot 2, 0000:0e:00.0).
  # This udev rule enforces the RX 6900 XT as the primary boot_vga device for KMS and Wayland compositors.
  services.udev.extraRules = ''
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="0000:0d:00.0", TAG+="boot_vga"
  '';
}
