---
name: architecture
description: Architectural layer enforcement via good_intentions. Use when planning features, refactoring, adding classes, moving code between packages, reviewing dependency direction, or reasoning about where new code should live. Covers layer rules, progressive validation, @PartOf composition, and how to think about problem decomposition within Bestie's layered architecture.
---

# Architecture Guide

Bestie uses **good_intentions** to enforce layered architecture at build time. Every public concrete class in an annotated package must carry an intention annotation. Violations are build errors. This is not optional — the build hook runs on `dart run`, `dart test`, and `dart build`.

## The Layer Stack

Dependencies flow **downward only**. Higher layers may depend on lower layers. Never the reverse. Siblings at the same layer cannot depend on each other.

```
  @view            UI components, widgets, pages
  @viewModel       Presentation logic (cubits, blocs, LogicBloc adapters)
  @useCase         Business orchestration across repositories
  @repository      Domain data gateways, bounded contexts, state machines
  @dataSource      External system adapters (APIs, databases, file I/O, FFI)
```

`@model` is cross-cutting — any layer can depend on a model. Models carry no layer enforcement.

## What the Annotations Mean in Practice

| Annotation    | This class...                                                | Can depend on...                                                                       |
| ------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `@view`       | Renders UI, composes other views, hosts providers            | `@viewModel`, `@useCase`, `@repository`, `@dataSource` (subject to claiming), `@model` |
| `@viewModel`  | Translates domain state into view state, handles user intent | `@useCase`, `@repository`, `@dataSource` (subject to claiming), `@model`               |
| `@useCase`    | Orchestrates multiple repositories for a business operation. One use case **per feature**, not per operation — group related commands as methods on a single facade class (e.g. `SessionUseCase.reload()` + `.retry()` + `.contextSizeFor()`). Matches the pragmatic style endorsed by the [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide). | `@repository`, `@dataSource` (subject to claiming), `@model`                           |
| `@repository` | Owns a bounded context, transforms and composes data sources | `@dataSource`, `@model`                                                                |
| `@dataSource` | Talks to external systems (HTTP, FFI, filesystem, DB)        | `@model` only                                                                          |
| `@model`      | Data class, value object, enum, utility                      | Other `@model` classes                                                                 |

## Packages That Use Intentions

A package is annotated and validated by `good_intentions` if its `pubspec.yaml` lists `intentions` as a dependency. Grep the workspace for that if you need the current list — don't rely on a hardcoded enumeration here, since packages get renamed, split, and added often enough that a static list goes stale fast.

Packages without `intentions` in their pubspec are not validated.

## Progressive Validation (Claiming)

This is the most important rule to understand for day-to-day work.

**Claiming** means: when a class at layer N depends on a class at layer M (where N is higher), that lower-layer class becomes "claimed" by layer N. Once claimed, **only layer N can access it directly** — everyone else must go through layer N.

**Example:** If `UserRepo` (@repository) depends on `UserApi` (@dataSource), then `UserApi` is claimed by the repository layer. A `@viewModel` that tries to depend on `UserApi` directly will get a build error — it must go through `UserRepo` instead.

**Why this matters for refactoring:** When you introduce a wrapper (repository wrapping a data source, use case wrapping a repository), all existing consumers above that layer must migrate to use the wrapper. The build will tell you exactly which ones.

**When there's no wrapper yet:** If a `@viewModel` depends directly on a `@dataSource` and no `@repository` wraps that data source, good_intentions issues a **warning** (not an error). This is progressive — it won't break your build until someone actually wraps that data source.

## `@PartOf` — Composition Without Layer Pollution

Use `@PartOf(OwnerType)` when a class is an implementation detail of another class. The `@PartOf` class inherits the owner's layer.

```dart
@repository
class ThingRepository {
  const ThingRepository(this.downloadService, this.recommender);
  final ThingDownloadService downloadService;
  final ThingRecommender recommender;
}

@PartOf(ThingRepository)
class ThingDownloadService { ... }

@PartOf(ThingRepository)
class ThingRecommender { ... }
```

**Rules:**

