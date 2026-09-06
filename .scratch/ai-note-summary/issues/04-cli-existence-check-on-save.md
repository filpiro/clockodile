# 04 — CLI existence check on Salva

**Blocked by:** 01 — AI section in Settings

**Status:** ready-for-agent

**What to build:**

A user who enables AI and picks a provider whose CLI is not actually on the
machine finds out immediately, at Salva, rather than the first time they press
the AI button on a Nota full of pasted email.

Pressing Salva, before anything is persisted, runs the chosen provider's binary
with `--version` — through WSL if WSL Mode is on — with a short timeout. A
non-zero exit or a spawn failure blocks the **entire** save with an inline error
naming the CLI. Nothing is written, including the retention setting, so a
rejected save never half-applies.

The check runs only when AI is enabled; with the switch off there is no provider
to verify and Salva behaves as it always has.

On Windows the failure message should point at WSL Mode as the likely cause,
because a CLI installed inside WSL is by far the most common reason for this to
fail. On the development machine all three CLIs are WSL-only and Windows finds
none of them, so this check fails for every provider until WSL Mode is switched
on — that is intended behaviour, not a bug.

**Existence is checked; authentication is not.** A real generation would make
Salva take tens of seconds, and the result would be stale by the next press of
the AI button anyway. Auth failures surface at generation time instead.

This ticket depends only on ticket 01 — it needs the AI section and the stored
provider, not the generation path. If ticket 02 has already landed, reuse its
command-building and WSL handling rather than duplicating them; if it has not,
build the smallest thing that runs `--version` and let ticket 02's refactor
absorb it.

- [ ] Salva with AI enabled and a present CLI saves normally
- [ ] Salva with AI enabled and a missing CLI is refused with an inline error
      naming the CLI
- [ ] A refused save writes nothing at all, retention included, and leaves the
      previous AI settings untouched
- [ ] On Windows the message points at WSL Mode as the likely cause
- [ ] The check honours WSL Mode, running through the login shell when it is on
- [ ] With AI disabled, Salva runs no check and behaves as before
- [ ] The check times out quickly rather than hanging Salva
- [ ] Authentication is not checked — an installed but unauthenticated CLI saves
      successfully
