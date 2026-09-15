# 00 — Charting round

**Type:** grilling
**Blocked by:** none
**Status:** resolved

## Question

What shape does the local llama.cpp integration take, and what is deliberately
left out?

## Answer

Settled with the user in four grilling rounds while charting.

### Scope and destination

1. **Destination is a handoff spec**, not shipped code. Decisions here, build in
   one later session.
4. **Checklist operation out of scope.** No UI exists for it. The interface must
   not preclude adding it.
5. **Other providers hidden, not deleted.** Claude/Codex/OpenCode are refactored
   behind the new interface and disappear from Settings — no hidden env-var
   escape hatch until someone needs one. The Settings AI block becomes a single
   enable switch (plus the delete-model button, see 20).

### Packaging and install

2. **Both `llama-server` and the model are downloaded** on first enable — no
   binaries bundled in the Flutter build. The confirm alert therefore says
   ~1,4 GB, not ~1,28 GB.
3. **Native Windows x64 only.** WSL is irrelevant to this provider; `aiWslMode`
   stays as the CLI providers' concern. Other platforms are a later effort.
7. **Storage: `%LOCALAPPDATA%\Clockodile\ai\`** — `bin/llama-server.exe`,
   `models/Qwen3-1.7B-Q4_K_M.gguf`. Resolved behind one `LlamaPaths` seam so a
   user-configurable path can arrive without touching the provider. No
   `path_provider` dependency: `Platform.environment['LOCALAPPDATA']`.
8. **Download blocks in a modal** with a progress bar and Annulla. No
   Range-resume: a failure deletes the partial file and starts over.
9. **SHA256 verified** on both the release zip and the GGUF before first use.
22. **Install confirm fires when the Settings switch flips on.** Cancel leaves
    the switch off.
20. **Disabling AI keeps the files** and kills the server; Settings carries an
    explicit "elimina modello (1,4 GB)" button to reclaim the disk.

### Runtime

6. **Server starts at app open only when `aiEnabled` is true** and the install is
   complete. Killed on app close.
13. **Port probing** 18080 upward, the same `ServerSocket` bind-and-close trick
    `main.dart` already uses for the single-instance lock. The winning port is
    passed to both the child process and the HTTP client.
16. **A PID file** next to the binary handles crash orphans: on startup, kill the
    process it names if still alive. Only ever a PID we wrote — never a scan for
    `llama-server` by name.
21. **Three timeouts**, as `AiConfig` constants: startup 120 s, cold inference
    90 s, warm inference 30 s. A cold-start wait is never reported as a failure;
    Riassumi shows a spinner throughout.
12. **`const AiConfig`** holds port, ctxSize, sleepIdleSeconds, temperature,
    maxTokens and the three timeouts. No DB columns, no UI, no env overrides.
11. **No schema migration.** The legacy AI columns stay; only what llama needs is
    added.

### Contract and code shape

14. **Spec §10's prompt**, with `response_format` JSON Schema `{summary}`. The
    hidden CLI providers keep their existing prompt and parsers.
17. **The interface is named `AiProvider`;** the existing DB enum is renamed
    `AiProviderKind`. Both go into `CONTEXT.md` under Language.
18. **An `AiCubit`**, provided in `main.dart` beside the existing cubits, owns
    install, process and status. Same house pattern as `EntriesCubit` et al.
10. **One `LocalAiStatus` enum** — `notInstalled / installing / starting / ready
    / error` — drives the status strip, the Riassumi button's enabled state and
    Settings alike. Spec §3's seven states collapse: `sleeping` and `busy` are
    invisible to this UI.
15. **The status strip lives in `MaterialApp.builder`'s `Column`**, below
    `Expanded(child: child!)`, zero-height when idle. A `SnackBar` would be lost
    when `EntryEditPage` pushes its own `Scaffold`.
19. **Constructor-injected collaborators** into `AiCubit` for spawn, HTTP and
    download. The existing pure/impure split survives: argv building, request
    bodies and response parsing stay pure and unit-tested; the contract test runs
    the parsers, not the processes.
