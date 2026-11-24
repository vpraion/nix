{ config, ... }:

{
  # Gigabyte X570 AORUS Ultra Super I/O Motherboard Sensor Driver:
  # The motherboard utilizes dual ITE IT8688E chips (at I/O ports 0x0a40 and 0x0a60)
  # responsible for PWM fan speed control, tachometer readings, and thermal sensor probes.
  # Out-of-tree it87 kernel module package.
  boot.extraModulePackages = with config.boot.kernelPackages; [
    it87
  ];

  # Load it87 at boot.
  boot.kernelModules = [
    "it87"
  ];

  # Force chip ID recognition and bypass ACPI hardware resource conflicts.
  boot.extraModprobeConfig = ''
    options it87 ignore_resource_conflict=1 force_id=0x8688
  '';
}
