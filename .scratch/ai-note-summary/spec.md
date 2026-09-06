# AI Note Summary

**Status:** ready-for-agent

## Problem Statement

A Note often begins life as a pasted client email. The user copies the whole
message into the Nota field of an Attività because that is where the context
belongs, and because retyping it as a one-liner in the moment is friction they
will not pay while a timer is running.

The cost lands later. The Report is meant to be scanned — one day, one glance,
copied into the portal by hand. Instead it carries paragraphs of greeting,
signature, and thread quoting, and the actual work being billed is buried
somewhere in the middle. Every Note has to be re-read and mentally condensed at
exactly the moment the user wants to be done for the day.

The user already has coding-agent CLIs installed and authenticated on this
machine for their own work. The condensing is a job a model does well and a job
the user does not want to do fifteen times a week.

## Solution

The Nota field becomes a text area, sized for a pasted email rather than a
one-liner. When AI is enabled in Settings, a single icon button sits in its
bottom-right corner.

With at least ten words in the field, the button is live. Pressing it dims the
field to 50% opacity and locks it while a local CLI is asked to reduce the text
to one Italian line of at most fifteen words. On success the field's entire
contents are replaced by that line and interaction is restored. On any failure —
non-zero exit, timeout, blank result — the text is left exactly as it was and
the CLI's own error is shown.

The replacement is final. The pasted email is not kept anywhere and there is no
undo. The original is still in the user's mail client, which is the copy that
matters.

Settings gains an AI section: an off-by-default switch, a provider choice
(Claude Code, Codex, OpenCode) presented like the theme choice, per-provider
model and effort controls on one row, and — on Windows only — a WSL Mode
switch. Saving verifies the chosen CLI actually exists and refuses the save if
it does not.

## User Stories

1. As a user pasting a client email into a Nota, I want the field to be a text
   area several lines tall, so that I can see what I pasted instead of a
   single-line sliver of it.
2. As a user with a long Nota, I want the text area to stop growing past a
   sensible height and scroll instead, so that the Salva button is never pushed
   off screen.
3. As a user who has pasted an email into a Nota, I want one button that
   rewrites it as a short line, so that I do not have to summarise it myself.
4. As a user, I want that button to be an icon in the bottom-right corner of the
   field, so that it is where the text ends and does not take up a row of its
   own.
5. As a user, I want my typed text never to run underneath the button, so that
   the last thing I typed stays readable.
6. As a user who has never turned AI on, I want no AI button anywhere in the
   Nota field, so that the app looks exactly as it did before.
7. As a user with AI enabled and a short Nota, I want the button visible but
   disabled, so that I can see the feature exists and understand it is waiting
   on more text.
8. As a user, I want the button to become enabled only once the Nota holds at
   least ten words, so that I am not offered a summary of something already
   shorter than a summary.
9. As a user typing into the Nota, I want the button to enable and disable as I
   cross the ten-word line, so that its state always matches what I have
   written.
10. As a user who has pressed the button, I want the text area to dim and stop
    accepting input, so that I can see the app is working and cannot edit text
    that is about to be replaced.
11. As a user waiting on a summary, I want the whole field restored to full
    opacity and editable the moment the work finishes, so that I can correct the
    result immediately.
12. As a user, I want the generated line to replace the entire contents of the
    Nota, so that the pasted email is gone and only the note remains.
13. As a user, I want the generated line in Italian, so that it matches the rest
    of my notes and the portal I paste into.
14. As a user, I want the generated line capped at fifteen words, so that it fits
    a time-tracking note field and reads as a note rather than a paragraph.
15. As a user, I want the summary to state the core request or feedback with no
    greeting, filler, or quoting, so that what survives is the part I am billing
    against.
16. As a user whose CLI fails, I want my Nota text left completely untouched, so
    that a failed generation can never cost me the email I pasted.
17. As a user whose CLI fails, I want to see the CLI's own first line of error,
    so that I can tell an authentication problem from a missing binary without
    opening a terminal.
18. As a user whose CLI returns nothing at all, I want that treated as a failure
    rather than as an empty summary, so that a silent CLI cannot wipe my text.
19. As a user whose CLI hangs, I want the attempt abandoned after a fixed
    timeout, so that a stuck process does not lock the field forever.
20. As a user who closes the Attività page mid-generation, I want the CLI process
    killed, so that nothing keeps running for a result nobody will read.
21. As a user creating a brand-new Attività, I want the same AI button in the
    Nota field, so that the feature is not limited to editing existing ones.
22. As a user, I want an AI section in Settings, so that all of this is
    configured in one place alongside theme and retention.
