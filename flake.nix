{
  description = "qa-nix — единый QA для Nix-репозиториев (nixfmt, statix, deadnix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          wrapped =
            pkgs.runCommand "qa-nix"
              {
                nativeBuildInputs = [ pkgs.makeWrapper ];
                meta = {
                  description = "Единый QA для Nix-репозиториев";
                  homepage = "https://github.com/wprhvso/qa-nix";
                  mainProgram = "qa-nix";
                };
              }
              ''
                mkdir -p "$out/share/qa-nix"
                cp -r ${./config} "$out/share/qa-nix/config"
                install -Dm755 ${./scripts/local.sh} "$out/bin/qa-nix"
                wrapProgram "$out/bin/qa-nix" \
                  --set QA_LOCAL "$out/share/qa-nix" \
                  --prefix PATH : ${
                    lib.makeBinPath [
                      pkgs.deadnix
                      pkgs.git
                      pkgs.nixfmt
                      pkgs.statix
                    ]
                  }
              '';
        in
        {
          default = wrapped;
          qa-nix = wrapped;
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/qa-nix";
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.system}.default;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.actionlint
            pkgs.deadnix
            pkgs.nixfmt
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.statix
          ];
        };
      });
    };
}
