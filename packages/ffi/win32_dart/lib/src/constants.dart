import 'package:win32_dart/src/bindings/windows_bindings.dart';

/// Address of `INVALID_HANDLE_VALUE`. It is a cast macro,
/// `((HANDLE)(LONG_PTR)-1)`, which ffigen cannot evaluate.
const int invalidHandleAddress = -1;

/// What `_get_osfhandle` returns for a descriptor with no open stream.
const int noStreamHandleAddress = -2;

/// `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE`, derived from the mask macros
/// ffigen can bind — the composite is the function-like macro
/// `ProcThreadAttributeValue(22, FALSE, TRUE, FALSE)`, which ffigen cannot
/// evaluate. Resolves to `0x20016`.
const int procThreadAttributePseudoconsole =
    (22 & PROC_THREAD_ATTRIBUTE_NUMBER) | PROC_THREAD_ATTRIBUTE_INPUT;

/// `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`, the same function-like macro
/// `ProcThreadAttributeValue(2, FALSE, TRUE, FALSE)`. Restricts a child's
/// inherited handles to exactly the listed set. Resolves to `0x20002`.
const int procThreadAttributeHandleList =
    (2 & PROC_THREAD_ATTRIBUTE_NUMBER) | PROC_THREAD_ATTRIBUTE_INPUT;

/// `PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES`, the same function-like
/// macro `ProcThreadAttributeValue(9, FALSE, TRUE, FALSE)`. Runs the child
/// under an AppContainer package SID. Resolves to `0x20009`.
const int procThreadAttributeSecurityCapabilities =
    (9 & PROC_THREAD_ATTRIBUTE_NUMBER) | PROC_THREAD_ATTRIBUTE_INPUT;

/// `FILE_ALL_ACCESS` — the concrete file rights `GENERIC_ALL` maps to. A deny
/// ACE must carry specific rights (an access check requests specifics), so an
/// unmapped generic bit in a deny matches nothing and silently no-ops; grants
/// are mapped on the allow path, where `GENERIC_ALL` is fine. ffigen cannot
/// evaluate the composite macro.
const int fileAllAccess = 0x1F01FF;

/// The rights a read-only grant needs: read plus execute, since a confined
/// program that may read a path may run it (read implies execute below the IR).
const int fileReadExecuteRights = GENERIC_READ | GENERIC_EXECUTE;

/// `FILE_GENERIC_READ`: what `GENERIC_READ` becomes in a file object's ACE.
const int fileGenericRead = 0x120089;

/// `FILE_GENERIC_WRITE`, likewise.
const int fileGenericWrite = 0x120116;

/// `FILE_GENERIC_EXECUTE`, likewise.
const int fileGenericExecute = 0x1200A0;

/// [rights] with each generic bit replaced by its file-specific rights, so a
/// mask asked for compares with one read back from an ACE.
int fileSpecificRights(int rights) {
  var specific = rights & 0x0FFFFFFF;
  if (rights & GENERIC_READ != 0) specific |= fileGenericRead;
  if (rights & GENERIC_WRITE != 0) specific |= fileGenericWrite;
  if (rights & GENERIC_EXECUTE != 0) specific |= fileGenericExecute;
  if (rights & GENERIC_ALL != 0) specific |= fileAllAccess;
  return specific;
}

/// `PROTECTED_DACL_SECURITY_INFORMATION` — severs an object from its parent's
/// inheritable ACEs. Paired with an empty DACL it carves a hole under a granted
/// root: inheritance broken, nothing granted, access falls to deny-by-absence.
const int protectedDaclSecurityInformation = 0x80000000;

/// `UNPROTECTED_DACL_SECURITY_INFORMATION` — restores inheritance flow, undoing
/// [protectedDaclSecurityInformation] so a carved hole re-inherits on teardown.
const int unprotectedDaclSecurityInformation = 0x20000000;

/// AppContainer network capability SIDs, enabled in `SECURITY_CAPABILITIES` to
/// let a confined process reach the network. `internetClient` alone grants
/// outbound internet and DNS; loopback is never capability-gated (it needs the
/// loopback exemption instead — see sandbox).
const String capabilityInternetClientSid = 'S-1-15-3-1';

/// AppContainer `internetClientServer` capability SID (inbound + outbound).
const String capabilityInternetClientServerSid = 'S-1-15-3-2';

/// AppContainer `privateNetworkClientServer` capability SID (local subnet).
const String capabilityPrivateNetworkClientServerSid = 'S-1-15-3-3';
