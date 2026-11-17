// A program that runs from a shell or from Workbench, and takes its settings
// from its icon's tool types.
//
// When started from Workbench, libnix's startup code passes argc 0 and the
// WBStartup message as argv, with the icon's drawer as the current directory.

#include <stdio.h>
#include <workbench/startup.h>
#include <workbench/workbench.h>
#include <proto/dos.h>
#include <proto/icon.h>

// Where libnix sends stdio when Workbench starts the program: a console
// that waits for the user to close it.
const char *__stdiowin = "CON:20/20/400/100/Hello/AUTO/CLOSE/WAIT";

// Returns the GREETING tool type of the icon `name` in the drawer `dir`
// (0 for the current one), or `def` if the icon or the tool type is missing.
// The returned string lives in *icon, which the caller frees when done with it.
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

int main(int argc, char **argv)
{
    struct DiskObject *icon = nullptr;

    if (argc == 0) {
        // sm_ArgList[0] is the program; the others are the project icons
        // selected with it, or dropped on it with Shift.
        const struct WBStartup *wbs = (const struct WBStartup *)argv;
        const struct WBArg *args = wbs->sm_ArgList;

        const char *hello = greeting(args[0].wa_Lock, (const char *)args[0].wa_Name,
                                     &icon, "Hello");
        printf("%s, Workbench!\n", hello);

        for (int i = 1; i < wbs->sm_NumArgs; i++) {
            printf("project: %s\n", (const char *)args[i].wa_Name);
        }
    } else {
        // From a shell the tool types are still there, as defaults that the
        // arguments override.
        const char *hello = greeting(0, argv[0], &icon, "Hello");

        if (argc > 1) {
            hello = argv[1];
        }
        printf("%s, Shell!\n", hello);
    }

    if (icon != nullptr) {
        FreeDiskObject(icon);
    }
    return 0;
}
