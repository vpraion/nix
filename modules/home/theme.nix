# =============================================================================
# Desktop Theming, Icons & Cursor Configuration (Breeze Dark Everywhere)
# Configures unified Breeze Dark styling and KDE Breeze Dark icons across
# Qt/KDE apps (Dolphin, Gwenview, Haruna), GTK3/GTK4, and XDG Portals.
# =============================================================================

{ config, pkgs, ... }:

{
  # ===========================================================================
  # KDE / Qt Theme, Icons & Desktop Integration Packages
  # ===========================================================================
  home.packages = with pkgs; [
    kdePackages.breeze              # Breeze Qt widget style & BreezeDark.colors
    kdePackages.breeze-icons        # KDE Breeze & Breeze-Dark icon themes
    kdePackages.breeze-gtk          # Matching Breeze-Dark GTK3/GTK4 theme
    kdePackages.plasma-integration  # Native KDE QPA platform theme plugin
    kdePackages.qqc2-desktop-style  # Qt Quick Controls 2 Breeze styling (Kirigami/QML)
    kdePackages.kio-extras          # Thumbnails & extra KIO protocols for Dolphin
  ];

  # ===========================================================================
  # Cursor Theme (GTK, X11/XWayland & Wayland)
  # ===========================================================================
  home.pointerCursor = {
    enable     = true;
    gtk.enable = true;
    x11.enable = true;
    package    = pkgs.kdePackages.breeze;
    name       = "breeze_cursors";
    size       = 32;
  };

  # ===========================================================================
  # Qt / KDE Application Theming
  # Uses the native KDE platform theme so Qt6/KDE apps read ~/.config/kdeglobals.
  # ===========================================================================
  qt = {
    enable             = true;
    platformTheme.name = "kde";
    style.name         = "breeze";
  };

  xdg.configFile."kdeglobals".text = ''
    ${builtins.readFile "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors"}

    [Icons]
    Theme=breeze-dark

    [KDE]
    widgetStyle=Breeze
    LookAndFeelPackage=org.kde.breezedark.desktop
  '';

  # ===========================================================================
  # GTK3 / GTK4 & XDG Desktop Portal Dark Mode
  # ===========================================================================
  gtk = {
    enable = true;

    theme = {
      name    = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };

    iconTheme = {
      name    = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Drives xdg-desktop-portal-gtk, Libadwaita, Firefox, and Electron/Vesktop dark mode.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme    = "Breeze-Dark";
      icon-theme   = "breeze-dark";
    };
  };
}
