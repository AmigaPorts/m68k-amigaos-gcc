{
  description = "m68k-amigaos-gcc: GCC, binutils and tools for cross compiling to AmigaOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

      # Parse the lines in default-repos and default-archives
      readTable =
        file: entry:
        lib.listToAttrs (
          map
            (
              line:
              let
                words = lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" line);
              in
              lib.nameValuePair (lib.head words) (entry words)
            )
            (
              lib.filter (line: builtins.match "[[:space:]]*(#.*)?" line == null) (
                lib.splitString "\n" (builtins.readFile file)
              )
            )
        );

      # the repository URL and branch of each module, and the commit it is
      # pinned to
      repos = readTable ./default-repos (words: {
        url = lib.elemAt words 1;
        branch = lib.elemAt words 2;
        rev =
          if lib.length words > 3 then
            lib.elemAt words 3
          else
            throw "default-repos: ${lib.head words} is not pinned to a commit";
      });

      # the file in download/ of each archive, its sha256 and the URLs to try
      archives = readTable ./default-archives (words: {
        file = lib.elemAt words 1;
        sha256 = lib.elemAt words 2;
        urls = lib.drop 3 words;
      });

      # the source trees of the pinned commits; make all takes ixemul from
      # ixemul-sdk.lha, not from its module
      modules = lib.mapAttrs (
        name: repo:
        let
          github = builtins.match "https://github.com/([^/]+)/([^/]+)" repo.url;
        in
        builtins.fetchTree {
          type = "github";
          owner = lib.elemAt github 0;
          repo = lib.elemAt github 1;
          inherit (repo) rev;
        }
      ) (lib.removeAttrs repos [ "ixemul" ]);

      rev = self.shortRev or self.dirtyShortRev or "unknown";

      # what make all needs from this repository
      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./Makefile
          ./disable_implicite_rules.mk
          ./default-archives
          ./default-repos
          ./lib
          ./patches
          ./scripts
          ./sdk
          ./support
        ];
      };

      # .manifest as scripts/manifest writes it
      manifest =
        pkgs:
        pkgs.writeText "manifest" (
          lib.concatStringsSep "\n" (
            [
              "# m68k-amigaos-gcc https://github.com/AmigaPorts/m68k-amigaos-gcc ${
                self.rev or self.dirtyRev or "unknown"
              }"
            ]
            ++ lib.mapAttrsToList (name: _: "${name} ${repos.${name}.url} ${repos.${name}.rev}") modules
          )
          + "\n"
        );

      package =
        pkgs:
        pkgs.callPackage ./package.nix {
          inherit src archives;
          sources = modules;
          manifest = manifest pkgs;
          version = "${lib.fileContents "${modules.gcc}/gcc/BASE-VER"}-${rev}";
          pkgVersion = "AmigaDev ${rev}";
        };
    in
    {
      packages = forAllSystems (pkgs: {
        default = package pkgs;
        m68k-amigaos-gcc = package pkgs;
      });

      overlays.default = final: _prev: {
        m68k-amigaos-gcc = package final;
      };

      # For working on the toolchain: the build prerequisites, to run
      # make update and make all as described in the README
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ (package pkgs) ];
          packages = with pkgs; [
            coreutils
            curl
            dejagnu
            file
            gawk
            git
            gnugrep
            gnumake
            gnupatch
            gnused
            gnutar
            python3
            readline
            texinfo
            unzip
            wget
            xz
          ];

          hardeningDisable = [ "all" ];

          shellHook = ''
            echo "m68k-amigaos-gcc dev shell: make update && make all PREFIX=''${PREFIX:-/opt/amiga}"
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
