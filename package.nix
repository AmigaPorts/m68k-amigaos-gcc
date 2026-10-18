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
  # the archives the Makefile downloads for `make all`, with its checksums
  downloads = {
    "gmp-6.2.1.tar.bz2" = {
      url = "https://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.2.1.tar.bz2";
      sha256 = "eae9326beb4158c386e39a356818031bd28f3124cf915f8c5b1dc4c7a36b4d7c";
    };
    "mpfr-4.1.0.tar.bz2" = {
      url = "https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-4.1.0.tar.bz2";
      sha256 = "feced2d430dd5a97805fa289fed3fc8ff2b094c02d05287fd6133e7f1f0ec926";
    };
    "mpc-1.2.1.tar.gz" = {
      url = "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.2.1.tar.gz";
      sha256 = "17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459";
    };
    "NDK3.2.lha" = {
      url = "https://aminet.net/dev/misc/NDK3.2.lha";
      sha256 = "96cabd4ad683dced632e147bf86dee0f50dcb1254386216c25c362916a6409bb";
    };
    "ixemul-sdk.lha" = {
      url = "https://aminet.net/util/libs/ixemul-sdk.lha";
      sha256 = "00b4054283b99d22f6b353194fa8c75917ec0cc08a3a64395a891da446db07fc";
    };
    "vbcc_target_m68k-amigaos.lha" = {
      url = "http://aminet.net/dev/c/vbcc_target_m68k-amiga.lha";
      sha256 = "ec734d7115359cdb5d1c70349284ecbd5712ef47e8bc28d4150117c6f8c73289";
    };
    "vbcc_target_m68k-kick13.lha" = {
      url = "http://aminet.net/dev/c/vbcc_target_m68k-kick13.lha";
      sha256 = "8815948604eb50ec8b82d4fd2c9d673f5ec59a6623778edfcb29a7df608ea711";
    };
  };
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
    ${lib.concatStrings (
      lib.mapAttrsToList (name: d: ''
        cp ${fetchurl d} $sourceRoot/download/${name}
      '') downloads
    )}
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
