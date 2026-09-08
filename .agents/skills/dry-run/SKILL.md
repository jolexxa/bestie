---
name: dry-run
description: Audit a plan before implementation by tracing proposed changes against the real codebase, finding concrete issues, and updating only the plan file. Use when asked to dry-run, audit, validate, or sanity-check a plan before coding.
---

# Dry-run

Audit the current plan by tracing proposed changes against real code (read-only). Finds gaps, fixes them in the plan.

## Instructions

You are performing a **read-only dry run** of the current plan file. Your job is to simulate implementing every proposed change against the real codebase, find issues, and update the plan to fix them. Do NOT make any changes to source code — only read source files and edit the plan file.

### Phase 1: Load the plan

Find the plan file. If there's an active plan referenced in the session context, use that. Otherwise, list recent plan `.md` files, read the first few lines of each to get a sense of what they're about, and ask the user to pick which plan to audit. Show up to 4 recent plans as options with short descriptions based on their content.

Read the plan file and identify every file it proposes to touch (create, modify, or depend on). This includes:

- Files to be created or modified
- Files whose APIs are assumed (imports, exports, constructors, method signatures)
- Test files that would need updating
- Barrel/export files
- Generated files (codegen)
- Note any "unsure" statements in the plain "but wait," "or maybe," etc. Be sure to note those and attempt to resolve them throughout this process.

### Phase 2: Read every touched file

For each file identified in Phase 1, read its current contents. Pay attention to:

- Exact class/method/constructor signatures (parameter names, types, required vs optional)
- Import paths and barrel exports
- Existing test fakes/mocks that extend classes being modified
- State machine transitions and input handlers
- Stream subscriptions and their lifecycle (onDone, onError, cancelOnError)
- Dispose methods and resource cleanup

### Phase 3: Trace each proposed change

For each change in the plan, mentally execute it against the real code. Look for:

**Type system issues:**

- Wrong parameter types or names
- Missing required parameters in constructors
- Incorrect return types
- Generics mismatches

**API assumption errors:**

- Methods that don't exist or have different signatures
- Private members assumed to be public (or vice versa)
- Missing imports or exports in barrel files
- Wrong line number references (lines may have shifted)

**State machine edge cases:**

- Unhandled inputs in states (LogicBlock silently ignores unhandled inputs via `toSelf()`)
- Stream `onDone` firing unexpectedly when controllers are closed
- `cancelOnError: true` interactions with error-then-close sequences

**Lifecycle issues:**

- New streams/subjects not closed in `dispose()`
- New timers not cancelled in `dispose()`
- Subscriptions not cancelled

**Test breakage:**

- Fakes/mocks that extend modified classes and inherit real (possibly filesystem-touching) implementations
- Test constructors that use old parameter names/types
- Missing test coverage for new code paths

**Dependency chain issues:**

- Package pubspec.yaml missing needed deps (dart:convert, json_annotation, etc.)
- Codegen requirements (build_runner, json_serializable, part directives)
- Cross-package dependency direction violations

**Data shape issues:**

- Serialization bloat (e.g., nested objects containing more data than intended)
- Computed getters that won't survive JSON roundtrip
- Mutable vs immutable type mismatches

### Phase 4: Fix the plan

For each issue found, edit the plan file to fix it inline — correct the code, add the missing method, fix the signature, etc. Do NOT add a separate audit/report section to the plan. The plan should read as if it were always correct.

Do NOT add speculative issues. Only flag things where you can point to specific code that contradicts the plan.

Make sure the plan does not have any unsure language in it. If still uncertain, include question(s) in your report.

### Phase 5: Report to the user

As you work through phases 2-4, **show findings to the user in real time** — don't save everything for the end. Report each issue as you find it so the user can provide helpful comments and pointers while you're still tracing. A quick one-liner like "Issue: `_createLogicFromSelection` referenced but never defined — fixing" is enough.

After all edits are done, give a brief conversational summary (not in the plan file) of what you found and fixed.
