# 03 — Toast on shadcn

**What to build:** Message toasts and the AI toast use shadcn's native toast stack: bottom-right, stack of 3, a message stacks over the AI toast and the AI toast shows again when it closes. The AI toast closes and is raised again on each AI state change. Callers do not change.

**Blocked by:** 02 — ShadcnApp root

**Status:** ready-for-agent

Spec: `../../shadcn-migration/spec.md` (phase 1; ticket 10 of the map)

- [ ] `showToast` keeps its signature; the 7 call sites are untouched
- [ ] Sticky/generation bookkeeping, the sonner overlay and its config are deleted
- [ ] Navigator key reachable from the toast helper; dialogs opened from the toast still work
- [ ] AI toast test on a `ShadcnApp` harness: messages stack, 5s timer
- [ ] `pws -c flutter analyze` has no errors
