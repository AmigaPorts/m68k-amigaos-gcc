# m68k-amigaos-gcc

The GNU C Compiler with binutils and other useful tools for cross compiling software for AmigaOS.
This is the AmigaPorts continuation of bebbo's amiga-gcc; fixes flow both ways.

Currently, these tools are built:

* binutils with Hunk binary format support
* gcc with frontends for C/C++/ObjC
* libnix, newlib, clib2
* sfdc, fd2sfd, fd2pragma
* vbcc, vasm, vlink
* ira (m68k reassembler)

## Branches
### Notable branches of gcc
* `amiga6`: The legacy gcc-6.5.0b branch
* `amiga10.4`: gcc-10.4.0
* `amiga13.4`: gcc-13.4.0
* `amiga15.2`: gcc-15.2.0
* `amiga16.2`: gcc-16.2.0, the default branch, built and tested by CI

### Notable branches of binutils
* `amiga-2.46`: binutils 2.46 with amigaos support and dwarf2 debugging (the default)


## Prerequisites

### Fedora
```
sudo dnf install wget gcc gcc-c++ python git perl-Pod-Simple gperf patch autoconf automake make makedepend bison flex gmp-devel mpfr-devel libmpc-devel gettext-devel rsync readline-devel which
```

### Ubuntu, Debian
```
sudo apt install make wget git gcc g++ libgmp-dev libmpfr-dev libmpc-dev flex bison gettext autoconf rsync libreadline-dev
```

### macOS
Install Homebrew (https://brew.sh/) or any other package manager first. The compiler will be installed together with XCode. Once XCode and Homebrew are up install the required packages:

```
brew install autoconf automake bash bison coreutils flex gettext gmp \
  gnu-sed gnu-tar grep make libmpc mpfr wget xz
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

* You might need to use the brew version of make when building your projects (e.g.: `gmake`). Link failures are known to happen with GNU Make 3.81, but to succeed with GNU Make 4.4.1 on the same machine and project
* If you want `m68k-amigaos-gdb` then you have to build it with `gcc` rather than the default Apple toolchain, e.g. `brew install gcc@12` and then:

```
CC=gcc-12 CXX=g++-12 gmake all
```

### Windows with msys2

```
pacman -S git base-devel gcc flex gmp-devel mpc-devel mpfr-devel rsync autoconf automake
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

The default prefix is `/opt/amiga`. You must make sure that the target `PREFIX` directory
is writable for the user who is doing the build:

```
sudo mkdir /opt/amiga
sudo chown $(id -u):$(id -g) /opt/amiga
```

You may specify a different prefix by adding `PREFIX=<path>` to the make commands:

```
make all PREFIX=$HOME/m68k-amiga-gcc
```

## Building

Once the `PREFIX` directory is writable, run `make all`. You can use `-j$(nproc)` to speed up the build.

```
make clean
make drop-prefix
time make all -j$(nproc)
```
A full bootstrap takes roughly 10 to 30 minutes on current Linux hardware, dominated by multilib phases.

## Packaging
This packages the PREFIX folder into a redistributable archive:

```
make package      # builds a .tar.xz archive
make package-lha  # builds a .lha archive
```
Native builds use the build machine's OS and architecture in the filename.
Cross builds use `HOST`, so their filenames identify the system on which the tools
will run rather than the build machine.

## Continuous integration
The GitHub Actions workflow in `.github/workflows/toolchain.yml`
bootstraps the toolchain from scratch, optionally runs the gcc
testsuite under vamos, and uploads the native `.tar.xz` packages as build
artifacts.

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

* Nothing specified: newlib-based static runtime for Kickstart 2.0+ (still the default, but uncommon nowadays)
* `-mcrt=nix20` or `-noixemul`: the libnix runtime for Kickstart 2.0+ (recommended option for most projects)
* `-mcrt=nix13`: the libnix static runtime for Kickstart 1.3 (also uses headers from `<PREFIX>/m68k-amigaos/ndk13-include`)
* `-mcrt=clib2`: the clib2 static runtime
* `-mcrt=ixemul`: the ixemul dynamic runtime for Kickstart 2.0+, requires an installed `ixemul.library`

Always specify this as the last parameter and only once.

## Checking gcc

To check the built toolchain, run the gcc dejagnu execution tests.

This does not cover everything but it's a start. The tests run each
compiled testcase under [vamos](https://github.com/AmigaPorts/amitools)
to emulate the AmigaOS APIs, so `vamos` must be on the PATH.

Install dejagnu (`sudo apt install dejagnu` on Debian/Ubuntu,
`brew install dejagnu` on macOS) and amitools, in a venv to keep it
out of the system Python:
```shell
python3 -m venv .venv
.venv/bin/pip install "amitools[vamos] @ git+https://github.com/AmigaPorts/amitools.git"
source .venv/bin/activate
```

Then run the testsuite:
```shell
make -j$(nproc) check
```

## Version management
The **Makefile** provides some targets to switch to an older state
for all modules.

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

## Copyrights

See [COPYING](COPYING) and [COPYING-THIRD-PARTY](COPYING-THIRD-PARTY.md).
