// ffigen entry point for the Win32 + UCRT surface bestie uses.

#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

// AppContainer profiles, SID conversion, and the DACL calls that grant a
// container SID access to a path.
#include <userenv.h>
#include <sddl.h>
#include <accctrl.h>
#include <aclapi.h>

// ShellExecuteExW, for re-running bestie elevated.
#include <shellapi.h>
