# m68k-amigaos-gcc

The GNU C Compiler with binutils and other useful tools for cross compiling software for AmigaOS.
This is the AmigaPorts continuation of bebbo's amiga-gcc; fixes flow both ways.

Currently, these tools are built:

* binutils with Hunk binary format support
* gcc with frontends for C/C++/ObjC; the experimental Rust frontend (gccrs) builds with `make ADDLANG=rust`, which needs cargo (see `rust-demo/`)
* libnix, newlib, clib2
* sfdc, fd2sfd, fd2pragma
* vbcc, vasm, vlink
* ira (m68k reassembler)

## Branches
### Notable branches of gcc
* `amiga6`: The legacy GCC 6.5.0b
* `amiga13.4`: GCC 13.4, unsupported but still widely used
* `amiga16.2`: GCC 16.2, the default branch, built and tested by CI

### Notable branches of binutils
* `amiga-2.46`: binutils 2.46 with amigaos support and dwarf2 debugging (the default)


## Prerequisites

### Fedora
```
sudo dnf install curl gcc gcc-c++ patch make bison flex rsync ncurses-devel which
```

### Ubuntu, Debian
```
sudo apt install make curl gcc g++ flex bison gettext rsync libreadline-dev
```

### macOS
Install Homebrew (https://brew.sh/) or any other package manager first. The compiler will be installed together with XCode. Once XCode and Homebrew are up install the required packages:

```
brew install bash bison coreutils curl flex gettext \
  gnu-sed gnu-tar grep make wget xz
```

Apple ships old or BSD versions of many of these tools. Put the Homebrew GNU
versions first on `PATH` under their plain names, so the build machinery does
not need BSD workarounds (add these lines to your shell profile to make them
permanent):

```
export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$PATH"
for pkg in coreutils gnu-sed gnu-tar grep make; do
  export PATH="$(brew --prefix $pkg)/libexec/gnubin:$PATH"
done
```

**NOTE**

* With the `PATH` above, `make` is Homebrew's GNU make 4.x; Apple's GNU Make 3.81 is known to produce link failures on the same machine and project, so use it for your own projects too
* If you want `m68k-amigaos-gdb` then you have to build it with `gcc` rather than the default Apple toolchain, e.g. `brew install gcc@12` and then:

```
CC=gcc-12 CXX=g++-12 make all
```

### Nix
`nix develop` enters a shell with all build prerequisites, for the
`make update` and `make all` steps below. To get the toolchain itself
as a Nix package instead, see [Nix package](#nix-package).

### Windows with msys2

```
pacman -S curl git base-devel gcc flex rsync
```

Also note that you **MUST** cd into an **absolute path** e.g. `cd /c/msys64/home/test/amiga-gcc/` before running make, or builds may fail, because some files aren't found correctly (that's a msys2 bug).


## Cloning and Downloading Sources

```
git clone https://github.com/AmigaPorts/m68k-amigaos-gcc
cd m68k-amigaos-gcc
make update
```

The default configuration builds GCC 16.2. Use `make branch` as described
under Version management if you need a different GCC branch.

Use `make help` to see which targets can be built.

## Install Prefix

The build performs the installation automatically, there is no separate `make install` step.

The first build must set the installation directory with `PREFIX=<path>`,
which must be writable for the user doing the build:

```
make all PREFIX=$HOME/m68k-amigaos-gcc
```

The build tree remembers that prefix, so later invocations in the same
checkout need no `PREFIX=` unless you want another one.

## Building

You can use `-j$(nproc)` to speed up the build:

```
time make all -j$(nproc)
```
A full bootstrap takes roughly 5 to 15 minutes on current Linux hardware, dominated by multilib phases.

## Packaging

This packages the PREFIX folder into a redistributable archive:

```
make package      # builds a .tar.xz archive
make package-lha  # builds a .lha archive
```
Native builds use the build machine's OS and architecture in the filename.
Cross builds use `HOST`, so their filenames identify the system on which the tools
will run rather than the build machine.

### Nix package

The flake builds the toolchain of `make all` as a package, from the modules
of `default-repos` pinned in `flake.lock` and the archives of
`default-archives`:

```
nix build github:AmigaPorts/m68k-amigaos-gcc   # or nix build . in a checkout
./result/bin/m68k-amigaos-gcc --version
nix profile install github:AmigaPorts/m68k-amigaos-gcc
```

Other flakes can use `packages.<system>.default` or add
`m68k-amigaos-gcc` to their nixpkgs with `overlays.default`, for example
in a project's development shell:

```nix
{
  inputs.amiga-gcc.url = "github:AmigaPorts/m68k-amigaos-gcc";
  outputs = { nixpkgs, amiga-gcc, ... }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      packages = [ amiga-gcc.packages.x86_64-linux.default ];
    };
  };
}
```

`nix flake update` moves every module to the head of its branch, and
`nix flake update gcc` just one. The inputs in `flake.nix` mirror
`default-repos`; to build another branch, change the input's URL, for
example `github:AmigaPorts/gcc/amiga13.4`.

## Continuous integration

The GitHub Actions workflow in `.github/workflows/toolchain.yml`
bootstraps the toolchain from scratch, runs amigaos.exp and the libnix
tests under volamos by default (with `simulator=vamos`, amigaos.exp runs
under vamos and the libnix tests are skipped), runs the full gcc testsuites
on request, and uploads the native `.tar.xz` packages as build artifacts.

By default it also Canadian-cross-builds the `amiga16.2` compiler for AmigaOS
and MinGW hosts, using the published `amigadev/crosstools:m68k-amigaos-gcc10`
and `amigadev/crosstools:x86_64-w64-mingw32` build environments. The local hosted
build Dockerfiles are not rebuilt by CI. The AmigaOS package is an `.lha`; the
Windows runner uses the files in `setup/` to compile an Inno Setup installer
without running the generated installer. If installer compilation fails, the
workflow uploads a portable `.zip` instead.

## Releases

Pushing a tag matching `v*` publishes the binary archives as a GitHub release,
with the gcc testsuite as a release gate.

## Libraries/Runtimes

You can select one of the various runtimes:

* `-mcrt=nix20`: the libnix runtime for Kickstart 2.0+ (**recommended for most projects**)
* `-mcrt=nix13`: the libnix static runtime for Kickstart 1.3 (also uses headers from `ndk13-include`)
* `-mcrt=newlib`: the newlib-based static runtime for Kickstart 2.0+ (**default, but uncommon nowadays**)
* `-mcrt=clib2`: the clib2 static runtime
* `-mcrt=ixemul`: the ixemul dynamic runtime for Kickstart 2.0+, requires an installed `ixemul.library`
* `-noixemul`: a misleadingly named alias for `-mcrt=nix20` (**deprecated**)

Always specify the runtime, even when you want the default:
it affects the include path as well as the libraries, so
**compiling for one runtime and linking against another breaks quietly**.

## Testing

To check the built toolchain, run the gcc dejagnu execution tests.

This does not cover everything but it's a start. The tests run each
compiled testcase under [volamos](https://github.com/sidick/volamos), which
emulates the AmigaOS APIs; `make check` downloads its release binary into
`$PREFIX/bin` first (`make volamos` does just that).

Install dejagnu (`sudo apt install dejagnu` on Debian/Ubuntu,
`brew install dejagnu` on macOS), then run the testsuite:
```shell
make -j$(nproc) check
```

The `baseboards/amigaos*.exp` boards run the same tests under
[vamos](https://github.com/AmigaPorts/amitools) instead, for comparison.
Install amitools, in a venv to keep it out of the system Python, and
select one with `board`:
```shell
python3 -m venv .venv
.venv/bin/pip install "amitools[vamos] @ git+https://github.com/AmigaPorts/amitools.git"
source .venv/bin/activate
make -j$(nproc) check board=amigaos
```
(`board=volamos-020`, `board=volamos-baserel`, etc. have matching
`amigaos-020`, `amigaos-baserel`, ... counterparts).

## Version management

The **Makefile** provides some targets to switch to an older state
for all modules.

### Rebuilding a release
A release tags every module as `m68k-amigaos-gcc-<tag>`. Check out the
release here, then every module at its tag:
```
git checkout v16.2-rc17
make v ref=m68k-amigaos-gcc-v16.2-rc17
```
This also pins `.repos` to the tag, so `make update` clones any module
not checked out yet at the same tag. A module without the tag is an
error. Any tag, branch or commit that exists in every module works.

### Switching amiga-gcc to a given date
Use make to switch all modules to a given date. You may also add the time
```
make v date=2021-04-01
```
### Switching amiga-gcc back to the branches
Run make to switch all modules back to the branch
```
make v
```
After `make v ref=...`, restore the branches in `.repos` first:
`cp default-repos .repos`, then `make branch` for any module that was not
on its default branch.
### Show the current commit for all submodules
This lists all modules with the last commit. Useful if you switched to a given date to show what's where.
```
make l
```
### Switch a module to a different branch
You can switch modules to different branches. E.g.
```
make branch mod=binutils branch=devel1
```
The default branches and repositories are in the file **default-repos**, the local state is managed in the file **.repos**.
The archives the build downloads, with their checksums, are in the file **default-archives**.

## Copyrights

See [COPYING](COPYING) and [COPYING-THIRD-PARTY](COPYING-THIRD-PARTY.md).
