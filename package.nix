# The toolchain as built by `make all`, installed into $out.
#
# The Makefile clones a module or downloads an archive only when it is
# missing, so the sources are put in place up front and the build itself
# needs no network.  `sources` maps each module name of default-repos to its
# source tree, `archives` each archive name of default-archives to its file,
# sha256 and URLs; `manifest` is the .manifest recording their revisions.
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
  archives,
  manifest,
  version,
  pkgVersion ? "AmigaDev ${version}",
}:

let
  # the archives make all needs
  downloads = map (name: archives.${name}) [
    "gmp"
    "mpc"
    "mpfr"
    "ndk"
    "ixemul-sdk"
    "ixemul-libs"
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

  # The binutils of stdenv are for the build machine, but configure scripts
  # for the target, like newlib's, take AR and the like from the
  # environment.  Hide them while make runs, and bring them back for the
  # strip in fixup.
  preBuild = ''
    hostTools=$(for tool in AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF SIZE STRINGS STRIP; do
      [ -z "''${!tool+set}" ] || printf 'export %s=%q\n' $tool "''${!tool}"
    done)
    unset AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF SIZE STRINGS STRIP
  '';
  postBuild = ''
    eval "$hostTools"
  '';

  enableParallelBuilding = true;
  buildFlags = [ "all" ];
  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "MANIFEST=${manifest}"
  ];
  # with a space, so not in makeFlags; the Makefile takes it from the
  # environment
  env.PKGVERSION = pkgVersion;

  # make all already installs into PREFIX
  dontInstall = true;

  # Strip the host programs fully, make all leaves some of them unstripped.
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
