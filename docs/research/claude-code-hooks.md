# Research: Claude Code hook events for work start and stop

Ticket: [#23](https://github.com/filpiro/clockodile/issues/23) (part of map [#6](https://github.com/filpiro/clockodile/issues/6)).
Researched 2026-10-24 against the official hooks reference and hooks guide.

Sources:

- [H] Hooks reference: https://code.claude.com/docs/en/hooks (fetched as `hooks.md`)
- [G] Hooks guide: https://code.claude.com/docs/en/hooks-guide (fetched as `hooks-guide.md`)

## Short answer

- **Work starts** at `UserPromptSubmit`. **Work stops** at `Stop` (normal end of turn) or `StopFailure` (API error).
  These are the documented per-turn events [H "Hook lifecycle"].
- **A user interrupt (Esc) fires no stop event.** `Stop` "does not run if the stoppage occurred due to a user interrupt" [H "Stop"; G].
  A crash or kill also has no event. So an open span must be closed by a fallback: the next event in the same `session_id`, `SessionEnd`, `Notification` `idle_prompt`, or a timeout.
- **Session launch only:** `SessionStart` (`source` = `startup`/`resume`/`clear`/`compact`/`fork`) and `SessionEnd`. They mark presence, not work [H "Hook lifecycle", "SessionStart", "SessionEnd"].
- **Subagents:** `SubagentStart`/`SubagentStop` happen inside a turn that is already open. Do not use them as turn boundaries.
- Every event gets `session_id`, `transcript_path`, `cwd`, `hook_event_name` on stdin (or as the POST body for `type: "http"` hooks). Key by `session_id` to handle several sessions at once.
- Configure in `~/.claude/settings.json` (all projects, the right place for a time tracker). `UserPromptSubmit` blocks the prompt for up to 30 s by default. Keep the hook a fast fire-and-forget call, or use `async: true`.

## Event map for time tracking

| Event | Cadence | Meaning for Clockodile | Notes |
| :- | :- | :- | :- |
| `SessionStart` | per session | session opened (not work) | `source`: `startup`, `resume`, `clear`, `compact`, `fork`. Also fires after `/clear` and compaction, so it is not one-per-launch [H "SessionStart"] |
| `UserPromptSubmit` | per turn | **work start** | Also fires for `/loop` and scheduled tasks, a background subagent reporting back, and cross-session messages, not only typed prompts [H "UserPromptSubmit"] |
| `PreToolUse` / `PostToolUse` | per tool call | heartbeat, optional | Fire inside the turn, also inside subagents (with `agent_id`) [H "Hook locations"] |
| `SubagentStart` / `SubagentStop` | inside a turn | nested work, ignore for spans | `SubagentStop` also fires for internal agents (prompt suggestions, `/btw`), where `agent_type` can be `""` [H "SubagentStop"] |
| `Stop` | per turn | **work stop** | Not on user interrupt. Has `background_tasks` and `session_crons`, so you can tell "done" from "paused, waiting for background work" [H "Stop"] |
| `StopFailure` | per turn | **work stop** (error) | Fires *instead of* `Stop` on API error. `error`: `rate_limit`, `overloaded`, `authentication_failed`, ... Output ignored [H "StopFailure"] |
| `Notification` `idle_prompt` | idle | fallback stop signal | About 60 s after Claude finished and you have not typed. Not sent while a background agent runs [H "Notification"] |
| `Notification` `permission_prompt` | waiting | Claude is blocked on the user | About 6 s after a permission prompt with no typing. `PermissionRequest` fires at once [H "Notification"] |
| `SessionEnd` | per session | session closed, close any open span | `reason`: `clear`, `resume`, `logout`, `prompt_input_exit`, `other`. 1.5 s budget [H "SessionEnd"] |

## Stdin JSON

Common fields on every event [H "Common input fields"]:

| Field | Note |
| :- | :- |
| `session_id` | Session identifier. Use it as the span key |
| `prompt_id` | UUID of the prompt being processed. Absent until the first user input. Matches the OpenTelemetry `prompt.id` |
| `transcript_path` | Path to the session `.jsonl`. Written asynchronously, so it can lag the current turn |
| `cwd` | Working directory when the hook runs. Use it to map the session to a project |
| `permission_mode` | Not on every event |
| `hook_event_name` | Event name |
| `agent_id`, `agent_type` | Present when the hook fires inside a subagent or with `--agent` |

Event-specific fields:

- `SessionStart`: `source`, optional `model`, `agent_type`, `session_title`. On `resume`/`fork`: `seconds_since_last_response` and others [H "SessionStart input"].
- `UserPromptSubmit`: `prompt` (full text, pasted content expanded), optional `session_title` [H "UserPromptSubmit input"].
- `Stop`: `stop_hook_active`, `last_assistant_message`, `background_tasks`, `session_crons` [H "Stop input"].
- `StopFailure`: `error`, optional `error_details`, optional `last_assistant_message` (the error string) [H "StopFailure input"].
- `SubagentStop`: `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active` [H "SubagentStop input"].
- `SessionEnd`: `reason` [H "SessionEnd input"].

Examples from [H]:

```json
{"session_id":"abc123","transcript_path":"/Users/.../00893aaf-....jsonl","cwd":"/Users/...","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"Write a function to calculate the factorial of a number"}
{"session_id":"abc123","transcript_path":"/Users/.../00893aaf-....jsonl","cwd":"/Users/...","hook_event_name":"StopFailure","error":"rate_limit","error_details":"429 Too Many Requests","last_assistant_message":"API Error: Rate limit reached"}
{"session_id":"abc123","transcript_path":"/Users/.../00893aaf-....jsonl","cwd":"/Users/...","hook_event_name":"SessionEnd","reason":"other"}
```

## Edge cases

### Several sessions at once

Each Claude Code process runs its own hooks and stamps its own `session_id` on every event. The docs list no cross-session lock or ordering. So Clockodile must keep one open span per `session_id`, and treat overlapping spans as normal (inference from [H "Common input fields"]).
Within one event, all matching hooks run in parallel. An identical handler defined in several settings files runs once [H "Hook handler fields"].
`UserPromptSubmit` can also fire in session A because session B sent it a message [H "UserPromptSubmit"].

### Interrupt (Esc)

`Stop` does not fire on a user interrupt [H "Stop"; G "limitations"]. The docs list no "interrupted" hook event.
Signals you can use instead:

1. The next `UserPromptSubmit` in the same `session_id`: close the old span, then open a new one.
2. `Notification` with matcher `idle_prompt`, about 60 s later, if the user does not type. Whether it fires after an interrupt is not stated. Verify by testing.
3. `SessionEnd` when the user quits.
4. A timeout in Clockodile (for example, no tool event for N minutes).

### Errors

- An API error fires `StopFailure`, not `Stop` [H "StopFailure"]. Treat both as "turn ended".
- A failing hook (exit code other than 0 or 2, or bad JSON) is a non-blocking error. Claude Code goes on and shows a `hook error` notice [H "Exit code output"]. A tracker hook must never exit 2 on `UserPromptSubmit`: exit 2 blocks the prompt.
- If the Clockodile app is not running, the hook must still exit 0 quickly, or it delays or blocks the user.

### Crash with no stop event

The docs promise no event when the process is killed or crashes. `SessionEnd` runs only on a normal end (`/clear`, `/resume`, logout, exit), with a 1.5 s budget [H "SessionEnd"].
So Clockodile must close stale spans itself. Options: a timeout, a check that the session is still alive, or the transcript `.jsonl` mtime at `transcript_path` (see `docs/research/claude-code-logs.md` on branch `research/claude-code-logs`).

## Configuration

Hook locations [H "Hook locations"]:

| File | Scope |
| :- | :- |
| `~/.claude/settings.json` | All your projects. Use this for Clockodile |
| `.claude/settings.json` | One project, committed |
| `.claude/settings.local.json` | One project, not committed |
| Managed policy | Organization. `allowManagedHooksOnly` blocks user hooks |
| Plugin `hooks/hooks.json` | While the plugin is enabled. A possible way to ship the Clockodile hooks |

Hooks from all levels merge. They do not replace each other. Edits are picked up by a file watcher, so no restart is needed [H "Hook locations", "Disable or remove hooks"].
`disableAllHooks: true` turns every hook off [H "Disable or remove hooks"].

Handler types useful here [H "Hook handler fields"]:

- `type: "command"`: the JSON arrives on stdin.
- `type: "http"`: Claude Code POSTs the same JSON to `url`. This could point straight at a Clockodile loopback server (see ADR 0001), with no helper script. The default is `onFailure: "continue"`, so a down app does not block Claude.

Example (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:PORT/claude/start", "timeout": 2 }] }],
    "Stop":             [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:PORT/claude/stop", "timeout": 2 }] }],
    "StopFailure":      [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:PORT/claude/stop", "timeout": 2 }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:PORT/claude/end", "timeout": 1 }] }]
  }
}
```

`PORT` and the paths are placeholders. Nothing in Clockodile serves them yet.

## Timeouts and blocking

From [H "Common fields", "Timeouts", "UserPromptSubmit", "SessionEnd", "Run hooks in the background"]:

| Case | Default timeout | Effect |
| :- | :- | :- |
| `command`/`http`/`mcp_tool` on most events | 600 s | Synchronous hooks block Claude until they finish |
| `UserPromptSubmit` | 30 s | Blocks the prompt from reaching the model. A stuck hook stalls the session. On timeout, output is dropped and the prompt goes on |
| `SessionEnd` | 1.5 s total budget | Raise it with a per-hook `timeout` (up to 60 s) or `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` |
| `async: true` (command only) | not enforced | Runs in the background. Cannot block. In `-p` mode, it is killed at teardown |
| `SessionStart` | runs in the background at launch | The first response waits for it |

Rule for Clockodile: every hook is a fire-and-forget notify. It finishes in milliseconds, sets a short `timeout` (1 to 2 s), and always exits 0.

## Environment note (WSL and Windows)

Claude Code here runs in WSL, so command hooks run in WSL Linux, while Clockodile runs on Windows. Whether `127.0.0.1` reaches a Windows loopback server from WSL depends on the WSL networking mode (mirrored or NAT). This is not covered by the hooks docs. Verify it before choosing `http` hooks.
On native Windows, command hooks use Git Bash, or PowerShell with `"shell": "powershell"` [H "Windows PowerShell tool"].

## Open questions to verify by testing

- Does `Notification` `idle_prompt` fire after an Esc interrupt?
- Does `UserPromptSubmit` fire for `/compact` and other slash commands that do not reach the model? (`UserPromptExpansion` covers skill commands.)
- Can WSL reach the Windows app at `127.0.0.1`?
