# 01 — AI section in Settings

**Blocked by:** None — can start immediately.

**Status:** Done

**What to build:**

The Settings page grows an AI section below the retention field. A user opens it,
turns AI on, picks which local CLI they use, configures its model and effort,
presses Salva, restarts the app, and finds everything exactly as they left it.

The section, top to bottom:

1. An **enable switch**, off by default. Everything below it is inert while off.
2. **Provider selection** — Claude Code, Codex, OpenCode — presented with the
   same segmented control the theme choice uses, so the page reads as one page.
3. **Model and effort on a single row**, whose shape depends on the provider:
   - **Claude Code** — two selects, Sonnet|Opus and Low|Medium|High. Defaults
     Sonnet + High. Only these three effort levels; the CLI's `xhigh` and `max`
     are deliberately not offered.
   - **Codex** and **OpenCode** — two free-text fields each, because their model
     names change faster than this app will be updated. Empty is allowed and
     means "don't pass the flag".

Model and effort are remembered **per provider**. Configuring Claude Code,
switching to Codex, and switching back must not lose the Claude configuration.

All AI settings are Salva-bound, not instant. This differs from the theme, which
persists on change — update the existing comment on the theme block that claims
Salva only concerns retention.

Free-text model and effort values are validated on save against
`^[A-Za-z0-9._/-]+$` (empty passes). These values will later be interpolated
into a shell command string under WSL Mode, so a value carrying a shell
metacharacter is rejected here with a message naming the field.

Persistence is new columns on the existing single-row `Settings` table at schema
version 5, added with `addColumn` in `onUpgrade` exactly as `themeMode` was for
version 4. This is purely additive: **no existing data may be lost**. No table
is recreated, no rows are rewritten, nothing is exported and restored.

Out of scope for this ticket: WSL Mode, the CLI existence check, and any
generation. The section configures; nothing runs yet.

- [x] AI section renders below retention, with the enable switch off by default
- [x] Provider selection uses the same control style as the theme choice
- [x] Claude Code shows model and effort selects on one row, defaulting to
      Sonnet + High
- [x] Codex and OpenCode each show two free-text fields on one row
- [x] Switching provider away and back preserves that provider's model and
      effort
- [x] Salva persists every AI setting; a fresh app launch shows them back
- [x] AI settings do not apply until Salva is pressed
- [x] Free-text model/effort containing a space, quote, semicolon or backtick
      fails validation with a message naming the field; empty passes
- [x] Schema version is 5, upgraded with `addColumn` only
- [x] A schema-4 database with existing Clients, Attività, Sessions, a
      non-default theme and a non-default retention opens at schema 5 with all
      of it intact and the new columns at their defaults — covered by a test
      alongside the existing database tests
