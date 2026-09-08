---
name: hunt-leaks
description: Hunt for leaking abstractions in a feature or layer of the codebase. Diagnoses architectural smells — closure injection, skipped layers, annotation/diagram mismatches, duplicate domain types, singleton fields for plural concerns, state enum sprawl, mutable-shared-state reads, etc — and proposes targeted refactors. Use when the user asks to "review", "audit", or "look for leaks" in a feature, or wants to validate that a recent feature isn't bolted on. See also `architecture` and `logic-blocks` skills.
---

# Hunt Leaks

You are auditing a feature (or layer, or domain aggregate) for **leaking abstractions** — places where one layer's concerns have bled into another, where a class is doing more than its annotation says it does, or where the mental model has drifted from the code shape.

This means you have a primary suspicion about the codebase. It can be as vague as "are there any leaking abstractions?" or as specific as "I think this \_ model is actually stateful and not really a model at all."

This is related to the /architecture and /logic-blocks skills.

This is **diagnostic work, not implementation**. Output is a punch list of prioritized findings + targeted refactor proposals. The user picks which to act on.

## Examples of Core Suspicions

- "I just shipped \_ feature — does it feel bolted on?"
- "Audit \_ feature for structural issues."
- "Is there duplication across \_ domain types?"
- "Why does this viewModel feel heavy?"

## Methodology

### 1. Pick a target

A feature (chat, config, palette), a domain aggregate (conversation, session), or anything that feels off.

### 2. Map the surface in one Explore agent pass

Spawn an Explore agent with a comprehensive read brief. Ask for:

- Every public method and constructor parameter on the target class
- Every dependency it pulls in (injected, looked up via blackboard, read from providers)
- Every place external code reaches into the target (line-by-line)
- The annotation it carries, and what siblings/layers it appears next to in `architecture.g.puml`
- For state machines: the full state hierarchy, inputs, outputs

You'll have to read each file in its entirety to identify potential pitfalls. This is context-heavy, but you can always suggest that user compacts your context.

### 3. Run the leak detectors

Walk the surface looking for each of these patterns. Below are some examples of real leak archetype seen in this codebase in the past, but there could be others that come to mind as you read the codebase.

#### A. Closure-as-state leak

**Symptom:** A state machine (LogicBlock, cubit) takes N closures or `Reader` wrappers in its constructor that read from another layer's mutable state. Decisions inside `on<Input>()` handlers call those closures synchronously.

**Diagnosis:** The state machine is pretending. It's actually a coordinator reading shared state at decision time, dressed up as a state machine. State machines should make decisions from their own `data` blackboard, with external truth pushed in as inputs.

**Fix:** Push decisions up to the caller. Compute the result before sending the input, and include the result as an input field. The state machine routes on the input; closures vanish.

**Example seen here:** `ConversationOrchestrator` had 7 `*Getter` closures into `ConversationRepository`. Pulled into the repo as `_planPreTurnChain()` / `_planPostTurnChain()`; orchestrator inputs grew nullable `CompactionChain` fields. All closures deleted.

#### B. Skipped architectural layer

**Symptom:** A viewModel depends directly on a repository when other features in the same codebase go through a use case. The viewModel does multi-repo orchestration ("submit a turn" = acquire brain handle + start conversation turn).

**Diagnosis:** The orchestration belongs in a `@useCase`. The viewModel should be view-shaped (state machine, selection state, format derivations), not business-shaped.

