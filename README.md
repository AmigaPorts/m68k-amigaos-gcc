# m68k-amigaos-gcc

The GNU C Compiler with binutils and other useful tools for cross
compiling software for AmigaOS. This is the AmigaPorts continuation of
bebbo's amiga-gcc; fixes flow both ways.

This is a Makefile based approach to building the amigaos-toolchain, aiming to reduce its build time.

Currently, these tools are built:

* binutils
* gcc with libs for C/C++/ObjC
* fd2sfd
* fd2pragma
* ira
* sfdc
* vasm
* vbcc
* vlink
* libnix
* newlib
* clib2

# Branches
## Notable branches of gcc
* `amiga6`: The default branch providing gcc-6.5.0b with a lot of hacks^^
* `amiga10.4`: gcc-10.4.0  supports register parameters
* `amiga13.4`: gcc-13.4.0  supports register parameters
* `amiga15.2`: gcc-15.2.0  supports register parameters
* `amiga16.2`: gcc-16.2.0  the current development branch, built and tested by CI

## Notable branches of binutils
* `amiga-2.46`: binutils 2.46 with amigaos support and dwarf2 debugging (the default)

# COPYRIGHTS
* amiga-netinclude: 'Roadshow' -- Amiga TCP/IP stack, Copyright © 2001-2016 by Olaf Barthel. Freely Distributable.
* aros-stuff: libpthread, Copyright (C) 2014 Szilard Biro.
* binutils: Free Software Foundation, GNU GENERAL PUBLIC LICENSE V2.
* clib2: Copyright (c) 2002-2015 by Olaf Barthel.
* fd2pragma: Dirk Stoecker, public domain.
* fd2sfd: Martin Blom et al, GNU GENERAL PUBLIC LICENSE V2.
* gcc: Free Software Foundation, GNU GENERAL PUBLIC LICENSE V2.
* ira: Tim Ruehsen, Ilkka Lehtoranta, Frank Wille, Nicolas Bastien. Freeware.
* ixemul: Markus Wild, Rafael W. Luebbert, Leonard Norrgard, Jeff Shepherd, Matthias Fleischer, Hans Verkuil. GNU GENERAL PUBLIC LICENSE V2.
* libdebug: ?, GNU GENERAL PUBLIC LICENSE V2.
* libnix: Matthias Fleischer, Gunther Nikl. Public Domain.
* NDK3.2: Hyperion, unknown license...
* newlib: Free Software Foundation, GNU GENERAL PUBLIC LICENSE V2.
* sfdc: Martin Blom, GNU GENERAL PUBLIC LICENSE V2.
* vasm: copyright in 2002-2022 by Volker Barthelmann, free for non-commercial purposes.
* vbcc: copyright in 1995-2022 by Volker Barthelmann, free for non-commercial purposes.
* vlink: copyright 1995-2022 by Frank Wille, free for non-commercial purposes.

There are also libraries (SDKs) which can be downloaded and installed. These libraries can all be built from source. All of these libraries are provided under their respective licenses.

Various AmigaOS-specific patches have been applied to this version of gcc. None if these changes modify the original copyright in any way. All other changes are published under the terms of the GNU GENERAL PUBLIC LICENSE V2.

## Prerequisites
### Fedora
```
sudo dnf install wget gcc gcc-c++ python git perl-Pod-Simple gperf patch autoconf automake make makedepend bison flex ncurses-devel gmp-devel mpfr-devel libmpc-devel gettext-devel texinfo rsync readline-devel which
```

### Ubuntu, Debian
```
sudo apt install make wget git gcc g++ lhasa libgmp-dev libmpfr-dev libmpc-dev flex bison gettext texinfo ncurses-dev autoconf rsync libreadline-dev
```

If building with a normal user, the `PREFIX` directory must be writable (default is `/opt/amiga`). You can add the user to an appropriate group. 

