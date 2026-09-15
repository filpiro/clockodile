# 04 — Write the handoff spec, ADR 0003 and the CONTEXT additions

**Type:** task
**Blocked by:** 00, 01, 02, 03, 05, 07, 08
**Status:** resolved

## Question

Nothing left to decide — write the destination down.

Three artifacts:

1. **`.scratch/local-llama-provider/spec.md`** — the build session's brief.
   Follows this repo's existing spec convention (see
   `.scratch/ai-note-summary/spec.md`). Must cover:
   - the `AiProvider` interface and the normalized request/result models, with
     `AiProviderKind` renamed and every call site listed
     (`entry_edit_page.dart`, `settings_view.dart`, `test/ai_command_test.dart`,
     `test/settings_ai_test.dart`);
   - the migration order from spec §23 — wrap the CLI providers first, prove no
     behaviour change, then add the local one;
   - `LlamaRuntimeManager` / process lifecycle / port probing / PID file;
   - the install flow: Italian confirm copy with the real byte figure, modal
     progress, checksum, failure and cancel paths;
   - `AiCubit`, `LocalAiStatus`, the status strip, the Riassumi button states;
   - `AiConfig` with every constant and its value;
   - the JSON Schema request body and the parser split;
   - what Settings looks like once the CLI providers are hidden, including the
     delete-model button;
   - the test plan from spec §21, minus the out-of-scope checklist cases, and
     honest about which integration tests can run without a 1.4 GB download in
     CI.
2. **`docs/adr/0003-local-model-provider.md`** — why the default AI path moved
   from a coding-agent CLI to a bundled-at-runtime local model, and why the CLI
   providers survive hidden rather than deleted. Supersedes nothing in ADR 0002;
   amends its consequences.
3. **`CONTEXT.md`** — Language entries for **AI Provider** (the interface),
   **AI Provider Kind** (the enum), **Local Model**, and **Summary**, each with
   its `_Avoid_` list, matching the file's existing style.

Definition of done: a build session can start from `spec.md` alone and never need
to reopen a decision. Delete the ticket list's "not yet specified" leftovers from
`map.md` or promote them into the spec.

## Answer

Written 2026-09-15. The three artifacts:

- [`spec.md`](../spec.md) — `Status: ready-for-agent`
- [`docs/adr/0003-local-model-provider.md`](../../../docs/adr/0003-local-model-provider.md)
- `CONTEXT.md` — added **AI Provider Kind** and **Local Model**, rewrote **AI
  Provider** as the interface, and updated **Note Summary**, **WSL Mode** and the
  example dialogue.

**Found while writing, and already in the spec:**

- `test/migration_test.dart` also references `AiProvider` and was missing from
  the call-site list.
- `SettingsView._save` writes every `ai*` column. Left as is, Salva would
  overwrite the `aiEnabled` value the switch now persists immediately. The spec
  strips `_save` down to retention.
- The strip sits above the `Navigator`, so it cannot `showDialog` from its own
  context. The spec gives `MaterialApp` a `navigatorKey`.
- Charting's "~1,4 GB" is really **1,3 GB** (18,423,427 + 1,282,439,264 bytes).
  The disk-full text uses the computed size.
- The app still builds for macOS (`Platform.isMacOS` branches exist), but the
  Local Model is Windows-only, so the AI section and the Riassumi button are
  hidden on other platforms.

**Choices the build needed that no ticket had made.** Each one is small and
reversible. Object to any of them and it gets reopened:

1. No `SummaryRequest`/`SummaryResult` wrappers:
   `Future<String> summarize(String text, {Future<void>? cancelled})` plus a
   sealed `AiFailure`. The ticket asked for request/result models, but they
   would wrap a single field each.
2. One `CliAiProvider` parameterized by `AiProviderKind`, not three classes.
3. `crypto` is promoted from a transitive to a direct dependency, for streaming
   SHA256. Extraction uses Windows' built-in `tar.exe`, not `archive`.
4. Cold or warm timeout: pick it by reading `GET /props` `is_sleeping` before
   each request. If `/props` fails, treat it as cold.
5. Socket errors and non-400 HTTP errors on a request show the "risposta non
   valida" text.
6. Before killing an orphan, check the PID's image name with `tasklist`, because
   Windows reuses PIDs. The PID file lives in `ai\`, since `bin\` gets wiped.
7. The Settings switch acts immediately, no longer tied to Salva. If the files
   are already installed, there is no confirm.
8. During the silent auto-restart the status is `starting`, so the neutral
   strip shows. The error strip appears only if the restart fails before
   reaching `ready`.
9. New Italian copy, not in ticket 08: the install confirm and update confirm,
   the modal lines, the delete confirm, the Settings subtitle, and the Aiuto
   licence line.
10. `CONTEXT.md` has no separate **Summary** term. It would be a synonym of the
    existing **Note Summary**, so bare "Summary" goes in its _Avoid_ list.
11. There are no automated integration tests: the repo has no CI and a 1.3 GB
    download is needed. The spec has a 10-step manual pass on the Windows box
    instead.
