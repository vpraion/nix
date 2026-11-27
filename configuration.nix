# =============================================================================
# NixOS Desktop Configuration
# Master configuration entrypoint importing modular subsystem definitions.
# =============================================================================

{ ... }:

{
  imports = [
    # Hardware scan results (disk partitions, filesystems, CPU microcode)
    ./hardware-configuration.nix

    # Core system foundation
    ./modules/core/nix.nix
    ./modules/core/locale.nix
    ./modules/core/users.nix
    ./modules/core/network.nix

    # Physical machine & device drivers
    ./modules/hardware/boot.nix
    ./modules/hardware/gpu.nix
    ./modules/hardware/sensors.nix
    ./modules/hardware/storage.nix

    # Desktop environment & multimedia
    ./modules/desktop/hyprland.nix
    ./modules/desktop/sddm.nix
    ./modules/desktop/audio.nix

    # System services & daemons
    ./modules/services/docker.nix
    ./modules/services/openrgb.nix
    ./modules/services/arrmada.nix

    # Gaming & Hybrid Desktop / TV Mode
    ./modules/gaming

    # Applications
    ./modules/programs/firefox.nix
    ./modules/programs/antigravity-cli.nix
    ./modules/programs/sidra.nix
  ];
}
