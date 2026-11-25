{ pkgs, ... }:

let
  serviceDir = "/home/vini/services/arrmada";
  httpsUrl   = "https://github.com/vpraion/arrmada.git";
  sshUrl     = "git@github.com:vpraion/arrmada.git";

  arrmadaStart = pkgs.writeShellApplication {
    name = "arrmada-start";
    runtimeInputs = with pkgs; [ git docker-compose ];
    text = ''
      # Bootstrap the repo on first run via HTTPS (no SSH key needed at boot),
      # then switch origin to SSH so interactive edits can be pushed normally.
      if [ ! -d "${serviceDir}/.git" ]; then
        git clone "${httpsUrl}" "${serviceDir}"
        git -C "${serviceDir}" remote set-url origin "${sshUrl}"
      fi

      cd "${serviceDir}"
      exec docker-compose up -d --remove-orphans
    '';
  };

  arrmadaStop = pkgs.writeShellApplication {
    name = "arrmada-stop";
    runtimeInputs = with pkgs; [ docker-compose ];
    text = ''
      if [ -d "${serviceDir}" ]; then
        cd "${serviceDir}"
        exec docker-compose down
      fi
    '';
  };
in
{
  # Dedicated media group and isolated per-service users for Arrmada containers.
  users.groups.media.gid = 2000;

  users.users.jellyfin = {
    isSystemUser = true;
    uid          = 2001;
    group        = "media";
  };

  # Ensure ~/services exists with proper user ownership.
  systemd.tmpfiles.rules = [
    "d /home/vini/services 0755 vini users -"
  ];

  # Systemd lifecycle unit for the Arrmada Docker Compose stack.
  systemd.services.arrmada = {
    description     = "Arrmada Docker Compose Stack";
    after           = [ "docker.service" "network-online.target" ];
    requires        = [ "docker.service" ];
    wants           = [ "network-online.target" ];
    wantedBy        = [ "multi-user.target" ];
    reloadIfChanged = true;

    # Wait for the MergerFS media pool before starting containers.
    unitConfig.RequiresMountsFor = [ "/srv/media" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      User            = "vini";
      Group           = "users";
      ExecStart       = "${arrmadaStart}/bin/arrmada-start";
      ExecReload      = "${arrmadaStart}/bin/arrmada-start";
      ExecStop        = "${arrmadaStop}/bin/arrmada-stop";
    };
  };
}
