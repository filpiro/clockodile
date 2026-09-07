# 03 — Codex and OpenCode providers

**Blocked by:** 02 — Generate a Note Summary with Claude Code

**Status:** Done

**What to build:**

The other two providers actually generate. A user who picks Codex or OpenCode in
Settings gets the same button, the same dimming, the same replacement, and the
same failure handling as a Claude Code user — only the command and the output
parsing differ.

Both are invoked with no prompt argument so that each reads the prompt from
stdin, and both are asked for machine-readable output.

**Codex** — `codex exec --json -m <model>`, plus `-c
model_reasoning_effort=<effort>` when the effort field is non-empty.

Codex is the one provider needing real parsing, and the accepted fragility of
this feature. It emits a **JSONL event stream**, not a single object. The summary
is the text of the **last** `agent_message` event, not the first. Malformed
lines are skipped rather than aborting the parse. If no line parses at all, fall
back to the trimmed raw stdout.

**OpenCode** — `opencode run --format json -m <model>`, plus `--variant
<effort>` when the effort field is non-empty. Its output is directly usable and
needs no event-stream handling.

For both, an empty model or effort field means the corresponding flag is omitted
entirely rather than passed with an empty value.

Everything else is inherited from ticket 02 unchanged: stdin delivery, WSL Mode
and its quoting, the temporary working directory, the 60-second timeout, kill on
page dispose, and the rule that any failure leaves the Nota exactly as it was.

Note for whoever picks this up: `opencode` on the development machine currently
returns `Token refresh failed: 401`. That is an authentication problem in the
user's own CLI setup, not something this ticket fixes. It will appear as an
ordinary generation-time error, which is the designed behaviour.

- [x] Choosing Codex in Settings and pressing the button produces a Note Summary
- [x] Choosing OpenCode in Settings and pressing the button produces a Note
      Summary
- [x] Codex effort is passed as `-c model_reasoning_effort=<value>`; OpenCode
      effort as `--variant <value>`
- [x] An empty model or effort omits the flag rather than passing it empty
- [x] Failure handling, dimming, WSL Mode and the ten-word gate behave
      identically to Claude Code
- [x] Pure module tests cover: each provider's argument list with model and
      effort set; flag omission when either is empty; Codex's JSONL yielding the
      **last** `agent_message`; malformed Codex lines skipped rather than
      aborting; Codex with no parseable line falling back to trimmed stdout;
      OpenCode's output parsed to its summary; unparseable-with-empty-fallback
      yielding "nothing usable"
