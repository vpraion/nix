# =============================================================================
# Seamless Desktop (Hyprland) <-> TV (Gamescope) SDDM Session Switching
# - NO autologin on cold boot (purged via systemd-tmpfiles + Relogin=false)
# - Passwordless one-shot autologin ONLY during explicit session switches
# - Single user CLI: session-switch {tv|desktop|status}
# =============================================================================

{ lib, pkgs, ... }:

let
  cfg = import ./config.nix;
  readBash = file: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile file);

  # Internal root worker (only invoked by systemd session-switch@.service, not in user PATH)
  sessionSwitchWorker = pkgs.writeShellApplication {
    name = "session-switch-worker";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      util-linux
      procps
    ];
    text = readBash ./scripts/session-switch-worker.sh;
  };

  # User-facing CLI: session-switch {tv|desktop|status}
  sessionSwitch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = with pkgs; [
      systemd
      procps
    ];
    runtimeEnv = {
      TV_SESSION_NAME = cfg.sessions.tv;
      DESKTOP_SESSION_NAME = cfg.sessions.desktop;
    };
    text = readBash ./scripts/session-switch.sh;
  };

  # Steam "Switch to Desktop" adapter & Rofi .desktop entries
  sessionIntegrations = pkgs.runCommand "session-switch-integrations" {} ''
    mkdir -p "$out/bin" "$out/share/applications"

    # Required in PATH for Steam Gaming Mode's native "Switch to Desktop" action
    ln -s ${sessionSwitch}/bin/session-switch "$out/bin/steamos-session-select"

    cat <<EOF > "$out/share/applications/session-switch-tv.desktop"
    [Desktop Entry]
    Name=TV Mode (Steam)
    Comment=Switch to Steam Gaming Mode on TV (${cfg.tv.connector})
    Exec=${sessionSwitch}/bin/session-switch tv
    Icon=video-television
    Terminal=false
    Type=Application
    Categories=Game;
    EOF

    cat <<EOF > "$out/share/applications/session-switch-desktop.desktop"
    [Desktop Entry]
    Name=Desktop Mode (Hyprland)
    Comment=Switch to Hyprland desktop
    Exec=${sessionSwitch}/bin/session-switch desktop
    Icon=video-display
    Terminal=false
    Type=Application
    Categories=System;
    EOF
  '';
in
{
  environment.systemPackages = [
    sessionSwitch
    sessionIntegrations
  ];

  # Boot-time safety: always remove one-shot autologin drop-in on cold boot
  systemd.tmpfiles.rules = [
    "R! ${cfg.sddmSwitchConf} - - - - -"
  ];

  # Root template service that survives graphical session teardown cleanly
  systemd.services."session-switch@" = {
    description = "Switch SDDM Graphical Session to %i";
    serviceConfig = {
      Type = "oneshot";
      Environment = [
        "TARGET_USER=${cfg.user}"
        "SDDM_SWITCH_CONF=${cfg.sddmSwitchConf}"
        "TV_SESSION_NAME=${cfg.sessions.tv}"
        "DESKTOP_SESSION_NAME=${cfg.sessions.desktop}"
      ];
      ExecStart = "${sessionSwitchWorker}/bin/session-switch-worker %i";
    };
  };

  systemd.services.session-switch-cleanup = {
    description = "Remove Temporary SDDM One-Shot Autologin Drop-in";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/rm -f ${cfg.sddmSwitchConf}";
    };
  };

  # Allow wheel users to trigger ONLY these 3 session-switching units without password
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")) {
        var unit = action.lookup("unit");
        if (unit == "session-switch@${cfg.sessions.tv}.service" ||
            unit == "session-switch@${cfg.sessions.desktop}.service" ||
            unit == "session-switch-cleanup.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';

  # Clean up temporary SDDM one-shot drop-in right after the target session starts
  systemd.user.services.sddm-switch-cleanup = {
    description = "Clean Up One-Shot SDDM Session Switch Config";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig = {
      ConditionPathExists = cfg.sddmSwitchConf;
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block session-switch-cleanup.service";
    };
  };
}