**Fix:** Introduce a feature-aggregate `@useCase` (facade style, see `architecture` skill's `@useCase` row). Move every cross-repo call into it. ViewModel ends up calling `useCase.submit(...)` instead of composing repo + session use case + brain handle inline.

**Example seen here:** `ChatLogic` depended on both `ConversationRepository` and `SessionUseCase` and did 11+ cross-repo writes. Introduced `ChatUseCase` facade; ChatLogic now depends only on the use case.

#### C. Annotation / diagram mismatch

**Symptom:** A class is annotated `@model + @PartOf(Owner)` but is actually an operational component (LogicBlock, service, lifecycle-managed). Or it's `@PartOf(X)` but doesn't appear bundled in `architecture.g.puml`.

**Diagnosis:** `@model` excludes the class from the architecture graph because it's marked as "data shape, not architectural component." If the class actually has lifecycle/behavior, it should carry the parent's layer annotation (`@repository @PartOf(Repo)`, `@useCase @PartOf(UseCase)`, etc.) — `@model + @PartOf` is the pattern for state-machine _states_ the view needs to read.

**Fix:** Change `@model` to the appropriate layer annotation. Run `dart tool/test.dart {package}` to regenerate the puml. Verify the class now appears in the diagram.

**Example seen here:** `ConversationOrchestrator` and `AuxiliaryConversationWorker` were `@model + @PartOf(ConversationRepository)`. Both are real LogicBlocks with lifecycle. Changed to `@repository + @PartOf(...)`. Diagram immediately surfaced them as repository-layer components.

#### D. Duplicate domain types across layers

**Symptom:** Two types with similar names + overlapping fields (e.g., brain `Message` vs domain `ChatMessage`, brain events vs domain content blocks).

**Diagnosis:** Often _justified_ — different layers have different shapes for different reasons (brain Message is sparse + serialization-friendly; ChatMessage carries id/timestamp/stats). But sometimes accidental — copy-paste evolution drifted.

**Test:** Is there a clean conversion bridge (`toMessage()`, `applyEvent(...)`)? Does each layer have a _reason_ for its shape? If the answer is "I don't know, it's just always been there", that's a smell.

**Fix:** If justified, document the bridge. If accidental, collapse — usually the layer that's least-modified-by-tests wins.

#### E. Singleton field for plural concern

**Symptom:** An aggregate has a `nullable singularField` for a thing that could (and conceptually should) be a list. E.g., `Conversation.compactionArtifact` (single optional artifact) when there could be a history of them, or it could be expressed as a special message in the existing `messages` list.

**Diagnosis:** Often signals a feature that was bolted on rather than integrated. The new concept didn't fit the existing shape, so a separate field was added. Now there are two parallel projection paths (timeline-with-marker, conversation-with-artifact) instead of one (messages).

**Fix:** Ask whether the new concept can be expressed _as_ the existing primary shape. "Compaction is a system message" eliminates the field, the marker variant, the projection logic, and the dual-dispatch — all in one move.

#### F. State enum sprawl

**Symptom:** Three or more enums across the stack all answering "what's happening right now" with non-trivial mappings between them.

**Diagnosis:** Each enum may be doing meaningful refinement work (orchestrator states → ConversationPhase → ChatPhase, e.g.). But the chain length and mapping function in the middle layer suggest opportunities to collapse — or at minimum, document explicitly.

**Test:** Can you draw a one-page table mapping every value to every value? If yes, justified. If the mapping requires reading code in 3 files, smell.

**Fix:** Often the right answer is _not_ to collapse — the layers serve real purposes. But the mapping should be explicit, not implicit in scattered getters. A single `derive_chat_phase.dart` function or a comment block on the enum helps.

#### G. Mutable-shared-state reads at decision time

Related to A but more general. Anywhere a class reads `someOtherObject.mutableField` to make a _decision_ (not just to forward), suspect a leak. Decisions should be made by the owner of the state, not by readers.

**Fix:** Move the decision to the owner. Or at minimum, lift the read to construction time (immutable snapshot).

#### H. Two shapes for the same thing

**Symptom:** A scratchpad type (`ActiveTurn`) and a committed type (`ChatMessage`) carry overlapping data with different mutability.

**Diagnosis:** Usually _justified_ — accumulator-during-event-stream vs immutable-record-after-commit are genuinely different lifecycles.

**Test:** Is the conversion clearly demarcated (one method, one place)? Does the mutable type have stuff the immutable doesn't, or vice versa? Are mutations to the scratchpad atomic at the conversion point? If yes to all three, justified.

### 4. Score and prioritise

For each finding, give a verdict:

- **Cleanly separated** — note it; no action.
- **Justified by layer boundary** — document the bridge if undocumented; no action.
- **Borderline — could collapse** — flag for future; ship a note.
- **Smell — should collapse** — propose a concrete refactor.

Don't propose fixes for the first two categories. Reserve them for genuine smells.

### 5. Write the report

Format:

```
## Issue 1: [name of leak archetype]

[1-2 sentence diagnosis with file:line citations]

[Verdict: which of the four categories]

[For "should collapse": concrete refactor sketch — which file, which type, which methods touched]
```

Be sure to include a TL;DR -- this is the most helpful part for the user. They'll most likely trust your judgement and ask you to go into plan mode to work out the specifics.
