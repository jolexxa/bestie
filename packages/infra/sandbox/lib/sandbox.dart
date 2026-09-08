/// bestie's cross-platform sandbox contract.
library;

export 'src/confined_sandbox.dart' show ConfinedSandbox;
export 'src/lowering/ancestors.dart' show unlistedAncestorsOf;
export 'src/lowering/effective_policy.dart' show EffectivePolicy;
export 'src/lowering/enumerated_deny_lowering.dart' show EnumeratedDenyLowering;
export 'src/lowering/glob.dart' show GlobExpander;
export 'src/lowering/lowered_policy.dart'
    show Deny, Grant, GrantAccess, GrantProgram, LoweredPolicy, MaskedProgram;
export 'src/lowering/lowering.dart' show Lowering;
export 'src/lowering/lowering_compiler.dart' show LoweringCompiler;
export 'src/lowering/lowering_outcome.dart'
    show LoweringOutcome, LoweringSucceeded;
export 'src/lowering/native_deny_lowering.dart' show NativeDenyLowering;
export 'src/lowering/resolved_spec.dart' show ResolvedDeny, ResolvedSpec;
export 'src/lowering/wire.dart' show encodeWire, wireMagic;
export 'src/sandbox_acquisition.dart'
    show
        SandboxAcquired,
        SandboxAcquisition,
        SandboxConsentDeclined,
        SandboxInitializing,
        SandboxProvisioningFailed,
        SandboxUnavailable;
export 'src/sandbox_backend.dart' show SandboxBackend;
export 'src/sandbox_enforcement.dart'
    show
        NetworkConfined,
        NetworkEnforcement,
        NetworkIneligibleForConfinement,
        NetworkPartiallyConfined,
        SandboxCapability,
        SandboxEnforcement;
export 'src/sandbox_spec.dart' show NetworkTier, SandboxSpec;
export 'src/suspect.dart' show SandboxSuspector;
export 'src/suspicion.dart' show SandboxDimension, SandboxSuspicion;
