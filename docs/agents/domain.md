# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the glossary for the time-tracking domain (Client, Entry, Session, Open Session, Active Entry, Retention Period, Report).
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

This is a single-context repo:

```
/
├── CONTEXT.md
├── docs/adr/
│   └── 0001-single-instance-loopback-socket.md
└── lib/
```

If the repo ever splits into multiple bounded contexts, a `CONTEXT-MAP.md` at the root would point at one `CONTEXT.md` per context, with context-scoped decisions under `lib/<context>/docs/adr/`. It does not today — treat the root files as authoritative.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

`CONTEXT.md` lists an `_Avoid_` line under each term — those are not stylistic preferences, they are words the project has decided *not* to use because they collide with another concept. "Task" is not an Entry; "session" is not an Entry; "active session" is not an Open Session.

Note the UI is Italian while the glossary and code are English: an Entry is "Attività" on screen, and the Open Session's owner shows an "in corso" badge. Use the English term in code and prose, the Italian only when quoting UI strings.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0001 (single-instance loopback socket) — but worth reopening because…_
