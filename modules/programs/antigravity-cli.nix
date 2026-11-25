{ pkgs, inputs, ... }:

{
  environment.systemPackages = [
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];
}
