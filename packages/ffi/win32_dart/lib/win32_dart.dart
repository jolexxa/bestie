/// win32_dart — bestie's single source of truth for Win32 and CRT FFI on
/// Windows.
library;

export 'src/bindings/windows_bindings.dart'
    show
        ALL_PROCESSOR_GROUPS,
        CF_UNICODETEXT,
        COORD,
        ENABLE_ECHO_INPUT,
        ENABLE_LINE_INPUT,
        ENABLE_PROCESSED_INPUT,
        ENABLE_VIRTUAL_TERMINAL_INPUT,
        ENABLE_VIRTUAL_TERMINAL_PROCESSING,
        ERROR_CANCELLED,
        GMEM_MOVEABLE,
        HANDLE,
        HPCON,
        INFINITE,
        NO_INHERITANCE,
        SEE_MASK_NOCLOSEPROCESS,
        STD_ERROR_HANDLE,
        STD_INPUT_HANDLE,
        STD_OUTPUT_HANDLE,
        SUB_CONTAINERS_AND_OBJECTS_INHERIT,
        SW_HIDE,
        WindowsBindings;

export 'src/clipboard/clipboard.dart';
export 'src/console/conpty.dart';
export 'src/console/conpty_libraries.dart';
export 'src/console/console_mode.dart';
export 'src/console/pseudo_console.dart';
export 'src/constants.dart';
export 'src/crt_fd.dart';
export 'src/dll_search_path.dart';
export 'src/io/pipe.dart';
export 'src/io/read_loop.dart';
export 'src/process/attribute_list.dart';
export 'src/process/child_process.dart';
export 'src/process/exit_waiter.dart';
export 'src/query/disk.dart';
export 'src/query/link.dart';
export 'src/query/memory.dart';
export 'src/query/processors.dart';
export 'src/security/app_container_profile.dart';
export 'src/security/capability.dart';
export 'src/security/dacl.dart';
export 'src/security/elevation.dart';
export 'src/security/loopback_exemption.dart';
export 'src/security/security_capabilities.dart';
export 'src/security/sid.dart';
export 'src/stdio_redirect.dart';
export 'src/win32.dart' show win32, win32Provides;
export 'src/win32_failure.dart';
export 'src/win32_handle.dart';
