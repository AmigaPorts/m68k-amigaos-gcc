# Packaging the toolchain

Part of the [Amiga GCC Development Manual](devel.md).

This packages the PREFIX folder into a redistributable archive:

```
make package      # builds a .tar.xz archive
make package-lha  # builds a .lha archive
```
Native builds use the build machine's OS and architecture in the filename.
Cross builds use `HOST`, so their filenames identify the system on which the tools
will run rather than the build machine.

## Nix package

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
