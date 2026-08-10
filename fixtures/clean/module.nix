{ config, lib }:
let
  cfg = config.services.qaFixture;
in
{
  options.services.qaFixture = {
    enable = lib.mkEnableOption "фикстуру qa-nix";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Порт, который слушает фикстура.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
