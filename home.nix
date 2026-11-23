{ config, pkgs, ... }:

{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Vini Praion";
    userEmail = "vpraion@proton.me";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
