---
name: simplify
description: identify and propose complexity simplifications
---

Help me simplify this by finding the right abstraction.

Preserve behavior, edge cases, constraints, and user intent. Remove accidental complexity only.

First identify the invariants. Then identify what complexity is accidental. Propose a simpler model, explain what it preserves, what it removes, and what it might wrongly collapse. End with the cleanest model and a warning about where not to over-simplify.

Look at everything from a "if we simplify the mental model here, what improvements on the ground do we get?" angle.