- Only the owner and sibling `@PartOf` classes can depend on a `@PartOf` class.
- `@PartOf` siblings (same owner) can depend on each other freely.
- `@PartOf` chains are allowed: `Inner` -> `@PartOf(Helper)` -> `@PartOf(Repository)` resolves to the repository's layer.

### Relaxed `@PartOf` with `@model`

When a class is logically owned by a parent but needs to be read by higher layers (e.g., state machine states), use both annotations:

```dart
@model
@PartOf(ThingRepository)
class ThingState { ... }
```

`@model` takes precedence for validation (any layer can depend on it), but the `@PartOf` relationship still appears in the architecture diagram. This is the standard pattern for state machine states that views need to read.

## How to Think About New Code

### "Where does this class go?"

1. **Does it render UI?** -> `@view`
2. **Does it manage view state / presentation logic?** -> `@viewModel`
3. **Does it orchestrate multiple repositories?** -> `@useCase`
4. **Does it own a bounded context and transform data?** -> `@repository`
5. **Does it talk to an external system?** -> `@dataSource`
6. **Is it just data / a value object / utility?** -> `@model`
7. **Is it an implementation detail of another class?** -> `@PartOf(Owner)`

### "Where does this class live (which package)?"

Bestie's package structure maps to layers, not features — a top-level directory under `packages/` corresponds to a layer tier (e.g. a `data/` directory holds `@dataSource` packages, a `domain/` directory holds `@repository` packages), and the app package holds views, view models, use cases, and feature-local repositories. Check the current top-level `packages/` layout rather than trusting a hardcoded list, since package names and groupings shift as the codebase evolves.

### "I need a new feature — how do I structure it?"

In the app package, features follow this structure:

```
features/my_feature/
  my_feature.dart       # barrel export
  domain/
    my_feature_use_case.dart    # @useCase
    my_feature_repository.dart  # @repository
  state/
    my_feature_cubit.dart       # @viewModel
    my_feature_state.dart       # state types
  view/
    my_feature_page.dart        # @view
    components/
      my_widget.dart            # @view
```

Not every feature needs every layer. A simple feature might just be a `@viewModel` + `@view`. Only add layers when they earn their keep.

### "I'm refactoring and need to move code between layers"

1. **Check what depends on the class** — if you move a class to a different layer, every consumer must still satisfy the dependency rules.
2. **Moving down is easy** — a class that was `@viewModel` becoming `@repository` won't break its consumers (they were already above it).
3. **Moving up is breaking** — a class that was `@dataSource` becoming `@repository` means other `@repository` classes can't depend on it anymore (sibling rule).
4. **Introducing a wrapper triggers claiming** — if you wrap a `@dataSource` in a new `@repository`, all classes above the repository layer that previously accessed the data source directly must now go through the repository. That's fine, just needs a little refactoring when it happens.
5. **`@PartOf` is your friend** — if a refactor splits a large class into helpers, use `@PartOf` to keep them as implementation details without creating new layer boundaries. Try not to publicly expose classes that are just implementation details.

### "This dependency feels wrong but I need it"

If you're tempted to break the rules, ask:

1. **Should the target be a `@model` instead?** Cross-cutting data doesn't need layer enforcement.
2. **Should there be an intermediate layer?** Maybe you need a `@useCase` or `@repository` to mediate.
3. **Is this an implementation detail?** Maybe `@PartOf` is the right call.

## Testing Implications

Architecture enforcement means:

- **Mock at layer boundaries.** A `@viewModel` test mocks the `@useCase` or `@repository` it depends on — never reaches down to `@dataSource` directly.
- **`@PartOf` classes are tested through their owner** (or in isolation with the owner mocked/faked).
- **`@model` classes are pure data** — test them directly, no mocking needed.

## Build Hook

Validation runs from **one hook, in the app package** — `packages/bestie/hook/build.dart`:

```dart
import 'package:good_intentions/good_intentions.dart';

Future<void> main(List<String> args) async =>
    ArchitectureValidator.validate(args);
```

This runs automatically. Architecture violations are build errors — they block `dart run`, `dart test`, and `dart build`. The hook also generates `lib/architecture.g.puml` showing the dependency graph with violations in red.