23. As a user, I want AI off by default, so that installing an update never
    changes how the app behaves until I ask it to.
24. As a user, I want to choose between Claude Code, Codex, and OpenCode, so
    that I can use whichever CLI I already have set up.
25. As a user, I want the provider chosen the same way the theme is chosen, so
    that the Settings page reads as one page rather than a pile of unrelated
    widgets.
26. As a Claude Code user, I want to pick model and effort from fixed lists, so
    that I cannot mistype a value the CLI will reject.
27. As a Claude Code user, I want Sonnet with High effort chosen for me, so that
    the feature works without me configuring anything.
28. As a Codex user, I want to type the model and effort myself, so that I can
    use a model released after this app was last updated.
29. As an OpenCode user, I want to type the model and effort myself, so that I
    can point at any provider/model combination my CLI knows about.
30. As a user who configures Claude Code, switches to Codex, and switches back, I
    want my Claude Code model and effort still there, so that experimenting with
    another provider does not cost me my setup.
31. As a user, I want model and effort side by side on one row, so that the
    section stays compact.
32. As a Windows user whose CLIs live inside WSL, I want a WSL Mode switch, so
    that the app can reach binaries that exist on no Windows PATH.
33. As a macOS user, I want no WSL switch at all, so that I am not shown a
    setting that cannot mean anything on my machine.
34. As a user saving Settings, I want the app to check the chosen CLI actually
    exists, so that I find out now rather than the first time I press the AI
    button.
35. As a user whose CLI is not found, I want the save refused with a message
    naming the CLI, so that I know exactly which binary is missing.
36. As a Windows user who enabled AI but forgot WSL Mode, I want the failed check
    to point me at that, so that the most likely cause is the first thing I try.
37. As a user, I want a failed CLI check to leave my previous AI settings
    untouched, so that a rejected save does not half-apply.
38. As a user typing a model name with a shell metacharacter in it, I want the
    save rejected with a clear message, so that I am told my input is invalid
    rather than having it silently mangled.
39. As a user of this app, I want a model name I type in Settings to be incapable
    of executing anything on my machine, so that a settings field is not a shell.
40. As a user pasting an email full of quotes, newlines, and backticks, I want it
    summarised correctly, so that ordinary email punctuation is not a failure
    mode.
41. As a user pasting a very long email, I want no length limit imposed by how
    the app talks to the CLI, so that a long thread works the same as a short
    one.
42. As a user, I want the CLI run somewhere with nothing of mine in it, so that
    an agentic tool asked to summarise text has no reason to go reading my files.
43. As an existing user upgrading, I want every Client, Attività, and Session I
    already have to survive untouched, so that adding an AI section never costs
    me my history.
44. As an existing user upgrading, I want my current theme and retention settings
    preserved, so that the new columns do not reset what I already configured.
45. As a user, I want the app to hold no API key, so that there is no credential
    sitting next to my time entries.
46. As a user, I want the app to make no network connections of its own, so that
    it stays the local-only tool it has always been.

## Implementation Decisions

### Where the boundary sits

One new feature module for AI note summarisation, split into a **pure part** and
a **thin impure part**:

- **Pure**: builds the command to run, and parses a provider's stdout into a
  result string. No `Process`, no `Platform`, no I/O. Everything interesting
  lives here. This is the single test seam.
- **Impure**: spawns the process, writes stdin, collects stdout/stderr, enforces
  the timeout, kills on cancel. Kept as small as it can be — it takes a built
  command, returns raw output, and makes no decisions.

The pure part exposes two operations:

- Given provider, model, effort, WSL on/off, and a working directory, produce
  the executable name and its argument list. Under WSL this collapses the
  provider command into a single shell string carried as one argument.
- Given provider and raw stdout, produce the summary line or `null` for "no
  usable result".

Prior art for this shape is the Report feature, where `normalize.dart` holds the
pure rounding rules and the view does the rest.

### Prompt delivery

The prompt is always written to the child process's **stdin** and closed. It is
never an argument and never part of a shell string. This removes the command
line length limit and removes the need to escape the user's pasted email at all.

The prompt template is a constant in the AI module:

```
Summarize the following email into the shortest possible italian line for a
time-tracking note field (hard cap: 15 words, fewer is better—don't pad to
reach the limit). Capture the core request or feedback. No greetings, no
filler, no quotes—just the essence as a plain statement.

Email:
"""
{text}
"""
```

`{text}` is replaced with the Nota's current contents.

### Provider command contracts

All three are invoked with no prompt argument so that each reads stdin, and each
is asked for machine-readable output.

