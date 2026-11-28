Part of the [Amiga GCC Development Manual](devel.md).

# Building the toolchain

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
The compiler is installed with Xcode. The other packages come from
[Homebrew](https://brew.sh/), or from another package manager:

```
brew install bash bison coreutils curl flex gettext \
  gnu-sed gnu-tar grep make wget xz
```

Apple ships old or BSD versions of many of these tools. The Homebrew GNU
versions must come first on `PATH` under their plain names, so that the
build needs no BSD workarounds. These lines in the shell profile make the
setting permanent:

```
export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$PATH"
for pkg in coreutils gnu-sed gnu-tar grep make; do
  export PATH="$(brew --prefix $pkg)/libexec/gnubin:$PATH"
done
```

Notes:

* With the `PATH` above, `make` is Homebrew's GNU make 4.x. Apple's GNU Make
  3.81 is known to produce link failures on the same machine and project, so
  GNU make 4.x is recommended for other projects too.
* `m68k-amigaos-gdb` must be built with `gcc` rather than the default Apple
  toolchain, for example after `brew install gcc@12`:

```
CC=gcc-12 CXX=g++-12 make all
```

### Nix
`nix develop` enters a shell with all build prerequisites, for the
`make update` and `make all` steps below. The toolchain itself is also
available as a Nix package, see [Nix package](package.md#nix-package).

### Windows with msys2

```
pacman -S curl git base-devel gcc flex rsync
```

`make` must be run from a directory entered by its absolute path, such as
`cd /c/msys64/home/test/amiga-gcc/`: otherwise the build may fail to find
some files, because of a bug in msys2.

## Cloning and downloading the sources

```
git clone https://github.com/AmigaPorts/m68k-amigaos-gcc
cd m68k-amigaos-gcc
make update
```

The default configuration builds GCC 16.2. `make branch` selects another GCC
branch, as described under [Version management](branches.md).

`make help` lists the targets.

## Install prefix

The build installs the toolchain as it goes: there is no separate
`make install` step.

The first build must set the installation directory with `PREFIX=<path>`,
which must be writable for the user doing the build:

```
make all PREFIX=$HOME/m68k-amigaos-gcc
```

The build tree remembers that prefix, so later invocations in the same
checkout need no `PREFIX=`, except to change it.

## Building

`-j$(nproc)` runs the build in parallel:

```
time make all -j$(nproc)
```
A full bootstrap takes roughly 5 to 15 minutes on current Linux hardware,
most of it in the multilib phases.

## Beyond `make all`

These parts are built only when named on the command line, after `all`:

| target | builds and installs |
|---|---|
| `all-sdk` | every SDK described in [sdk/](../sdk/): headers, inlines and link libraries |
| `sdk-<name>` | the SDK of `sdk/<name>.sdk`, e.g. `sdk-mui` |
| `zlib`, `libpng`, `libfreetype2` | zlib, libpng and FreeType, for every multilib |
| `vbcc`, `vlink` | the vbcc compiler and the vlink linker |
| `flexcat` | FlexCat, which makes locale catalogs and their C sources (only for Linux and macOS), and its `.sd` templates in `$PREFIX/share/flexcat`: set `FLEXCAT_SDDIR` to it to name them without their path |

`make all-dist` builds what the release packages have: `all` and all of
these but `libfreetype2`.

## Thread model

`THREADS=` picks the thread model gcc is built with, which C++'s
`std::thread`, `std::mutex`, `thread_local` and static-local guards use
(see [Runtimes](runtimes.md)):

| `THREADS=` | threads | newlib's stdio and `malloc()` |
|---|---|---|
| `amigaos`, the default | DOS processes, locked with gcc's `<benaphore.h>` | locked in a program built with `-pthread`, which a newlib program needs to start threads; without it, they cost an empty call |
| `no` | none: one task | not locked, so they cost nothing |

The release binaries are built with the default.

A build tree keeps the model it was configured with: building it with
another `THREADS` stops with an error that names the tree. The remedies are
that `THREADS`, another `BUILD`, or `make clean-gcc` and
`make clean-newlib`.
