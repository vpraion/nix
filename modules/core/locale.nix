{ pkgs, ... }:

{
  # Primary time zone.
  time.timeZone = "Europe/Paris";

  # Default system locale (English for clean CLI logs and error messages).
  i18n.defaultLocale = "en_US.UTF-8";

  # Regional French settings for formatting (currencies, measurements, dates, phone numbers).
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT    = "fr_FR.UTF-8";
    LC_MONETARY       = "fr_FR.UTF-8";
    LC_NAME           = "fr_FR.UTF-8";
    LC_NUMERIC        = "fr_FR.UTF-8";
    LC_PAPER          = "fr_FR.UTF-8";
    LC_TELEPHONE      = "fr_FR.UTF-8";
    LC_TIME           = "fr_FR.UTF-8";
  };

  # System-wide fonts.
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
