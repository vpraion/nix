{ pkgs, ... }:

{
  # =========================================================================
  # 1. Physical Hard Drive Mounts
  # =========================================================================

  fileSystems."/mnt/disks/hdd-1" = {
    device = "/dev/disk/by-uuid/36eca03d-b304-4d80-8cbc-82aa92ddc0fe";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/mnt/disks/hdd-2" = {
    device = "/dev/disk/by-uuid/cda2c106-9904-419f-b1ad-93f5099273e3";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/mnt/disks/hdd-3" = {
    device = "/dev/disk/by-uuid/98bc5e11-b720-48eb-a871-7f976c5e03ec";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # =========================================================================
  # 2. Virtual Merged Media Pool (MergerFS)
  # =========================================================================

  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  # Unifies /mnt/disks/hdd-*/media into a single virtual directory at /srv/media.
  fileSystems."/srv/media" = {
    fsType = "fuse.mergerfs";
    device = "/mnt/disks/hdd-*/media";
    options = [
      "defaults"
      "allow_other"             # Allow non-root users (vini, Jellyfin, Docker) to read and write
      "umask=0002"              # Standard 0775 for directories and 0664 for files
      "use_ino"                 # Generates stable persistent inodes (required for media hardlinks & databases)
      "cache.files=partial"     # Intelligent page cache for high-throughput video streaming
      "dropcacheonclose=true"   # Releases RAM cache as soon as media playback finishes
      "category.create=epmfs"   # Existing Path, Most Free Space (keeps TV seasons grouped on one disk)
      "minfreespace=20G"        # Disk threshold before spilling over to another drive
      "moveonenospc=true"       # Dynamically moves in-progress writes to another disk if a drive fills up
      "fsname=mergerfs-media"   # Clean identifier in 'df -h'
      "x-systemd.requires-mounts-for=/mnt/disks" # Ensures underlying physical drives are ready first
      "nofail"                  # Prevents system lockup if one physical disk is disconnected
    ];
  };

  # =========================================================================
  # 3. Declarative Directory Structure & Permissions
  # =========================================================================

  systemd.tmpfiles.rules = [
    # Physical mount base folder
    "d /mnt/disks 0755 root root -"

    # Service data mount target
    "d /srv/media 0775 vini users -"
  ];
}
