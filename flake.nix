{
  description = "m68k-amigaos-gcc: GCC, binutils and tools for cross compiling to AmigaOS";

  # The modules of default-repos, pinned in flake.lock; `nix flake update`
  # moves them to the heads of their branches.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    amiga-netinclude = {
      url = "github:AmigaPorts/amiga-netinclude/main";
      flake = false;
    };
    binutils = {
      url = "github:AmigaPorts/binutils-gdb/amiga-2.46";
      flake = false;
    };
    clib2 = {
      url = "github:AmigaPorts/clib2/master";
      flake = false;
    };
    fd2pragma = {
      url = "github:AmigaPorts/fd2pragma/master";
      flake = false;
    };
    fd2sfd = {
      url = "github:AmigaPorts/fd2sfd/master";
      flake = false;
    };
    gcc = {
      url = "github:AmigaPorts/gcc/amiga16.2";
      flake = false;
    };
    ira = {
      url = "github:AmigaPorts/ira/master";
      flake = false;
    };
    lha = {
      url = "github:AmigaPorts/lha/master";
      flake = false;
    };
    libdebug = {
      url = "github:AmigaPorts/libdebug/master";
      flake = false;
    };
    libnix = {
      url = "github:AmigaPorts/libnix/master";
      flake = false;
    };
    newlib-cygwin = {
      url = "github:AmigaPorts/newlib-cygwin/amiga";
      flake = false;
    };
    sfdc = {
      url = "github:AmigaPorts/sfdc/master";
      flake = false;
    };
    vasm = {
      url = "github:AmigaPorts/vasm/master";
      flake = false;
    };
    vbcc = {
      url = "github:AmigaPorts/vbcc/master";
      flake = false;
    };
    vlink = {
      url = "github:AmigaPorts/vlink/master";
      flake = false;
    };
    aros-stuff = {
      url = "github:AmigaPorts/aros-stuff/master";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
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

      # the repository URL and branch of each module
      repos = readTable ./default-repos (words: {
        url = lib.elemAt words 1;
        branch = lib.elemAt words 2;
      });

      # the file in download/ of each archive, its sha256 and the URLs to try
      archives = readTable ./default-archives (words: {
        file = lib.elemAt words 1;
        sha256 = lib.elemAt words 2;
        urls = lib.drop 3 words;
      });

      modules = lib.removeAttrs inputs [
        "self"
        "nixpkgs"
      ];

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
            ++ lib.mapAttrsToList (name: input: "${name} ${repos.${name}.url} ${input.rev}") modules
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
            echo "m68k-amigaos-gcc dev shell: make update && make all all-sdk PREFIX=''${PREFIX:-/opt/amiga}"
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
