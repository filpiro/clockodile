# Research: read Claude Code logs from the Windows app

Ticket: [#7](https://github.com/filpiro/clockodile/issues/7) (map [#6](https://github.com/filpiro/clockodile/issues/6)). Date: 2026-10-19.

## Short answer

Yes. The Windows app can read the WSL transcripts with plain `dart:io` through
`\\wsl.localhost\<distro>\home\<user>\.claude\projects`. Listing and stat calls are fast.
Reading every byte is slow (about 7 MB/s), so the importer must be incremental:
remember a byte offset per file and read only appended bytes.
The JSONL format is internal to Claude Code and not documented, so the parser must be tolerant.
Idle detection can use turn boundaries (human prompt to end of turn) instead of a fixed 30-minute gap.

## Sources

- [S1] Measurements on this machine (Windows 11, WSL 2, distro `Ubuntu`, Claude Code 2.1.304, Dart 3.13.5 on Windows). Read-only scans; no personal content recorded.
- [S2] Claude Code docs, `.claude` directory reference: https://code.claude.com/docs/en/claude-directory ("Cleaned up automatically" section).
- [S3] Claude Code docs, settings: https://code.claude.com/docs/en/settings ("On Windows, `~/.claude` means `%USERPROFILE%\.claude`", and `CLAUDE_CONFIG_DIR`).
- [S4] Microsoft Learn, Working across file systems: https://learn.microsoft.com/en-us/windows/wsl/filesystems
- [S5] `~/.claude/reports/report.py` (the current 30-minute gap script).

## 1. Access from Windows

| Check | Result | Source |
|---|---|---|
| `Directory(r'\\wsl.localhost\Ubuntu\home\filippo\.claude\projects').exists()` | `true` | S1 |
| Recursive `Directory.list` of 602 entries (`.jsonl`) | 1.4 s | S1 |
| `File.stat()` on all 601 files | 1.2 s | S1 |
| `RandomAccessFile.setPosition` + read 4 KB at file tail | 42 ms | S1 |
| Read all bytes of all files (457 MB) from PowerShell | 65 s (about 7 MB/s) | S1 |
| List files modified in the last 24 h (15 files) from PowerShell | 4.4 s | S1 |
| `Directory.watch(recursive: true)` on the UNC path | No error, but no event seen in an 8 s window while sessions were writing. Treat as unreliable. | S1 |
| `Directory(r'\\wsl.localhost\NoSuchDistro\home').exists()` | Throws `PathNotFoundException` (OS error 67, network name not found). It does **not** return `false`. | S1 |

Consequences:

- Wrap every UNC call in `try/catch` on `FileSystemException`. A missing distro or a stopped WSL surfaces as an exception.
- Use polling (for example every 1 to 5 minutes, or on demand) instead of `Directory.watch`.
- Incremental import: store `(path, size, mtime, offset)` per file. Skip files whose size and mtime did not change. Read from `offset` to end. Ignore a trailing line without `\n` (the writer may still be appending it); re-read it next time.
- If a file got smaller than the stored offset, it was rewritten or replaced: re-read it fully.
- Microsoft recommends against cross-OS file work for performance and calls the WSL file system the `\\wsl$` drive [S4]. Our access is read-only and incremental, so the slow path is only the first full import.

### WSL not running

Not tested destructively (stopping WSL would kill this research session).
Microsoft documents `\\wsl$` as the way to see "all of your available Linux distributions" from Explorer [S4]; it does not state whether access starts a stopped distro.
Unverified expectation: access through the 9P/Plan 9 redirector starts the distro on demand, with a delay of a few seconds. The importer must tolerate a slow first call and an exception, and must never block the UI on it. Verify during the build with `wsl --shutdown` and a manual import.

### Distro and user discovery

- Enumerating `\\wsl.localhost\` or `\\wsl$\` as a directory **fails** from PowerShell ("path does not exist") [S1]. Do not rely on listing the UNC root.
- The registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` lists one subkey per distro with `DistributionName`, and the parent key holds `DefaultDistribution` (a GUID) [S1]. On this machine: `Ubuntu` (default) and `docker-desktop`.
- `wsl.exe -l -q` also lists distros, but its output is UTF-16LE; decode it explicitly.
- The Linux user name is not in the registry in a simple form. Simplest: probe `\\wsl.localhost\<distro>\home\*\.claude\projects` and pick the one that exists; let the user override it in settings.
- Recommendation: a settings field with the full log folder path, pre-filled from the default distro plus probing. This matches the open item "Settings for the log source" in #6.

## 2. Logs on the Windows side too

- Claude Code on Windows stores data under `%USERPROFILE%\.claude` [S3], so a native Windows Claude Code would write `%USERPROFILE%\.claude\projects\...`.
- `CLAUDE_CONFIG_DIR` moves the whole folder, including session history [S3].
- On this machine `%USERPROFILE%\.claude\projects` does not exist and `claude` is not on the Windows `PATH` [S1].
- Recommendation: support a list of log roots (WSL path plus optional Windows path). Sessions are keyed by `sessionId`, so two roots never collide.

## 3. File layout and size

From [S2] and [S1]:

| Path under `~/.claude/projects/` | Contents |
|---|---|
| `<project>/<session>.jsonl` | Main transcript. File name equals `sessionId` in 100% of records checked [S1]. |
| `<project>/<session>/subagents/*.jsonl` | Subagent transcripts (119 of 601 files here) [S1, S2]. |
| `<project>/<session>/tool-results/` | Large tool outputs, not JSONL. |
| `<project>/<session>.orphaned-<ts>-<suffix>.jsonl`, `<session>.jsonl.superseded-<ts>` | Set-aside older transcripts [S2]. The first form matches `*.jsonl`: exclude it, or it double counts. None present here. |

- `<project>` is the cwd with `/` and `.` replaced by `-` (for example `/home/filippo/.claude` becomes `-home-filippo--claude`). This mapping is lossy; use the `cwd` field, not the folder name.
- Retention: Claude Code deletes transcripts older than `cleanupPeriodDays`, default **30 days** [S2]. Not overridden on this machine. The app must import at least every few weeks or history is lost; it must keep its own copy of derived activity.
- Size here: 35 project folders, 601 files, 471 MB, 110,742 lines, 0 unparseable lines. Median file 377 KB, largest 36 MB [S1]. A single line can be large (tool results), so read with a streaming line splitter, not one big `readAsString`.

## 4. Record types and fields

Counts across all local files [S1]. "ts" means the record has `timestamp`; "cwd" means it has `cwd`.

| `type` | Count | ts | cwd | Use for time tracking |
|---|---:|:-:|:-:|---|
| `attachment` | 38,338 | yes | yes | No: context injected by Claude Code (reminders, environment, hook output). Written at session start too. |
| `assistant` | 24,065 | yes | yes | Yes: agent working. |
| `user` | 15,935 | yes | yes | Yes, but split by kind (below). |
| `system` | 2,453 | yes | yes | `subtype: turn_duration` marks end of turn with `durationMs`. |
| `queue-operation` | 962 | yes | no | Prompts queued while the agent was busy. |
| `last-prompt`, `ai-title`, `mode`, `permission-mode`, `agent-name`, `bridge-session`, `atis-latch`, `cost-state`, `api-request-blob`, ... | many | no | no | No timestamp: ignore for timing. `ai-title.aiTitle` is a useful session label. |
| `file-history-snapshot` / `file-history-delta` | 1,613 | partly | no | No. |
| `continued-in` | 16 | yes | no | `continuedInSessionId` links a session to its continuation. |

Common envelope fields on `user` / `assistant` / `attachment` / `system`:
`type`, `uuid`, `parentUuid`, `timestamp` (ISO 8601 UTC, `Z`), `sessionId`, `cwd`, `gitBranch`, `version`, `entrypoint`, `userType`, `isSidechain`, `agentId`, `slug`, `sessionKind`.

Observed values [S1]:

- `entrypoint`: `cli` (95%), `sdk-py` (5%, scripted runs).
- `userType`: always `external`.
- `sessionKind`: `bg` on background sessions, absent otherwise.
- `isSidechain: true` and `agentId`: subagent records.

### `user` records by kind

| Kind (content + flags) | Count | Meaning |
|---|---:|---|
| `tool_result` with `toolUseResult` | 13,445 | Tool output fed back to the model. Agent activity, not human. |
| string content, `origin.kind = "human"` | about 1,100 | **Human prompt.** |
| string/text content, no `isMeta`, no `origin` | about 400 | Human prompt from older versions or SDK. `promptSource` tells the source: `typed`, `suggestion_accepted`, `queued`, `sdk`, `system`. |
| `isMeta: true` | about 900 | Injected by Claude Code (slash command expansion, caveats). Not human. |
| `origin.kind = "task-notification"` or `"peer"` | about 65 | Background task or other agent woke the session. Not human. |
| `isCompactSummary: true` | 8 | Context compaction. Not human. |

## 5. Activity versus idle

What the logs show [S1]:

- An open but unused session writes **nothing** while idle. There is no heartbeat.
- Opening a session writes `attachment` records (environment, skills, hooks) with a timestamp and `cwd`, even if no prompt follows. 11 of 482 main sessions had no human prompt at all.
- Turn length: `system/turn_duration.durationMs` median 34 s, p90 6 min (1,111 turns).
- Human think time before a prompt and reading time after a turn are invisible in the logs.

Why `report.py` is off [S5]: it takes every record with `timestamp` and `cwd` as activity and merges points closer than 30 minutes.
So a session opened and never used counts as a point, and attachments, scheduled task fires and background notifications count like human work.
A 29-minute coffee break inside one interval counts as work; a long agent turn with no records for 30 minutes would split.

Proposed rule (to decide in the spec, not here):

1. **Human prompt** = `type == "user"`, not `isMeta`, not `isSidechain`, no `toolUseResult`, not `isCompactSummary`, content is a string or has a `text` block, and `origin.kind` absent or `"human"`.
2. **Turn** = from a human prompt to the next `system` record with `subtype == "turn_duration"` in the same session (or to the last `assistant` record before the next human prompt). Agent work in between, including subagents, is active time.
3. **Human time** around a turn: add a fixed lead-in before each prompt (time to write it) and a read-out after each turn end, both capped (for example 5 to 10 minutes). Gaps longer than lead-in plus read-out are idle.
4. Ignore records that are not triggered by a human: `attachment`, `queue-operation`, `scheduled_task_fire`, task notifications, `entrypoint == "sdk-py"` and `sessionKind == "bg"` (or tag them as "automated" so the user decides).
5. Subagent files (`isSidechain`, `subagents/`) overlap the parent turn; use them to extend the turn, never to add parallel time.

## 6. Identity fields

| Need | Field | Notes |
|---|---|---|
| Session | `sessionId` (equals file stem) | Present on nearly every record type. |
| Folder | `cwd` | Linux path, for example `/home/...` or `/mnt/c/Users/...`. Map `/mnt/<drive>/x` to `<DRIVE>:\x` when matching Windows folders. |
| Branch | `gitBranch` | Useful hint for project mapping. |
| Title | `ai-title.aiTitle` | Session label for the UI. |
| Continuation | `continued-in.continuedInSessionId` | Links sessions. |

`cwd` can change inside one session: 142 of 477 sessions had more than one `cwd`, 141 of them only into subfolders of the first `cwd` [S1].
Map per record (or per turn), not per session, or use the session's first `cwd` with a "subfolder belongs to parent" rule.

## Open points

- Behavior when WSL is stopped (does UNC access start it, and how long it takes): verify in the build.
- `Directory.watch` over `\\wsl.localhost`: no events seen; polling assumed.
- The JSONL schema is internal and undocumented; each record carries `version`, and fields can change between Claude Code versions. The parser must skip unknown types and missing fields without failing.
