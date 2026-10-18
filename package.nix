# The toolchain as built by `make all`, installed into $out.
#
# The Makefile clones a module or downloads an archive only when it is
# missing, so the sources are put in place up front and the build itself
# needs no network.  `sources` maps each module name of default-repos to its
# source tree; `manifest` is the .manifest recording their revisions.
{
  lib,
  stdenv,
  fetchurl,
  bison,
  flex,
  gettext,
  perl,
  rsync,
  which,
  ncurses,
  zlib,
  src,
  sources,
  manifest,
  version,
  pkgVersion ? "AmigaDev ${version}",
}:

let
  # The archives of default-archives, as the Makefile reads them: a name,
  # the file in download/, its sha256 and the URLs to try.
  archives = lib.listToAttrs (
    map
      (
        line:
        let
          words = lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" line);
        in
        lib.nameValuePair (lib.elemAt words 0) {
          file = lib.elemAt words 1;
          sha256 = lib.elemAt words 2;
          urls = lib.drop 3 words;
        }
      )
      (
        lib.filter (line: builtins.match "[[:space:]]*(#.*)?" line == null) (
          lib.splitString "\n" (builtins.readFile "${src}/default-archives")
        )
      )
  );

  # the ones make all needs
  downloads = map (name: archives.${name}) [
    "gmp"
    "mpc"
    "mpfr"
    "ndk"
    "ixemul-sdk"
    "vbcc-target-m68k-amigaos"
    "vbcc-target-m68k-kick13"
  ];
in
stdenv.mkDerivation {
  pname = "m68k-amigaos-gcc";
  inherit version src;

  nativeBuildInputs = [
    bison
    flex
    gettext
    perl
    rsync
    which
  ];
  buildInputs = [
    ncurses
    zlib
  ];

  # nixpkgs hardening flags (fortify, format-security, ...) break parts of
  # the gcc and binutils builds
  hardeningDisable = [ "all" ];

  postUnpack = ''
    mkdir -p $sourceRoot/projects $sourceRoot/download
    ${lib.concatStrings (
      lib.mapAttrsToList (name: path: ''
        cp -r ${path} $sourceRoot/projects/${name}
      '') sources
    )}
    # One timestamp for all of the checkouts, so make does not regenerate
    # their generated files, after the year 2000 the libnix and binutils
    # rules stamp their sources back to
    find $sourceRoot/projects -exec touch -h -d '2020-01-01 00:00:00 UTC' {} +
    ${lib.concatMapStrings (a: ''
      cp ${
        fetchurl {
          name = a.file;
          inherit (a) urls sha256;
        }
      } $sourceRoot/download/${a.file}
    '') downloads}
    chmod -R u+w $sourceRoot/projects $sourceRoot/download
  '';

  postPatch = ''
    patchShebangs --build scripts sdk projects
    # not executable itself, the source of the sfdc script
    substituteInPlace projects/sfdc/main.pl \
      --replace-fail "#!/usr/bin/perl" "#!${perl}/bin/perl"
  '';

  dontConfigure = true;
  # the modules' own config.sub and config.guess know amigaos
  dontUpdateAutotoolsGnuConfigScripts = true;

  # The binutils of stdenv are for the build machine; keep them out of the
  # target library builds that pick tools from the environment.
  buildPhase = ''
    runHook preBuild
    (
      unset AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF SIZE STRINGS STRIP
      make -j$NIX_BUILD_CORES all \
        PREFIX=$out \
        PKGVERSION=${lib.escapeShellArg pkgVersion} \
        MANIFEST=${manifest}
    )
    runHook postBuild
  '';

  # make all already installs into PREFIX
  dontInstall = true;

  # Strip the host programs fully, make all leaves some of them unstripped.
  # Only these directories: lib holds the target libraries, which the host
  # strip has no business with.
  stripDebugList = [ ];
  stripAllList = [
    "bin"
    "libexec"
    "m68k-amigaos/bin"
    "lib/bfd-plugins"
  ];

  meta = {
    description = "GCC, binutils and tools for cross compiling to AmigaOS";
    homepage = "https://github.com/AmigaPorts/m68k-amigaos-gcc";
    license = with lib.licenses; [
      gpl2Plus
      gpl3Plus
    ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "m68k-amigaos-gcc";
  };
}