### macOS
Install Homebrew (https://brew.sh/) or any other package manager first. The compiler will be installed together with XCode. Once XCode and Homebrew are up install the required packages:

```
brew install bash wget make lhasa gmp mpfr libmpc flex gettext gnu-sed texinfo gcc@12 make autoconf bison
```

By default macOS uses an outdated version of bash. Therefore, on macOS host always pass the the SHELL=/usr/local/bin/bash parameter (or any other valid path pointing to bash), e.g.:

```
make all SHELL=$(brew --prefix)/bin/bash
```

On macOS it may be also necessary to point to the brew version of gcc make and autoconf, e.g.:

```
CC=gcc-12 CXX=g++-12 gmake all SHELL=$(brew --prefix)/bin/bash
```

**NOTE**

* You might need to use the brew version of make when building your projects (e.g.: `gmake`). Link failures are known to happen with GNU Make 3.81, but to succeed with GNU Make 4.4.1 on the same machine and project
* If you want `m68k-amigaos-gdb` then you have to build it with `gcc`
* The `gdb` build also needs a more recent `bison` version than the one installed
  in macOS. Use the version from Homebrew instead. It's keg only so you need
  to add it to your `PATH` manually:

```
export PATH=$(brew --prefix bison)/bin:$PATH
```
* This version of gcc supports building binaries optimised for the various Motorola 68K series CPUs from the 68000 to the 68060 and also features some optimisations for the Vampire/Apollo 68080.

### macOS on M1
Native builds on M1 Macs are now directly supported.

### Windows with Cygwin
Install cygwin via setup.exe and add wget. Then open cygwin shell and run:

```
wget https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
install apt-cyg /bin
apt-cyg install gcc-core gcc-g++ python git perl-Pod-Simple gperf patch automake make makedepend bison flex libncurses-devel python-devel gettext-devel libgmp-devel libmpc-devel libmpfr-devel rsync
```

### Windows with msys2

```
pacman -S git base-devel gcc flex gmp-devel mpc-devel mpfr-devel ncurses-devel rsync autoconf automake
```

Also note that you **MUST** cd into an **absolute path** e.g. `cd /c/msys64/home/test/amiga-gcc/` before running make, or builds may fail, because some files aren't found correctly (that's a msys2 bug).

### Ubuntu running on the Windows 10 Linux subsystem
same as normal ubuntu

## Howto Clone and Download All You Need
```
git clone https://github.com/AmigaPorts/m68k-amigaos-gcc
cd m68k-amigaos-gcc
make update
```

To build the current gcc 16.2 instead of the default gcc 6.5.0b,
switch the gcc module before building:
```
make branch branch=amiga16.2 mod=gcc
```

## Overview
```
make help
```
yields:
```
make help 		        display this help
make all 		          build and install all
make <target>		      builds a target: binutils, gcc, fd2sfd, fd2pragma, ira, sfdc, vbcc, vlink, libnix, ixemul, libgcc
make clean		        remove the build folder
make clean-<target>	  remove the target's build folder
make drop-prefix	    remove all content from the prefix folder, beware!
make package		      package the prefix folder as .tar.xz (default) or .lha
make package-lha	      package the prefix folder as .lha
make check		        run the gcc testsuite against the built toolchain, using vamos as simulator
make update		        perform git pull for all targets
make update-<target>	perform git pull for the given target
```
display which targets can be build, you'll mostly use
*`make all`
*`make clean`
*`make drop-prefix`

to use NDK3.2 add `NDK=3.2` to the make parameters

## Prefix
The default prefix is `/opt/amiga`. You may specify a different prefix by adding `PREFIX=yourprefix` to make command. E.g.
```
make all PREFIX=/here/or/there
```
The build performs the installation automatically, there is no separate `make install` step. Because of this, you must make sure that the target `PREFIX` directory is writable for the user who is doing the build.
If the `PREFIX` directory points to a directory where the user already has appropriate permissions the below steps can be ommited and the directory will be created by the build process.
```
sudo mkdir /opt/amiga
sudo chgrp users /opt/amiga
sudo chmod 775 /opt/amiga
sudo usermod -a -G users username
```
After adding the user to the group, you may have to logout and login again to apply the changes to your user.

## Building
Once the `PREFIX` directory is writable, run `make all`. You can use
`-j` to speed up the build, adjusting the value of `-j` to the number
of cores you wish to use for the build process.

```
make clean
make drop-prefix
time make all -j$(nproc)
```
A full bootstrap takes roughly 10 to 30 minutes on current Linux
hardware, dominated by serial configure and multilib phases.

## Packaging
`make package` packages the PREFIX folder as `.tar.xz` by default. Native
builds use the build machine's OS and architecture in the filename. Cross
builds use `HOST`, so their filenames identify the system on which the tools
will run rather than the build machine.

Select an LHA archive with `PACKAGE_FORMAT=lha` or the `package-lha`
convenience target:

```
make package PACKAGE_FORMAT=lha
make package-lha
```

For example, `HOST=m68k-amigaos` produces a filename ending in
`-m68k-amigaos.tar.xz` or `-m68k-amigaos.lha`. Override the platform label
with `PACKAGE_PLATFORM=` and the complete output path with `PACKAGE=`:

```
make package PREFIX=/opt/amiga PACKAGE=/tmp/toolchain.tar.xz
make package-lha PREFIX=/opt/amiga PACKAGE_PLATFORM=AmigaOS-m68k
```

