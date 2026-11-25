# =============================================================================
# Home Manager User Configuration for 'vini'
# Manages dotfile symlinks, user environment variables, and desktop aesthetics.
# =============================================================================

{ config, pkgs, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/.dotfiles";
in
{
  # Home Manager release compatibility version.
  home.stateVersion = "26.05";

  # Enable Home Manager to manage itself.
  programs.home-manager.enable = true;

  # ===========================================================================
  # Git Configuration
  # ===========================================================================
  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = "Vini Praion";
        email = "vpraion@proton.me";
      };
      init.defaultBranch = "main";
      pull.rebase        = true;
      core.hooksPath     = "${dotfilesDir}/git/.config/git/hooks";
      core.excludesFile  = "${dotfilesDir}/git/.config/git/ignore";
      commit.template    = "${dotfilesDir}/git/.config/git/commit-template.txt";
    };
  };

  # ===========================================================================
  # Out-of-Store Dotfiles Symlinks
  # Links live Git repositories in ~/.dotfiles directly into the home directory,
  # allowing immediate edits without needing 'home-manager switch' on every tweak.
  # ===========================================================================
  home.file = {
    # Desktop Environment: Hyprland, Waybar & Rofi
    ".config/hypr".source   = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hypr/.config/hypr";
    ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hypr/.config/waybar";
    ".config/rofi".source   = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hypr/.config/rofi";

    # Terminal: Kitty
    ".config/kitty".source  = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/kitty/.config/kitty";

    # Text Editor: Neovim
    ".config/nvim".source   = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim/.config/nvim";

    # System Monitor: Btop
    ".config/btop".source   = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/btop/.config/btop";

    # Shell: Zsh
    ".zshenv".source        = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zsh/.zshenv";
    ".config/zsh".source    = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zsh/.config/zsh";

    # RGB Lighting Profiles: OpenRGB
    ".config/OpenRGB".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/OpenRGB/.config/OpenRGB";

    # Merged Virtual Media Library link to /srv/media
    "Videos/Media".source = config.lib.file.mkOutOfStoreSymlink "/srv/media";
  };

  # ===========================================================================
  # User Icon Packages
  # ===========================================================================
  home.packages = with pkgs; [
    kdePackages.breeze-icons
  ];

  # ===========================================================================
  # Cursor Theme Configuration
  # Configures Breeze Dark cursors across GTK and X11/XWayland applications.
  # ===========================================================================
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package    = pkgs.kdePackages.breeze;
    name       = "breeze_cursors";
    size       = 32;
  };

  # ===========================================================================
  # Systemd User Session Environment Variables
  # Injected into the user session for Wayland gaming and HDR support.
  # ===========================================================================
  systemd.user.sessionVariables = {
    # Force Proton to use native Wayland swapchains instead of XWayland.
    PROTON_ENABLE_WAYLAND = "1";

    # Expose HDR swapchains to Proton games.
    PROTON_ENABLE_HDR = "1";
  };
}