- **Claude Code** — `claude -p --output-format json --model <alias> --effort
  <level>`. Model alias is `sonnet` or `opus`; effort is `low`, `medium`, or
  `high`. Result is a single JSON object; the summary is its `result` field.
- **Codex** — `codex exec --json -m <model>`, plus `-c
  model_reasoning_effort=<effort>` when the effort field is non-empty. Output is
  a JSONL event stream; the summary is the last `agent_message` event's text.
  If no line parses, fall back to trimmed raw stdout.
- **OpenCode** — `opencode run --format json -m <model>`, plus `--variant
  <effort>` when the effort field is non-empty.

Empty model or effort means the corresponding flag is omitted entirely rather
than passed empty.

### WSL Mode

Windows only; the switch is not rendered on other platforms and the stored value
is ignored there.

- **Off** — the executable is spawned directly with an argument list. No shell,
  no quoting.
- **On** — the executable is `wsl.exe`, and the arguments are
  `--cd <temp dir> -e bash -lc <command string>`, where the command string is
  the provider command assembled as text.

The login shell is not optional. `wsl.exe -e claude` fails with
`execvpe(claude) failed: No such file or directory` because the CLIs live under
`~/.local/bin`, `~/.nvm/...`, and `~/.opencode/bin`, all of which are placed on
PATH by the shell's own startup files. `bash -lc` is what makes them findable.
See ADR 0002.

### Injection defense

Building a shell string from user-typed model and effort values is an injection
surface. It is closed twice:

- **Validation at save.** Model and effort text fields must match
  `^[A-Za-z0-9._/-]+$` or be empty. Anything else fails validation with a
  message naming the field. This exists to give an honest error.
- **Quoting at build.** Every interpolated value in a WSL command string is
  wrapped in single quotes with embedded `'` escaped as `'\''`. This is the
  actual defense, and it is exercised by tests independently of the validator.

The prompt is exempt from both, because it never reaches the command line.

### Process execution

- Working directory is a temporary directory, not the app's own. These are
  agentic CLIs; they are given nothing interesting to find.
- Hard timeout of 60 seconds, after which the process is killed and the attempt
  reported as a failure.
- The process is killed if the Attività page is disposed while a generation is
  in flight.
- Exit code non-zero, timeout, or a blank/whitespace-only parsed result are all
  the same outcome: failure, Nota untouched, first line of stderr surfaced.
- A long result is accepted as-is. The fifteen-word cap is the model's
  instruction; truncating client-side would cut sentences in half.

### Settings persistence

New columns on the existing single-row `Settings` table, schema version 5,
added with `addColumn` in `onUpgrade` exactly as `themeMode` was for version 4.
This is purely additive — no table is recreated, no rows are rewritten, no data
is moved, and no export/restore step is needed. Existing Clients, Attività,
Sessions, theme, and retention are untouched.

Columns:

- AI enabled — boolean, default false
- Provider — text, default `claude`
- WSL Mode — boolean, default false
- Model and effort **per provider**: six text columns, so that switching
  provider and back preserves each one's configuration. Claude's default to
  `sonnet` and `high`; the other four default to empty.

### Settings UI

Added below the existing retention field, in this order:

1. Enable switch (off by default). The rest of the section is disabled or hidden
   while off.
2. Provider selection, using the same segmented control the theme uses.
3. Model and effort on one row. Claude Code renders two selects (Sonnet|Opus and
   Low|Medium|High). Codex and OpenCode each render two free-text fields whose
   values pass through to the command.
4. WSL Mode switch — Windows only, last row of the section.

All AI settings are **Salva-bound**, not instant. This differs from the theme,
which persists on change; the existing comment on the theme block saying "Salva
only concerns retention" is updated accordingly. Salva-binding is required
because the CLI check needs one moment where the whole configuration is
consistent.

Claude's effort select exposes only Low, Medium, and High. The CLI also accepts
`xhigh` and `max`; they are deliberately not offered.

### CLI check on save

On Salva, before persisting anything, run the chosen provider's binary with
`--version` — through WSL if WSL Mode is on — with a short timeout. A non-zero
exit or a spawn failure blocks the entire save with an inline error naming the
CLI. Nothing is written, including the non-AI settings.

Existence is checked; authentication is not. A real generation would make Salva
take tens of seconds and the result would be stale by the next press of the AI
button anyway. Auth failures surface at generation time instead.

### Nota field

Text area with a minimum of three lines and a maximum of eight — it grows while
typing, then scrolls. The AI button is an overlay positioned at the field's
bottom-right inside its border, not a `suffixIcon` (which cannot sit at the
bottom). The field's content padding reserves space so text never runs under the
button.