## Continuous integration and releases
The GitHub Actions workflow in `.github/workflows/toolchain.yml`
bootstraps the toolchain from scratch, optionally runs the gcc
testsuite under vamos, and uploads the native `.tar.xz` packages as build
artifacts. By default it also Canadian-cross-builds the `amiga6` compiler for
AmigaOS and MinGW hosts using the published
`amigadev/crosstools:m68k-amigaos-gcc10` and
`amigadev/crosstools:x86_64-w64-mingw32` build environments. The local hosted
build Dockerfiles are not rebuilt by CI. The AmigaOS package is an `.lha`; the
Windows runner uses the files in `setup/` to compile an Inno Setup installer
without running the generated installer. If installer compilation fails, the
workflow uploads a portable `.zip` instead.

Manual runs may disable the hosted builds with `build_hosted=false` or select
another hosted compiler branch with `hosted_gcc_branch`. Label a pull request
`ci-cross` to exercise the hosted builds for its merge commit.

For a hosted build, build-time tools such as `fd2sfd`, `fd2pragma`, and `vasm`
are built separately for the build machine and destination host; `sfdc`
remains directly runnable because it is a Perl script. GCC and binutils are
built only for the requested host. When target libraries need the newly built
hosted compiler or binutils, the Makefile invokes them through `HOST_RUNNER`.
No prebuilt target toolchain needs to be copied into the build.

Pushing a tag matching `v*` additionally publishes all native and hosted
packages as a GitHub release, with the gcc testsuite as a release gate.

## Kickstart 1.3

If you plan to develop for Kickstart 1.3 you should use `-mcrt=nix13` in your compiler commandline

```
m68k-amigaos-gcc test.cpp -mcrt=nix13
```

The include files for 1.3 - which are picked up by the compiler if `-mcrt=nix13` is used - can be found at `<PREFIX>/m68k-amigaos/ndk13-include` i.E. `/opt/amiga/m68k-amigaos/ndk13-include`

## Libraries/Runtimes

You can select one of the various runtimes. My favorite is `libnix` which is selected by specifying `-noixemul` or `-mcrt=nix20`. Always specify this as the last parameter and only once. These are the available runtimes:

* nothing specifed: newlib based libraries for Kickstart 2.0+
* `-noixemul` or `-mcrt=nix20`: the libnix libraries for Kickstart 2.0+
* `-mcrt=nix13`: the libnix libraries for Kickstart 1.3
* `-mcrt=clib2`: the clib2 libraries.
* `-mcrt=ixemul`: the ixemul libraries for Kickstart 2.0+, requires an installed `ixemul.library`

## Checking gcc

To check the built toolchain, run the gcc dejagnu execution tests.
This does not cover everything but it's a start. The tests run each
compiled testcase under vamos (from
https://github.com/AmigaPorts/amitools) to emulate the AmigaOS APIs,
so `vamos` must be on the PATH.

Install dejagnu (`sudo apt install dejagnu` on Debian/Ubuntu,
`brew install dejagnu` on macOS) and amitools, in a venv to keep it
out of the system Python:
```
python3 -m venv .venv
.venv/bin/pip install "amitools[vamos] @ git+https://github.com/AmigaPorts/amitools.git"
```

Then point dejagnu at the board description in this repo and run the
suite:
```
echo "lappend boards_dir \"$PWD/baseboards\"" > dejagnu-site.exp
DEJAGNU=$PWD/dejagnu-site.exp PATH="$PWD/.venv/bin:$PATH" make -j$(nproc) check
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

The gcc default branch is `amiga6`; see the Branches section above
for the alternatives. If you start from scratch, switch gcc as soon
as possible, e.g.:
```
sudo mkdir -p /opt/amiga16
sudo chown $USER /opt/amiga16
git clone https://github.com/AmigaPorts/m68k-amigaos-gcc
cd m68k-amigaos-gcc
export PREFIX=/opt/amiga16
make branch branch=amiga16.2 mod=gcc
make all -j$(nproc)
```

## Fortran support
m68k-amigaos-gfortran is available now too. To build it add `ADDLANG=fortran`:
```
make all -j20 ADDLANG=fortran
```

The example from https://gcc.gnu.org/wiki/GFortranGettingStarted does work, you have to link using gcc:
```
> m68k-amigaos-gfortran -Os fprog.f90 -c
> m68k-amigaos-gcc -Os -noixemul sub.c -c
> m68k-amigaos-gcc fprog.o sub.o  -o fprog -lgfortran -noixemul -lm
> vamos fprog
abcd 5 4711 4712.000000 13 14
```
