/// Owns the session lifecycle of the process sandbox.
library;

export 'src/host_preparation.dart'
    show
        HostPreparation,
        HostPreparationDeclined,
        HostPreparationFailed,
        HostPrepared;
export 'src/sandbox_plan.dart'
    show
        Confined,
        ConfinementDecision,
        ConfinementRefused,
        SandboxOff,
        SandboxPlan,
        SandboxPlanned,
        Unconfined;
export 'src/sandbox_read_policy.dart' show SandboxReadPolicy;
export 'src/sandbox_readiness.dart'
    show
        SandboxAwaitingInitialization,
        SandboxInitializationFailed,
        SandboxPreparingHost,
        SandboxProvisioning,
        SandboxReadiness,
        SandboxReady;
export 'src/sandbox_repository.dart' show SandboxRepository;
export 'src/sandbox_repository_for_windows.dart'
    show SandboxRepositoryForWindows;
