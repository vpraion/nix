# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # Disable automnatic zstd firmware compression.
  hardware.firmwareCompression = "none";

  # Load G9 Edid
  hardware.firmware = [
    (pkgs.linkFarm "g9-edid" [
        {
          name = "lib/firmware/edid/LC49G95.bin";
          path = "${inputs.g9-edid}/edids/LC49G95.bin";
        }
      ]
    )
  ];
  
  # Put G9 Edid in DP-2 Output
  boot.kernelParams = [
    "drm.edid_firmware=DP-2:edid/LC49G95.bin"
  ];
  
  # Set RX 6900 XT as boot_vga (1st PCIe x16 slot)
  services.udev.extraRules = ''
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="0000:0d:00.0", TAG+="boot_vga"  
  '';

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager = {
    enable = true;
    settings = {
      "connection-10G" = {
        "match-device" = "interface-name:enp5s0";
        "ipv4.route-metric" = 10;
        "ipv6.route-metric" = 10;
      };
      "connection-1G" = {
        "match-device" = "interface-name:enp7s0";
        "ipv4.route-metric" = 100;
        "ipv6.route-metric" = 100;
      };
      "connection-WiFi" = {
        "match-device" = "interface-name:wlp6s0";
        "ipv4.route-metric" = 200;
        "ipv6.route-metric" = 200;
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Setup SDDM.
  services.xserver.enable = true;
  services.displayManager = {
    sddm = {
      enable = true;
      theme = "catppuccin-mocha-mauve";
      package = pkgs.kdePackages.sddm;
    };
    defaultSession = "hyprland-uwsm";
  };


  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."vini" = {
    isNormalUser = true;
    description = "Vini Praion";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kitty
      rofi
      waybar
      hyprshot
      hyprpaper
      wl-clipboard
      kdePackages.dolphin
      vesktop
      pavucontrol
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINeG34V+rulz3IucnQKPf5BMMwHRLdhuMbtmDJiKuyXf vini@vini-mba"
    ];
  };

  # Install hyprland DE
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  # Install zsh
  programs.zsh.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
  # Install Steam
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };
  # Gamemode
  programs.gamemode.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
    zsh
    btop
    fzf
    fd
    bat
    zoxide
    starship
    ripgrep
    eza
    ffmpeg
    python3Minimal
    nvtopPackages.full
    ncdu
    yazi
    (catppuccin-sddm.override {
      flavor = "mocha";
      font = "JetBrainsMono Nerd Font";
    })
  ];

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
