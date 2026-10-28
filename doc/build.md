# Building the toolchain

Part of the [Amiga GCC Development Manual](devel.md).

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
as a Nix package instead, see [Nix package](package.md#nix-package).

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
under [Version management](branches.md) if you need a different GCC
branch.

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
