{ lib }:
let
  hosts = [
    "alpha"
    "beta"
  ];

  port = 8080;

  urlFor = host: "http://${host}:${toString port}";

  urls = map urlFor hosts;
in
{
  inherit hosts port urls;

  joined = lib.concatStringsSep ", " urls;
}
