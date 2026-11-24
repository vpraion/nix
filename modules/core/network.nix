{ ... }:

{
  # Machine network hostname.
  networking.hostName = "desktop";

  # NetworkManager with deterministic interface metric priorities:
  # 1. 10G SFP+/Ethernet (enp5s0) - Highest priority (metric 10)
  # 2. 1G Onboard Ethernet (enp7s0) - Fallback wired (metric 100)
  # 3. Wi-Fi 6 (wlp6s0) - Wireless fallback (metric 200)
  networking.networkmanager = {
    enable = true;
    settings = {
      "connection-10G" = {
        "match-device"      = "interface-name:enp5s0";
        "ipv4.route-metric" = 10;
        "ipv6.route-metric" = 10;
      };
      "connection-1G" = {
        "match-device"      = "interface-name:enp7s0";
        "ipv4.route-metric" = 100;
        "ipv6.route-metric" = 100;
      };
      "connection-WiFi" = {
        "match-device"      = "interface-name:wlp6s0";
        "ipv4.route-metric" = 200;
        "ipv6.route-metric" = 200;
      };
    };
  };

  # Hardened OpenSSH server configuration.
  services.openssh = {
    enable = true;
    ports  = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };
}
