{ pkgs, ... }:

{
  # Enable Zsh at the system level to register valid shells.
  programs.zsh.enable = true;

  # Primary user account definition.
  users.users."vini" = {
    isNormalUser = true;
    description  = "Vini Praion";
    shell        = pkgs.zsh;
    extraGroups  = [
      "wheel"          # sudo permissions
      "networkmanager" # Network management without root
      "docker"         # Docker daemon socket access
    ];

    # Desktop GUI packages installed into the user profile.
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
      haruna
    ];

    # Authorized SSH public keys for remote access.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINeG34V+rulz3IucnQKPf5BMMwHRLdhuMbtmDJiKuyXf vini@vini-mba"
    ];
  };

  # Common CLI tools and utilities installed system-wide.
  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
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
    go
  ];
}
