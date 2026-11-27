# =============================================================================
# Seamless Desktop (Hyprland) <-> TV (Gamescope) SDDM Session Switching
# - NO autologin on cold boot (purged via systemd-tmpfiles + Relogin=false)
# - Passwordless one-shot autologin ONLY during explicit session switches
# - Intercepts Steam's native "Switch to Desktop" via steamos-session-select
# =============================================================================

{ lib, pkgs, ... }:

let
  targetUser = "vini";
  sddmSwitchConf = "/etc/sddm.conf.d/zz-session-switch.conf";
  readBash = file: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile file);

  sessionSwitchHelper = pkgs.writeShellApplication {
    name = "session-switch-helper";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      util-linux
      procps
    ];
    text = readBash ./scripts/session-switch-helper.sh;
  };

  getTvMode = pkgs.writeShellApplication {
    name = "get-tv-mode";
    runtimeInputs = with pkgs; [ systemd ];
    text = readBash ./scripts/get-tv-mode.sh;
  };

  getDesktopMode = pkgs.writeShellApplication {
    name = "get-desktop-mode";
    runtimeInputs = with pkgs; [ systemd procps ];
    text = readBash ./scripts/get-desktop-mode.sh;
  };

  setTvSession = pkgs.writeShellApplication {
    name = "set-tv-session";
    runtimeInputs = with pkgs; [ systemd ];
    text = readBash ./scripts/set-tv-session.sh;
  };

  setDesktopSession = pkgs.writeShellApplication {
    name = "set-desktop-session";
    runtimeInputs = with pkgs; [ systemd procps ];
    text = readBash ./scripts/set-desktop-session.sh;
  };

  steamosSessionSelect = pkgs.writeShellApplication {
    name = "steamos-session-select";
    runtimeInputs = [ setDesktopSession setTvSession ];
    text = readBash ./scripts/steamos-session-select.sh;
  };

  sessionAliasesAndLaunchers = pkgs.runCommand "session-switch-aliases" {} ''
    mkdir -p "$out/bin" "$out/share/applications"

    ln -s ${setTvSession}/bin/set-tv-session "$out/bin/mode-tv"
    ln -s ${setTvSession}/bin/set-tv-session "$out/bin/switch-to-tv"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/mode-desktop"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/mode-bureau"
    ln -s ${setDesktopSession}/bin/set-desktop-session "$out/bin/switch-to-desktop"

    cat <<EOF > "$out/share/applications/mode-tv.desktop"
    [Desktop Entry]
    Name=Mode TV (Steam)
    Comment=Basculer vers la session Steam Gaming Mode sur la TV (HDMI-A-2)
    Exec=${setTvSession}/bin/set-tv-session
    Icon=video-television
    Terminal=false
    Type=Application
    Categories=Game;
    EOF

    cat <<EOF > "$out/share/applications/mode-desktop.desktop"
    [Desktop Entry]
    Name=Mode Bureau (Hyprland)
    Comment=Basculer vers le bureau Hyprland
    Exec=${setDesktopSession}/bin/set-desktop-session
    Icon=video-display
    Terminal=false
    Type=Application
    Categories=System;
    EOF
  '';
in
{
  environment.systemPackages = [
    getTvMode
    getDesktopMode
    setTvSession
    setDesktopSession
    steamosSessionSelect
    sessionAliasesAndLaunchers
  ];

  # Boot-time safety: always remove one-shot autologin drop-in on cold boot
  systemd.tmpfiles.rules = [
    "R! ${sddmSwitchConf} - - - - -"
  ];

  # Root template service that survives graphical session teardown cleanly
  systemd.services."session-switch@" = {
    description = "Switch SDDM Graphical Session to %i";
    serviceConfig = {
      Type = "oneshot";
      Environment = [
        "TARGET_USER=${targetUser}"
        "SDDM_SWITCH_CONF=${sddmSwitchConf}"
      ];
      ExecStart = "${sessionSwitchHelper}/bin/session-switch-helper %i";
    };
  };

  systemd.services.session-switch-cleanup = {
    description = "Remove Temporary SDDM One-Shot Autologin Drop-in";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/rm -f ${sddmSwitchConf}";
    };
  };

  # Allow wheel users to trigger ONLY these 3 session-switching units without password
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")) {
        var unit = action.lookup("unit");
        if (unit == "session-switch@gamescope-session.service" ||
            unit == "session-switch@hyprland-uwsm.service" ||
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
      ConditionPathExists = sddmSwitchConf;
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block session-switch-cleanup.service";
    };
  };
}
