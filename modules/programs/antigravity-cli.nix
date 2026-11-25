{ pkgs, inputs, ... }:

{
  environment.systemPackages = [
    inputs.antigravity-nix.packages.${pkgs.system}.google-antigravity-cli
  ];
}
