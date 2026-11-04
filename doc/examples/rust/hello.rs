// m68k-amigaos-gccrs -mcrt=nix20 -O2 -frust-incomplete-and-experimental-compiler-do-not-use hello.rs -o hello
//
// gccrs cannot build core or std yet, so do without them, like the gccrs
// execute tests; main returning i32 is a gccrs extension
#![feature(no_core)]
#![no_core]

extern "C" {
    // dos.library is pre-opened by libnix
    fn PutStr(s: *const u8) -> i32;
}

fn main() -> i32 {
    let s = b"Hello, world!\n\0";
    unsafe {
        PutStr(s as *const [u8; 15] as *const u8);
    }
    42
}
