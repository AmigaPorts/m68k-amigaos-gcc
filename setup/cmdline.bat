@echo off
set "PREFIX=%~dp0"
set "PATH=%PATH%;%PREFIX%bin"
cd /d "%PREFIX%"

echo *******************************************************************************
echo *                              Welcome to amiga-gcc                           *
echo *******************************************************************************
dir "%PREFIX%bin\*.exe" /w
@echo on

if exist hello.c m68k-amigaos-gcc hello.c -o hello -Os -mcpu=68040 -mhard-float -mcrt=nix20

@cmd /k
