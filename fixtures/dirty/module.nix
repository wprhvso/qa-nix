{ config, lib, pkgs }:
let
   cfg = config.services.dirtyFixture;
  dead = "никем не используется";
in {
  options.services.dirtyFixture.enable = lib.mkOption { type = lib.types.bool; default = false; };
    config = lib.mkIf ( cfg.enable ) {
    environment.systemPackages = [pkgs.hello];
      ready = if cfg.enable then true else false;
  };
}
