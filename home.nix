{ config, pkgs, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Vini Praion";
        email = "vpraion@proton.me";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      core.hooksPath = "${dotfilesDir}/git/.config/git/hooks";
      core.excludesFile = "${dotfilesDir}/git/.config/git/ignore";
      commit.template = "${dotfilesDir}/git/.config/git/commit-template.txt";
    };
  };

  home.file = {
    # DE : Hyprland
    ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hypr/.config/hypr";
    ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hypr/.config/waybar";

    # Terminal : Kitty
    ".config/kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/kitty/.config/kitty";

    # Editor : Nvim
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim/.config/nvim";

    # System monitor : Btop
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/btop/.config/btop";

    # Shell : zsh
    ".zshenv".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zsh/.zshenv";
    ".config/zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zsh/.config/zsh";
  };
}
