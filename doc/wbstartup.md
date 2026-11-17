Part of the [Amiga GCC User's Manual](manual.md).

# Workbench programs

A program started from Workbench has no shell: no command line and no
console. Workbench sends it a `WBStartup` message instead, with the icons
it was started with, and the program takes its settings from the tool types
in its icon.

## The startup message

libnix, newlib and clib2 handle the message in their startup code, and call
`main()` with `argc` 0 and the message as `argv`:

```c
#include <workbench/startup.h>

int main(int argc, char **argv)
{
    if (argc == 0) {
        const struct WBStartup *wbs = (const struct WBStartup *)argv;
        // ...
    }
}
```

| field | |
|---|---|
| `sm_NumArgs` | the number of entries in `sm_ArgList` |
| `sm_ArgList[0]` | the program's own icon |
| `sm_ArgList[1]` ... | the project icons selected with it, or dropped on it with Shift |

Each `WBArg` names its icon with `wa_Name`, relative to the drawer whose lock
is `wa_Lock`. The startup code makes the program's drawer the current
directory, and replies to the message when the program exits.

## Standard input and output

Without a shell, the startup code opens a console for stdio. With `AUTO`, its
window appears only when the program writes to it, and with `WAIT` it stays
until the user closes it. The program sets it with a global variable:

| runtime | variable | default |
|---|---|---|
| libnix (`-mcrt=nix20`), newlib | `char *__stdiowin` | `"CON://///AUTO/CLOSE/WAIT"` |
| libnix for Kickstart 1.3 (`-mcrt=nix13`) | `char *__stdiowin` | none: stdio goes nowhere |
| clib2 | `char *__stdio_window_specification` | a window named after the program |

## Tool types

The tool types are strings such as `GREETING=Ciao` in the icon, which the
user edits with Workbench's Information window. icon.library reads them:
`GetDiskObject()` loads the icon, `FindToolType()` finds a tool type's value,
and `FreeDiskObject()` frees it. With libnix and newlib the startup code
opens icon.library, as it does the other libraries a program uses; with
clib2 the program opens it, see [Libraries](libraries.md#opened-by-the-program).

[examples/wbstartup](../examples/wbstartup/) runs from a shell and from
Workbench. Its greeting is the `GREETING` tool type of its icon, which an
argument replaces in a shell, and it lists the project icons it was started
with:

```c
static const char *greeting(BPTR dir, const char *name, struct DiskObject **icon,
                            const char *def)
{
    BPTR old = 0;

    if (dir) {
        old = CurrentDir(dir);
    }
    *icon = GetDiskObject((CONST_STRPTR)name);
    if (dir) {
        CurrentDir(old);
    }

    if (*icon == nullptr) {
        return def;
    }

    const char *value = (const char *)FindToolType(
        (CONST_STRPTR *)(*icon)->do_ToolTypes, (CONST_STRPTR)"GREETING");
    return value ? value : def;
}
```

From a shell, `argv[0]` names the program, and its icon is next to it:
`greeting(0, argv[0], ...)`. From Workbench, the program's icon is
`sm_ArgList[0]`: `greeting(args[0].wa_Lock, args[0].wa_Name, ...)`. The
program prints `Ciao, Workbench!` or `Ciao, Shell!` with `GREETING=Ciao`.