Word count for the ten-word gate is whitespace-separated tokens of the trimmed
text.

## Testing Decisions

A good test here describes behaviour a user or caller can observe and says
nothing about how it is achieved. It should survive the module being rewritten
internally. Concretely: no test spawns a process, no test asserts on a private
helper, and no test asserts on widget internals.

**One seam is tested: the pure part of the AI module.** Everything that can be
got wrong lives there, and it is reachable with plain function calls. Prior art
is `test/normalize_test.dart` and `test/board_geometry_test.dart`, which test
the Report's pure rules directly with no widget tree and no database.

Command building:

- Each provider, with model and effort set, produces the expected executable and
  argument list.
- Empty model or effort omits the flag rather than passing an empty value.
- Claude's model alias and effort level map to the documented CLI values.
- Codex's effort becomes `-c model_reasoning_effort=<value>`; OpenCode's becomes
  `--variant <value>`.
- With WSL Mode on, the executable is `wsl.exe` and the arguments carry
  `--cd`, `-e`, `bash`, `-lc`, and one command string.
- With WSL Mode off, no shell appears anywhere in the result.
- Quote escaping: a value containing a single quote is escaped as `'\''` in the
  WSL command string. A value containing `; rm -rf ~` cannot terminate the
  quoted argument. These are asserted on the built string directly, independent
  of the save-time validator, because the quoting is the real defense.

Output parsing:

- Claude's JSON object yields its `result` field.
- Codex's JSONL stream yields the **last** `agent_message`, not the first.
- Codex's malformed lines are skipped rather than aborting the parse.
- Codex with no parseable line at all falls back to trimmed raw stdout.
- Empty, whitespace-only, and unparseable-with-empty-fallback outputs all yield
  the "no usable result" outcome rather than an empty string.

Model/effort validation:

- Values matching `^[A-Za-z0-9._/-]+$` pass; empty passes; values containing
  spaces, quotes, semicolons, or backticks fail.

Database migration, following the prior art in `test/db_test.dart`:

- A database at schema 4 with existing Clients, Attività, Sessions, a
  non-default theme, and a non-default retention opens at schema 5 with all of
  that data intact and the new columns at their defaults.

Not tested: process spawning, timeout behaviour, the CLI existence check,
opacity and disabled state of the text area, and button enable/disable. These
need either a real CLI or a widget tree, and the logic behind each is thin
enough that the test would assert on the framework rather than on us.

## Out of Scope

- **Any undo of a generation.** No pre-generation copy is kept, in memory or in
  the database, and no undo control is offered. Explicitly declined: the source
  email exists in the user's mail client.
- **A second column for the original text.** The Note is one field and stays one
  field.
- **API-key providers.** No HTTP call to any model API, no key storage, no
  keychain dependency. See ADR 0002.
- **A bundled local model.**
- **Configuring the prompt.** The template is a constant. No settings field, no
  per-Client variation.
- **Summarising anything other than a Nota.** Attività names, Client names, and
  the Report are untouched.
- **Bulk or automatic generation.** One Nota, one button press, one result.
  Nothing runs on save, on stop, or in the background.
- **Streaming the result.** The field stays dimmed until the whole answer is in.
- **A progress indicator beyond the dimming.** No spinner, no percentage, no
  elapsed timer.
- **Checking CLI authentication at save time.** Existence only.
- **A WSL distribution picker.** `wsl.exe` gets the default distribution.
- **Claude's `xhigh` and `max` effort levels.**
- **A model list fetched from the CLIs.** Claude's list is hardcoded; the other
  two are free text.
- **Client-side truncation of a long result.**
- **Retrying a failed generation automatically.**

## Further Notes

The three CLIs on the development machine exist **only inside WSL** — Windows
`Get-Command` finds none of them. WSL Mode is therefore not an edge case here;
it is the working configuration, and the save-time CLI check will fail for every
provider until it is switched on. That is the intended behaviour, and story 36
exists so the message points at it.

Codex is the one provider needing real parsing. Claude and OpenCode return
directly usable structured output; `codex exec --json` emits an event stream
whose answer must be dug out. This is the accepted fragility of the feature and
the reason the parser is tested harder than anything else.

`opencode` on the development machine currently returns `Token refresh failed:
401`. This is an authentication problem in the user's own CLI setup, not
something this feature fixes or detects — it will appear as a generation-time
error, which is the designed behaviour.

Domain terms introduced by this feature — **Note Summary**, **AI Provider**,
**WSL Mode** — are defined in `CONTEXT.md`. The provider decision, the
login-shell constraint, and the accepted limits are recorded in ADR 0002.
