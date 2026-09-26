# 13 — Docs

**What to build:** The docs match the code: a new ADR explains why there is no house UI layer, the README names shadcn_flutter, and the conventions doc records every gap found during the build.

**Blocked by:** 12 — Remove old deps, all tests green

**Status:** done

**Model:** Opus, effort low — follows clear rules in the spec

Spec: `../../shadcn-migration/spec.md` (phase 6)

- [x] ADR 0005: catui dropped for direct shadcn_flutter; coherence held by the conventions doc (~10 lines)
- [x] README: catui/catppuccin mentions replaced
- [x] `style/components.md`: gaps and corrections from tickets 02–11 added; the catui→shadcn table kept
- [x] `CLAUDE.md`, `CONTEXT.md`, ADR 0004 untouched (already correct)
