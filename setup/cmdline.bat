@echo off
set "PREFIX=%~dp0"
set "PATH=%PATH%;%PREFIX%bin"
set "WORKDIR=%TEMP%\amiga-gcc"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"
cd /d "%WORKDIR%"

echo *******************************************************************************
echo *                              Welcome to amiga-gcc                           *
echo *******************************************************************************
dir "%PREFIX%bin\*.exe" /w
@echo on

if exist "%PREFIX%hello.c" m68k-amigaos-gcc "%PREFIX%hello.c" -o hello -Os -mcpu=68040 -mhard-float -mcrt=nix20

@cmd /k
