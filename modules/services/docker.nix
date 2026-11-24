{ pkgs, ... }:

{
  # Docker container runtime daemon.
  virtualisation.docker = {
    enable = true;

    # Weekly maintenance cleanup for unused container images and build caches.
    autoPrune = {
      enable = true;
      dates  = "weekly";
    };
  };

  # Docker Compose v2 CLI plugin.
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
