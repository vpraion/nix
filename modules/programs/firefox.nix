{ ... }:

{
  # Firefox web browser configuration.
  programs.firefox = {
    enable = true;

    # Declarative enterprise policies.
    policies = {
      # Force-install uBlock Origin ad blocker into the browser profile.
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url       = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };
}
