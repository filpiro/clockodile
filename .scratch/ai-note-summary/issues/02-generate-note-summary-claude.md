# 02 — Generate a Note Summary with Claude Code

**Blocked by:** 01 — AI section in Settings

**Status:** ready-for-agent

**What to build:**

The feature itself, end to end, for one provider. A user pastes a client email
into an Attività's Nota, presses one icon, and the paste is replaced by a single
Italian line of at most fifteen words.

**The Nota field** becomes a text area — minimum three lines, maximum eight, so
it grows while typing and then scrolls rather than shoving Salva off screen. An
icon button sits in its bottom-right corner, inside the border; the field's
content padding reserves room so typed text never runs underneath it. A
`suffixIcon` will not do this — it sits vertically centred.

**Button states:** absent entirely when AI is off in Settings, so a user who
never enables the feature sees the app exactly as before. Visible but disabled
when AI is on and the Nota holds fewer than ten whitespace-separated words, and
it enables and disables live as the user crosses that line. Present in both
create and edit mode.

**Pressing it** dims the text area to 50% opacity and locks it against input,
then runs the configured CLI. On success the entire contents of the Nota are
replaced by the returned line and the field is restored to full opacity and
interaction. The replacement is final — nothing is kept, there is no undo, and
no second column is added. The original email is in the user's mail client.

**The prompt** always travels over the child process's **stdin**, closed after
writing. Never an argument, never part of a shell string. This removes the
command-line length limit and removes any need to escape the user's pasted text.
Template, with `{text}` replaced by the Nota's contents:

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

**Claude Code is invoked** as `claude -p --output-format json --model <sonnet|
opus> --effort <low|medium|high>` — no prompt argument, so it reads stdin. The
summary is the `result` field of the single JSON object it prints.

**WSL Mode** ships in this ticket, because without it nothing runs on the
development machine — all three CLIs live inside WSL there and Windows finds
none of them. Add the Windows-only switch as the last row of the Settings AI
section; it is not rendered on other platforms.

- With WSL off, the binary is spawned directly with an argument list. No shell,
  no quoting anywhere.
- With WSL on, the executable is `wsl.exe` and the arguments are
  `--cd <temp dir> -e bash -lc <command string>`.

The login shell is not optional: `wsl.exe -e claude` fails with
`execvpe(claude) failed: No such file or directory`, because the CLIs sit under
paths that the shell's own startup files put on PATH. See ADR 0002.

Because WSL Mode builds a command **string**, every interpolated value is
single-quoted with embedded `'` escaped as `'\''`. The validator from ticket 01
gives the honest error; this quoting is the actual defense and must hold on its
own.

**Execution rules:** working directory is a temporary directory, never the app's
own — these are agentic CLIs and are given nothing interesting to find. Hard
timeout of 60 seconds, then the process is killed. The process is also killed if
the Attività page is disposed mid-generation. A non-zero exit, a timeout, or a
blank/whitespace-only result are all the same outcome: the Nota is left exactly
as it was and the CLI's first line of stderr is surfaced. A long result is
accepted as-is — the fifteen-word cap is the model's instruction, and truncating
client-side would cut sentences in half.

**Structure:** split the AI module into a pure part and a thin impure part. The
pure part builds the command (executable plus argument list, given provider,
model, effort, WSL flag and working directory) and parses raw stdout into a
result or "nothing usable". It touches no `Process` and no `Platform`. The
impure part takes a built command, spawns it, writes stdin, collects output,
enforces the timeout, and makes no decisions. Prior art for this shape is the
Report feature, where the pure rounding rules live apart from the view.

The pure part is the single test seam. Nothing in this ticket's tests spawns a
process.

- [ ] Nota renders as a 3–8 line text area that grows then scrolls
- [ ] Icon button sits at the field's bottom-right, inside the border, with text
      never running under it
- [ ] Button is absent when AI is disabled in Settings
- [ ] Button is visible but disabled below ten words, and toggles live while
      typing
- [ ] Button is present in both create and edit mode
- [ ] Pressing it dims the field to 50% and blocks input until the attempt ends
- [ ] Success replaces the whole Nota and restores opacity and interaction
- [ ] The prompt reaches the CLI over stdin and never appears on the command
      line
- [ ] An email containing quotes, newlines and backticks summarises correctly
- [ ] WSL Mode switch appears on Windows only, as the last row of the AI section
- [ ] With WSL on the command runs through `bash -lc`; with WSL off no shell is
      involved
- [ ] Non-zero exit, 60s timeout, and blank result each leave the Nota untouched
      and show the CLI's first stderr line
- [ ] Leaving the page mid-generation kills the process
- [ ] The CLI runs with a temporary working directory
- [ ] Pure module tests cover: Claude's argument list for each model/effort
      combination; the WSL command shape (`wsl.exe`, `--cd`, `-e`, `bash`,
      `-lc`, one command string); absence of any shell when WSL is off; single
      quotes escaped as `'\''`; a value containing `; rm -rf ~` unable to
      terminate its quoted argument; the `result` field extracted from Claude's
      JSON; empty and whitespace-only output yielding "nothing usable" rather
      than an empty string
