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
* `amiga6`: The legacy gcc-6.5.0b branch
* `amiga10.4`: gcc-10.4.0
* `amiga13.4`: gcc-13.4.0
* `amiga15.2`: gcc-15.2.0
* `amiga16.2`: gcc-16.2.0, the default branch, built and tested by CI

## Notable branches of binutils
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

If building with a normal user, the `PREFIX` directory must be writable (default is `/opt/amiga`). You can add the user to an appropriate group. 

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

* This version of gcc supports building binaries optimised for the various Motorola 68K series CPUs from the 68000 to the 68060 and also features some optimisations for the Vampire/Apollo 68080.

### macOS on M1
Native builds on M1 Macs are now directly supported.

### Windows with Cygwin
Install cygwin via setup.exe and add wget. Then open cygwin shell and run:

```
wget https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
install apt-cyg /bin
apt-cyg install gcc-core gcc-g++ python git perl-Pod-Simple gperf patch automake make makedepend bison flex python-devel gettext-devel libgmp-devel libmpc-devel libmpfr-devel rsync
```

### Windows with msys2

```
pacman -S git base-devel gcc flex gmp-devel mpc-devel mpfr-devel rsync autoconf automake
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

The default configuration builds GCC 16.2. Use `make branch` as described
under Version management if you need a different GCC branch.

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
Once the `PREFIX` directory is writable, run `make all`. You can use `-j$(nproc)` to speed up the build.

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
artifacts. By default it also Canadian-cross-builds the `amiga16.2` compiler
for AmigaOS and MinGW hosts, using the published
`amigadev/crosstools:m68k-amigaos-gcc10` and
`amigadev/crosstools:x86_64-w64-mingw32` build environments. The local hosted
build Dockerfiles are not rebuilt by CI. The AmigaOS package is an `.lha`; the
Windows runner uses the files in `setup/` to compile an Inno Setup installer
without running the generated installer. If installer compilation fails, the
workflow uploads a portable `.zip` instead.

Pushing a tag matching `v*` additionally publishes the tarball as a
GitHub release, with the gcc testsuite as a release gate.

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

# Copyrights

See [COPYING](COPYING) and [COPYING-THIRD-PARTY](COPYING-THIRD-PARTY.md).
