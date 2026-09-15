# Local Model for Note Summaries

**Status:** ready-for-agent

Map: [`map.md`](map.md). Every decision below was made in a ticket under
[`issues/`](issues/). Those tickets hold the evidence. This spec holds the
result. A build session starts here and should not need to reopen any of them.
ADR: `docs/adr/0003-local-model-provider.md`. Domain terms: `CONTEXT.md`.

## Problem Statement

Note Summaries work today by spawning a coding-agent CLI (ADR 0002). That only
works for someone who has Claude Code, Codex or OpenCode installed and signed
in. On Windows those CLIs usually live inside WSL, so WSL Mode is needed too.
The CLI is agentic and can take up to 60 s for one line of text. It also sends
the pasted client email to a remote model.

A 1.7B model running locally on the CPU writes the same line in about 5 s warm
and 11 s cold (ticket 05). It needs nothing installed except Clockodile, and the
text never leaves the machine.

## Solution

Settings → AI becomes one switch. The first time the user turns it on, a confirm
dialog shows the real download size. Accepting opens a blocking modal that
downloads two pinned files from their upstream hosts into
`%LOCALAPPDATA%\Clockodile\ai\` and verifies their SHA256: the `llama.cpp` CPU
build and the Qwen3-1.7B Q4_K_M GGUF. While AI is enabled and the files are
installed, Clockodile starts `llama-server` on localhost when the app opens and
kills it when the app closes.

The Riassumi button in the Nota works as before (ten-word gate, dimmed field,
replace on success). It now calls the local server over HTTP with a short
Italian prompt and a JSON Schema. It is enabled only while the server is
`ready`. A thin status strip under the whole app reports starting, broken or
out-of-date states. When everything is fine, it takes no space.

The Claude Code, Codex and OpenCode providers are moved behind the same
`AiProvider` interface. Their UI is hidden, but their code and tests are kept.

Windows x64 only. On other platforms the AI section and the Riassumi button are
not rendered.

## User Stories

1. As a user without any AI CLI installed, I want Note Summaries to work, so
   that the feature does not depend on tools only developers have.
2. As a user, I want my pasted client email processed on my own machine, so
   that client text never goes to a remote model.
3. As a user turning AI on, I want to be told how much will be downloaded before
   anything starts, so that I can say no on a metered connection.
4. As a user who cancels that confirm, I want the switch to stay off, so that
   nothing happens behind my back.
5. As a user downloading, I want a progress bar and an Annulla button, so that I
   can see progress and stop the download.
6. As a user whose download fails, I want to be told why in Italian and offered
   Riprova, so that one flaky connection does not force me back to Settings.
7. As a user, I want a corrupted download to be refused, so that the app never
   runs a damaged binary or model.
8. As a user whose disk is full, I want to be told how much space is needed, so
   that I know what to free.
9. As a user with AI on, I want the local server to start when I open the app,
   so that Riassumi is ready without me doing anything.
10. As a user, I want Riassumi disabled while the model is starting, so that I do
    not press a button that cannot work yet.
11. As a user whose first summary after a pause takes a few seconds longer, I
    want to see the spinner, not an error, so that a cold start is not reported
    as a failure.
12. As a user, I want a failed summary to leave my Nota exactly as it was, with a
    short Italian explanation, so that a failure can never cost me my text.
13. As a user pasting a very long thread, I want to be told it is too long, so
    that I do not get a summary of only half of it.
14. As a user whose server crashed once, I want it restarted without a message,
    so that one crash does not interrupt my day.
15. As a user whose server will not start, I want a strip saying so, with
    Riprova, so that I can recover without restarting the app.
16. As a user after a Clockodile update that changes the pinned files, I want to
    be asked before the new files are downloaded, with the real size, so that an
    update never silently downloads 1.3 GB.
17. As a user, I want disabling AI to stop the server but keep the files, so that
    turning it back on is instant.
18. As a user who wants the disk space back, I want an explicit "Elimina modello"
    button, so that 1.3 GB is never left behind without a way to remove it.
19. As a user closing the app, I want the server killed, so that nothing keeps
    holding RAM after Clockodile is gone.
20. As a user whose app crashed, I want the orphaned server cleaned up on the
    next start, without any other `llama-server` on my machine being touched.

## Implementation Decisions

### Code shape and file layout

All new code lives in `lib/features/ai/`. The repo's split between pure and
impure code stays: whatever can be decided without I/O goes into files with no
`dart:io` `Process`/`HttpClient`/`File`, and those files are the unit-test seam
(charting decision 19).

| File | Kind | Holds |
|---|---|---|
| `ai_provider.dart` | pure | `AiProvider` interface, `AiFailure` hierarchy |
| `summary_command.dart` | pure | existing CLI argv/prompt/parsers, enum renamed |
| `summary_runner.dart` | impure | existing `AiRun`, unchanged |
| `cli_provider.dart` | impure | `CliAiProvider` — wraps `AiRun` + `summary_command.dart` |
| `llama_config.dart` | pure | `AiConfig` constants, `LlamaPaths` |
| `llama_protocol.dart` | pure | argv, prompt, request body, response parser, `/props` sleep read, install marker, needed-downloads rule, size formatting, `tasklist` line check |
| `llama_installer.dart` | impure | download, hash, extract, marker write, delete |
| `llama_runtime.dart` | impure | port probe, spawn, health wait, PID file, orphan kill, stop |
| `llama_provider.dart` | impure | `LlamaCppProvider` — HTTP to `/v1/chat/completions` |
| `cubit/ai_cubit.dart` | — | `AiCubit`, `AiState`, `LocalAiStatus` |
| `ai_status_strip.dart` | widget | the strip |
| `ai_install_dialogs.dart` | widget | confirm, install modal, delete confirm |

**New direct dependency: `crypto`.** It is already in `pubspec.lock` as a
transitive dependency, and `dart:io` has no SHA256. Nothing else is added.
Downloads and requests use `dart:io` `HttpClient`, which follows redirects on
GET by default (`maxRedirects` 5; GitHub serves 1 hop, HF 2). Extraction uses
Windows' own `tar.exe` (`%SystemRoot%\System32\tar.exe`, included since Windows
10 1803), not the `archive` package.

### The `AiProvider` interface and the rename

```dart
/// Where a Note Summary comes from. The UI never knows which one.
abstract interface class AiProvider {
  /// The summary line, trimmed and non-empty. Throws [AiFailure] on anything
  /// else. Completing [cancelled] abandons the attempt: it kills the process or
  /// aborts the HTTP request, and the returned future then throws
  /// [AiCancelled].
  Future<String> summarize(String text, {Future<void>? cancelled});
}

/// Normalized failure. [message] is the Italian text the UI shows as-is.
sealed class AiFailure implements Exception {
  String get message;
}
final class AiTimeout extends AiFailure { ... }          // L'AI locale non ha risposto in tempo. Riprova.
final class AiInvalidResponse extends AiFailure { ... }  // Risposta dell'AI non valida. Riprova.
final class AiContextOverflow extends AiFailure { ... }  // Testo troppo lungo per l'AI locale. Accorcialo e riprova.
final class AiCliFailure extends AiFailure { ... }       // carries the CLI's first stderr line (today's behaviour)
final class AiCancelled extends AiFailure { ... }        // never shown: the page is gone
```

The request is a plain `String` and the result is a plain `String`. A
`SummaryRequest`/`SummaryResult` wrapper around one field adds nothing. The
checklist operation (out of scope) would be a second method with its own
return type, and this interface does not prevent that.

**Rename `enum AiProvider` → `AiProviderKind`** in `lib/data/db/database.dart`.
The stored strings (`claudeCode`, `codex`, `opencode`) do not change, so no
data changes and there is no migration. Every reference (verify with `ast-grep`
before editing):

- `lib/data/db/database.dart` — enum declaration, `aiProvider` column doc comment
- `lib/features/ai/summary_command.dart` — `_argv`, `buildAiCommand`,
  `buildVersionCommand`, `_binary`, `cliMissingMessage`, `parseAiResult`
- `lib/features/entries/entry_edit_page.dart` — `_summarise`
- `lib/features/settings/settings_view.dart` — state, `_providerLabel`, `_cliIsThere`, `_save`, `_aiSection`, `_providerFields`
- `test/ai_command_test.dart`
- `test/settings_ai_test.dart`
- `test/migration_test.dart` (line 51 — the ticket list missed it)

`CliAiProvider(AiProviderKind kind, Setting settings)` is a single class for
all three CLIs, because `summary_command.dart` already switches on the kind. It
builds the command, runs `AiRun`, parses the output, and throws `AiCliFailure`
with the first stderr line (or `Nessun riassunto prodotto.`) exactly as
`_summarise` does today. `buildVersionCommand`, `cliMissingMessage`,
`isCliInstalled` and `aiValuePattern` stay, with their tests. They belong to
the hidden CLI providers, and a later unhide needs them. Nothing constructs
`CliAiProvider` once step 6 below lands: no Settings control and no env var
(charting decision 5).

### Migration order

Each step leaves `pws -c flutter test` green and the app runnable.

1. **Rename** `AiProvider` → `AiProviderKind` (mechanical, all call sites above).
2. **Add the interface.** Add `ai_provider.dart` and `cli_provider.dart`, and
   route `EntryEditPage._summarise` through `CliAiProvider`. **Prove no
   behaviour change:** `ai_command_test.dart` and `entry_note_field_test.dart`
   stay green without edits, and one manual Riassumi through the configured CLI
   gives the same result and the same error text as before.
3. **Pure llama layer.** Add `llama_config.dart`, `llama_protocol.dart` and
   their unit tests (below). No UI change.
4. **Impure llama layer.** Add `llama_installer.dart`, `llama_runtime.dart` and
   `llama_provider.dart`. No UI change.
5. **`AiCubit`.** Provide it in `main.dart`, and test it with fake installer and
   runtime.
6. **UI switch-over.** Add the status strip, the Settings AI section and the
   close hook, move `EntryEditPage` to the cubit, and hide the CLI settings.
7. **Aiuto line** and the manual verification pass (see Testing).

### `AiConfig`

`lib/features/ai/llama_config.dart`. `const` only: no DB column, no UI, no env
override (charting 12). Bumped by hand in a Clockodile release (ticket 03).

```dart
abstract final class AiConfig {
  // Runtime pin — ticket 03.
  static const llamaTag = 'b10900';
  static const llamaAsset = 'llama-b10900-bin-win-cpu-x64.zip';
  static const llamaUrl =
      'https://github.com/ggml-org/llama.cpp/releases/download/$llamaTag/$llamaAsset';
  static const llamaSha256 =
      '47f6fe584bc8a6510c00f40ed103ec43db66a52f4eee23126b8379c9028fd107';
  static const llamaZipBytes = 18423427;
  static const llamaUnpackedBytes = 46746909;

  // Model pin — ticket 07 (supersedes 02/03's bartowski pin).
  static const modelRepo = 'ggml-org/Qwen3-1.7B-GGUF';
  static const modelRevision = 'daeb8e2d528a760970442092f6bf1e55c3b659eb';
  static const modelFile = 'Qwen3-1.7B-Q4_K_M.gguf';
  static const modelUrl =
      'https://huggingface.co/$modelRepo/resolve/$modelRevision/$modelFile';
  static const modelSha256 =
      'd2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5';
  static const modelBytes = 1282439264;

  // Server — spec §3/§16, tickets 05 and 08.
  static const host = '127.0.0.1';
  static const portRangeStart = 18080;
  static const portRangeEnd = 18099; // inclusive, 20 ports
  static const ctxSize = 8192;
  static const parallel = 1;
  static const sleepIdleSeconds = 60;

  // Request — spec §12, verified in ticket 05.
  static const temperature = 0;
  static const maxTokens = 128;
  static const cachePrompt = false; // the configuration every timing was measured with

  // Timeouts — charting 21; ticket 05 measured ~3x headroom.
  static const startupTimeout = Duration(seconds: 120);
  static const coldInferenceTimeout = Duration(seconds: 90);
  static const warmInferenceTimeout = Duration(seconds: 30);
  static const healthPollInterval = Duration(milliseconds: 500);
  static const propsTimeout = Duration(seconds: 2);
}
```

`LlamaPaths` is the single seam that maps a root directory to every path
(charting 7). Production uses
`Platform.environment['LOCALAPPDATA']\Clockodile\ai`, with no `path_provider`.
Tests pass a temp directory.

```
<root>\                      = %LOCALAPPDATA%\Clockodile\ai
  bin\                       whole release zip unpacked here; wiped before each unpack
    llama-server.exe
  models\
    Qwen3-1.7B-Q4_K_M.gguf   upstream filename kept (ticket 03)
  installed.json             {"llamaTag": "...", "modelSha256": "..."} — written LAST
  llama-server.pid           PID of the server this app spawned
  *.part                     in-flight downloads
```

The PID file sits in `<root>`, not `bin\`, because an unpack wipes `bin\`.

### Install state and the needed-downloads rule

Pure: `neededDownloads({InstallMarker? marker, bool exeExists, bool modelExists})`
returns the subset of `{runtime, model}`:

- no marker (never installed, or a crash mid-install) → both
- `marker.llamaTag != AiConfig.llamaTag` or `!exeExists` → runtime
- `marker.modelSha256 != AiConfig.modelSha256` or `!modelExists` → model

**Installed** means the result is empty. The model is never re-hashed at app
open (ticket 03). The download size quoted anywhere is the sum of the needed
parts: `llamaZipBytes` and/or `modelBytes`.

`InstallMarker.decode(String)` returns null on missing or malformed JSON, and
null means "no marker".

### Install flow

**Confirm** (charting 22). Shown when the Settings switch flips on and
`neededDownloads` is non-empty. If nothing is needed (files kept from an
earlier disable), there is no confirm and no download: the switch goes straight
on and the server starts.

- Title: `Attivare l'AI locale?`
- Body: `Clockodile scaricherà il motore llama.cpp e il modello Qwen3 1.7B (circa <size>) nella cartella dell'app. Il testo delle note non lascia mai questo computer.`
- Buttons: **Annulla** (switch stays off) / **Scarica**

The same dialog is used for the strip's **Aggiorna** action, with title
`Aggiornare i file AI?` and body `Serve un download di circa <size>.`

**Size text** (pure `formatBytes`): decimal units, Italian comma, from bytes.
At or above 10⁹ it is one decimal `GB` (`1300862691` → `1,3 GB`). Below that it
is whole `MB` (`18423427` → `18 MB`). A full install is `1,3 GB`, which
corrects charting's `~1,4 GB` estimate. That estimate predates the real sizes:
18,423,427 + 1,282,439,264 bytes.

**Modal** (charting 8). `showDialog(barrierDismissible: false)`, driven by
`BlocBuilder<AiCubit>`:

- Title: `Download AI locale`
- Line: `llama.cpp — 12 / 18 MB` or `Modello — 0,4 / 1,3 GB`, over a determinate
  `LinearProgressIndicator` fed from `Content-Length`
- Extraction: `Estrazione…`, indeterminate bar
- Button: **Annulla**

Steps, in `LlamaInstaller.install(needed, onProgress, cancelled)`:

1. For each needed file, runtime first: `GET` the URL into `<root>\<name>.part`
   while feeding the bytes to `sha256.startChunkedConversion` in the same pass.
   A non-200 status is a download failure.
2. Compare the digest with the pin. On a mismatch, delete the `.part` and fail
   with the checksum error.
3. Runtime: stop the server, wipe `bin\`, run `tar.exe -xf <zip> -C <root>\bin`,
   and delete the zip. The zip's files sit at its root (research 01 §2). If
   `bin\llama-server.exe` is missing afterwards, or `tar` exits non-zero, fail
   with the checksum text: the archive is not what was pinned.
4. Model: delete every other file in `models\`, then rename `.part` to
   `AiConfig.modelFile`.
5. Write `installed.json`, only after every needed part succeeded.

Cancel: close the response, delete the `.part`, close the modal, and keep the
switch off. No message (ticket 08). On failure, every `.part` is deleted and
`installed.json` is untouched. There is no Range resume (out of scope).

Install failures replace the progress bar with the text and the buttons
**Riprova** / **Chiudi**. Chiudi leaves the switch off, or leaves the strip as
it was for Aggiorna. Texts come from ticket 08:

| Cause | Text |
|---|---|
| `SocketException`, `HttpException`, `TimeoutException`, HTTP not 200 | `Download non riuscito. Controlla la connessione e riprova.` |
| SHA256 mismatch, bad archive | `File scaricato danneggiato. Riprova il download.` |
| `FileSystemException` with `osError.errorCode == 112` | `Spazio su disco insufficiente (servono circa <size>).` — size of the needed parts |

Any other `FileSystemException` uses the download text and is logged.

There is no disk-space precheck and no VC++ runtime check. `clockodile.exe`
already imports `VCRUNTIME140`/`MSVCP140`/UCRT and bundles none of them, so if
Clockodile launched, `llama-server.exe` can load too (ticket 03). Do not "fix"
this.

### Runtime lifecycle — `LlamaRuntime`

The spec §22 name `LlamaRuntimeManager` becomes `LlamaRuntime`. One class owns
the process.

**Start** (`start() → Future<int port>`, throws `NoFreePort` / `StartFailed`):

1. **Orphan check** (charting 16). If `llama-server.pid` exists, run
   `tasklist /FI "PID eq <pid>" /FO CSV /NH`. Only if the first CSV field is
   `"llama-server.exe"`, call `Process.killPid(pid)`. Delete the PID file either
   way. Never search for processes by name. The PID check guards against
   Windows reusing the PID for an unrelated process. Log it; never show it
   (ticket 08).
2. **Port** (charting 13): for `p` in `portRangeStart..portRangeEnd`, try
   `ServerSocket.bind(InternetAddress.loopbackIPv4, p)` and close it at once.
   This is the same technique `main.dart`'s instance lock uses. The first port
   that binds wins. If none binds, throw `NoFreePort`.
3. **Spawn** `<root>\bin\llama-server.exe` with `buildLlamaArgs(modelPath, port)`:

   ```
   -m <root>\models\Qwen3-1.7B-Q4_K_M.gguf --host 127.0.0.1 --port <port>
   --reasoning off --parallel 1 --ctx-size 8192 --sleep-idle-seconds 60
   ```

   `--reasoning off` alone is enough to suppress thinking, and without it every
   response comes back empty (ticket 05). No `--chat-template-kwargs`. Write the
   PID file right away. Drain stdout, and keep the last ~20 lines of stderr for
   the log.
4. **Wait for health**: poll `GET http://127.0.0.1:<port>/health` every
   `healthPollInterval`. 200 means ready. 503 (loading) or a refused connection
   means keep polling. If the process exits first, or `startupTimeout` passes
   (kill it first), throw `StartFailed`. `/health` is only a startup gate: it
   answers 200 while sleeping too (ticket 01).

**Exit watch.** `onExit` exposes `process.exitCode` for the cubit to react to.

**Stop.** `process.kill()`, await `exitCode`, delete the PID file. Safe to call
at any time.

### `AiCubit`, `AiState`, `LocalAiStatus`

Provided in `main.dart` next to the other cubits (charting 18). It is created
after the single-instance lock, so a second instance never touches the server.
Its collaborators are injected through the constructor (charting 19):

```dart
AiCubit({
  required AppDatabase db,
  required LlamaPaths paths,
  required LlamaInstaller installer,
  required LlamaRuntime runtime,
  required AiProvider Function(int port) providerFor, // LlamaCppProvider.new in prod
})
```

```dart
enum LocalAiStatus { notInstalled, installing, starting, ready, error }

class AiState {
  final bool enabled;           // Settings.aiEnabled
  final LocalAiStatus status;
  final bool noFreePort;        // only meaningful with status == error
  final bool filesOnDisk;       // <root> exists — drives "Elimina modello"
  final int pendingBytes;       // sum of neededDownloads, for Aggiorna (<size>)
  final InstallProgress? progress;    // file label, received, total; null when idle
  final InstallFailure? installFailure; // network | checksum | diskFull
}
```

`sleeping` and `busy` from spec §3 do not exist: this UI cannot see them
(charting 10). While `enabled` is false, `status` is `notInstalled` and nothing
reads it.

`AiCubit` reuses the existing `aiEnabled` column. **No schema change;
`schemaVersion` stays 6** (charting 11). An existing user who had a CLI provider
enabled opens the upgraded app with AI on and no files. They see the Aggiorna
strip, which is correct.

Transitions:

- **App open** (`init()`): read settings and the marker. Not Windows, or
  `!enabled` → idle. `enabled` and not installed → `notInstalled`. `enabled` and
  installed → `starting` → `runtime.start()` → `ready`, or `error` (with
  `noFreePort` when that was the cause).
- **`enable()`** (after the confirm): if downloads are needed, `installing` →
  `installer.install` → on success persist `aiEnabled = true` → start. On
  failure set `installFailure` and keep `enabled` false. On cancel, go back to
  idle with `enabled` false.
- **`update()`** (strip Aggiorna): same as `enable()`, but `enabled` is already
  true. A failure or cancel returns to `notInstalled`.
- **`disable()`**: `runtime.stop()`, persist `aiEnabled = false`. Files are kept
  (charting 20).
- **`deleteFiles()`**: `runtime.stop()`, delete all of `<root>`, persist
  `aiEnabled = false`, `filesOnDisk = false` (ticket 03, decision 11).
- **`retry()`** (strip Riprova): start again from `starting`.
- **Process exits while `ready`** (ticket 08, decision 4): one silent restart.
  Status goes to `starting` (the neutral strip), and `ready` again on success.
  If the restarted process dies or times out **before reaching `ready`**, go to
  `error`. The one-restart allowance renews every time `ready` is reached.
- **`shutdown()`**: `runtime.stop()`. Called from the window-close hook.
- **`summarize(text, cancelled)`**: throws `AiInvalidResponse` unless `ready`,
  otherwise delegates to the current `LlamaCppProvider`. A request failure never
  changes `status` (ticket 08, decision 5).

**App close.** In `HomeShell`, call `windowManager.setPreventClose(true)` and
add a `WindowListener`. `onWindowClose` → `await aiCubit.shutdown()` →
`windowManager.destroy()`. Ctrl+W already routes through `windowManager.close`,
so it takes the same path. A crash or a hot restart skips this, and the PID file
handles that case on the next start.

### `LlamaCppProvider` — request, timeouts, parser

`summarize(text, cancelled)`:

1. **Cold or warm.** `GET /props` with `propsTimeout`. If `is_sleeping == true`,
   or `/props` fails, use `coldInferenceTimeout`; otherwise use
   `warmInferenceTimeout`. `/props` does not wake the server or reset its idle
   timer (research 01 §6). This is pure `timeoutForProps(String? body)`.
2. **POST** `/v1/chat/completions` with `buildSummaryBody(text)`. Body shape
   verified in ticket 05 (`docs/llama.cpp/fixtures/summary.constrained.request.json`):

   ```json
   {
     "model": "Qwen3-1.7B-Q4_K_M.gguf",
     "messages": [{"role": "user", "content": "<buildLocalSummaryPrompt(text)>"}],
     "temperature": 0,
     "max_tokens": 128,
     "cache_prompt": false,
     "response_format": {
       "type": "json_schema",
       "json_schema": {
         "name": "summary",
         "strict": true,
         "schema": {
           "type": "object",
           "properties": {"summary": {"type": "string"}},
           "required": ["summary"],
           "additionalProperties": false
         }
       }
     }
   }
   ```

   Use the fixture's `json_schema: {name, strict, schema}` shape, which was
   tested, not the README's bare `schema` shape. There is no free-text fallback:
   unconstrained output never parses (ticket 05).
3. **Timeout** → abort the request, throw `AiTimeout`. **Cancel** → abort, throw
   `AiCancelled`. **Socket error / connection reset** → `AiInvalidResponse`
   (logged).
4. **Parse** with pure `parseLlamaSummary(int status, String body) → String`,
   which throws:
   - status 400 and `error.type == "exceed_context_size_error"` →
     `AiContextOverflow`. Match on `type`, never on `message` (ticket 08). The
     input is never truncated on the client.
   - any other status that is not 200 → `AiInvalidResponse`
   - `choices[0].finish_reason != "stop"` → `AiInvalidResponse`. This is checked
     **before** decoding (ticket 05: truncation gives `length`).
   - `choices[0].message.content` empty or whitespace → `AiInvalidResponse`
     (the thinking-on shape)
   - content is not a JSON object with a string `summary`, or the trimmed
     `summary` is empty → `AiInvalidResponse`
   - otherwise → trimmed `summary`

   No word count and no language detection (ticket 07).

**Prompt** (ticket 07, verbatim; `<INPUT>` replaced with the Nota text, nothing
else):

```text
Scrivi in italiano una nota di time-tracking brevissima, in stile telegrafico.

Massimo 15 parole.
Usa parole chiave e brevi frasi nome/azione.
Non serve una frase completa.
Tieni solo il lavoro essenziale richiesto.
Ometti saluti, riempitivi, esempi, citazioni e dettagli non essenziali.

Testo:
"""
<INPUT>
"""
```

Do not add "Rispondi solo in italiano" or a Schema `description`. More rules
made the output worse (ticket 07, `it2`). The CLI providers keep
`buildSummaryPrompt` unchanged.

### Status strip

`ai_status_strip.dart`. It sits in `MaterialApp.builder`'s `Column`, **below**
`Expanded(child: child!)` (charting 15), so it survives pushed routes. It is
wrapped in `Material` because it lives outside any `Scaffold`. It renders
`SizedBox.shrink()` unless `enabled` is true and `status` is one of the
following (ticket 08):

| Status | Text | Action |
|---|---|---|
| `notInstalled` | `File AI mancanti o da aggiornare` | **Aggiorna (<size of pendingBytes>)** |
| `starting` | `Avvio AI locale…` (small spinner) | none |
| `error` | `AI locale non avviata` | **Riprova** |
| `error` + `noFreePort` | `AI locale non avviata: nessuna porta libera (18080–18099)` | **Riprova** |

`installing` and `ready` show nothing, because the modal owns `installing`.
Build the port range text from `AiConfig`. Use the theme's `errorContainer`
colours for `error` and a neutral surface colour otherwise.

**Dialogs from the strip.** The strip sits above the `Navigator`, so its own
`context` cannot `showDialog`. Give `MaterialApp` a
`navigatorKey: GlobalKey<NavigatorState>` and open the Aggiorna confirm and
modal with `navigatorKey.currentContext!`.

### Riassumi button (`EntryEditPage`)

- The page stops reading `Setting` for AI and uses `context.watch<AiCubit>()`.
- **Visible** iff `state.enabled` (and on Windows). Absent otherwise, as today.
- **Enabled** iff `status == ready`, `hasEnoughWordsForSummary`, and no
  generation is in flight.
- **Pressed:** the field is dimmed and locked with the spinner, as today, for
  the whole request, cold or warm (charting 21). On success the Nota is
  replaced. On `AiFailure` the SnackBar shows `failure.message`, and
  `AiCancelled` is ignored.
- **Dispose:** complete the `cancelled` completer (replaces `_run?.cancel()`).
- `_firstLine` moves into `CliAiProvider`. The UI never shows raw diagnostics
  (ticket 08, decision 9).

### Settings

The AI section after step 6 (all CLI controls are removed from the UI):

```
AI
[switch] Riassunto delle note
         Usa un modello locale su questo computer.
[Elimina modello (1,3 GB)]      ← only when filesOnDisk
```

- **The switch acts at once**, like the theme. It is **not** tied to Salva any
  more. On → confirm → modal, via `AiCubit.enable()`. Off → `AiCubit.disable()`.
  The switch reflects `state.enabled`, so a cancelled or failed install leaves
  it off with no extra code.
- **Elimina modello** is a `DangerButton`. The size comes from
  `formatBytes(llamaUnpackedBytes + modelBytes)` = `1,3 GB`. It asks for
  confirmation first:
  - Title: `Eliminare l'AI locale?`
  - Body: `llama.cpp e il modello verranno rimossi da questo computer. Potrai riscaricarli riattivando l'AI.`
  - Buttons: **Annulla** / **Elimina** → `AiCubit.deleteFiles()`
- **`_save` writes only `retentionDays`.** Remove every `ai*` value from its
  `SettingsCompanion`. Otherwise Salva would overwrite `aiEnabled` with stale
  page state. Remove `_invalidAiField`, `_cliIsThere`, the provider
  `SegmentedButton`, `_providerFields`, the WSL switch, and the free-text
  controllers. Update the theme comment ("retention and AI wait for the button")
  to say that only retention waits.
- The legacy columns (`aiProvider`, the six model/effort columns, `aiWslMode`)
  stay in the table untouched (out of scope to drop).

### Aiuto

Add one line at the bottom of `HelpView`:
`AI locale: llama.cpp (MIT) e modello Qwen3-1.7B (Apache-2.0), scaricati da GitHub e Hugging Face.`

### Logging

`dart:developer` `log(..., name: 'clockodile.ai')` only. Log the stderr tail,
the HTTP status and body of failed requests, Windows error codes, timings
(`timings.prompt_ms`, `timings.predicted_ms`,
`usage.prompt_tokens_details.cached_tokens`), orphan kills and port choice.
**Never log the Nota text or the prompt** (spec §20). No log file.

## Testing Decisions

The repo's rule holds: tests describe behaviour a caller can observe, no test
spawns a process or downloads anything, and pure seams are tested with plain
calls. Prior art: `test/ai_command_test.dart`, `test/normalize_test.dart`.

**Step 1–2 (no behaviour change):** `ai_command_test.dart`,
`entry_note_field_test.dart` and `migration_test.dart` pass with only the
rename applied.

**`test/llama_protocol_test.dart`** (pure):

- `buildLlamaArgs` returns exactly the argv above; `--reasoning`, `off` are
  adjacent; there is no `--chat-template-kwargs`.
- `buildLocalSummaryPrompt` equals the ticket 07 text with the input substituted
  verbatim (quotes, backticks, newlines).
- `buildSummaryBody` decodes to the fixture's structure. Compare against
  `docs/llama.cpp/fixtures/summary.constrained.request.json` with
  `messages[0].content` and `model` excluded.
- `parseLlamaSummary`, reading the real fixtures from
  `docs/llama.cpp/fixtures/` (`flutter test` runs from the repo root):
  - `summary.constrained.pinned-reasoning-off.response.json` → its summary string
  - `summary.constrained.localfile-no-flag.response.json` (empty content, `length`) → `AiInvalidResponse`
  - `summary.truncated.pinned-reasoning-off.response.json` (`{"summary`, `length`) → `AiInvalidResponse`
  - `summary.unconstrained.pinned-reasoning-off.response.json` (`stop`, not JSON) → `AiInvalidResponse`
  - inline 400 `exceed_context_size_error` body from ticket 08 → `AiContextOverflow`
  - inline 400 with another `type`, and a 500 → `AiInvalidResponse`
  - `{"summary": "   "}` → `AiInvalidResponse`
- `timeoutForProps`: `is_sleeping: true` → cold, `false` → warm, null or
  malformed → cold.
- `neededDownloads`: no marker → both; everything matching → none; tag bumped →
  runtime only; SHA bumped → model only; exe missing → runtime; model missing →
  model.
- `InstallMarker` encode/decode round trip; malformed JSON → null.
- `formatBytes`: `18423427` → `18 MB`; `1282439264` → `1,3 GB`;
  `1300862691` → `1,3 GB`.
- `isOurProcess(tasklistLine)`: `"llama-server.exe","1234",...` → true;
  `"notepad.exe",...` → false; `INFO: No tasks...` → false.

**`test/ai_cubit_test.dart`** — real `AppDatabase.forTesting`, `LlamaPaths` on a
temp dir, hand-written fake `LlamaInstaller`/`LlamaRuntime`/provider. No
`bloc_test` or mocking package.

- enabled + installed → `starting` then `ready`
- enabled + no marker → `notInstalled` with `pendingBytes == 1300862691`
- start throws `StartFailed` → `error`; `NoFreePort` → `error` + `noFreePort`
- process exits while `ready` → `starting` → `ready` (one restart); exits again
  before ready → `error`
- `enable()` success → `aiEnabled` persisted true, status `ready`
- `enable()` cancel → `enabled` false, nothing persisted
- `enable()` network / checksum / disk-full → `installFailure` set to the
  matching kind, `enabled` false
- `disable()` → runtime stopped, files kept, `aiEnabled` false
- `deleteFiles()` → root gone, `filesOnDisk` false, `aiEnabled` false
- `summarize` while not `ready` → `AiInvalidResponse`; while `ready` → provider
  result

**Widget tests:**

- `entry_note_field_test.dart` (rewrite AI cases to seed `AiCubit` with fakes
  instead of `aiEnabled` in the DB): button absent when not enabled; visible but
  disabled while `starting`; toggles around ten words when `ready`; present in
  edit mode; padding reserved.
- `settings_ai_test.dart` (rewrite): switch off by default; flipping it shows the
  confirm with `1,3 GB`; Annulla leaves it off and never calls the installer;
  Scarica runs the fake install and the switch ends on; no confirm when files
  are already installed; Elimina modello hidden without files and shown with
  them; Salva persists retention and leaves `aiEnabled` untouched; no provider,
  model or WSL controls are rendered.
- `test/ai_status_strip_test.dart`: zero height when disabled or `ready`; each
  row of the strip table shows its text and action.

**Integration tests: none automated.** Every spec §21 integration case needs
the 1.3 GB download and a Windows CPU. This repo has no CI and no remote, and a
test that silently skips proves nothing. Instead, run this **manual pass on the
Windows box** once, at the end of step 7, and again whenever a pin is bumped:

1. Fresh `%LOCALAPPDATA%\Clockodile\ai` absent → enable → confirm says `1,3 GB`
   → modal completes → strip `Avvio AI locale…` → gone → Riassumi works on
   `docs/llama.cpp/fixtures/italian/email1.txt`.
2. Annulla mid-model-download → no `.part` left, switch off.
3. Edit `installed.json`'s `llamaTag` → restart app → strip offers
   `Aggiorna (18 MB)` → runtime only is downloaded.
4. Wait > 60 s idle → Riassumi still succeeds (cold path).
5. Hold port 18080 with another process → server picks 18081.
6. Kill `llama-server.exe` in Task Manager → it comes back silently.
7. Close via Ctrl+W → no `llama-server.exe` left in Task Manager.
8. Kill `clockodile.exe` in Task Manager → relaunch → the orphan is killed, and a
   separately started `llama-server` on another port survives.
9. Paste ~40,000 words → `Testo troppo lungo per l'AI locale. Accorcialo e riprova.`
10. Elimina modello → folder gone, switch off.

On a pin bump, first rerun `docs/llama.cpp/fixtures/llama-verify.ps1` and
`docs/llama.cpp/fixtures/italian/llama-italian.ps1` against the new files.

**Not tested:** process spawning, HTTP, download, `tar.exe`, window close. Each
needs a real binary or network, and the logic behind them lives in the pure
functions above.

## Out of Scope

From the map, unchanged:

- The checklist operation (spec §11) — no UI for it. The interface does not
  prevent adding it.
- macOS and Linux, and GPU builds (Vulkan/CUDA/ROCm/SYCL).
- Resumable (Range) or background download.
- Dropping the legacy AI settings columns.
- Falling back to a CLI provider when local inference fails — it would silently
  send client text to a remote model.
- Tunable inference settings in the UI (ctx size, temperature, sleep idle).
- A log file on disk.

Also not built:

- Any way to re-enable the CLI providers (no Settings control, no env var).
- Resolving "latest" from the GitHub API at runtime.
- Word-count validation, language detection, client-side truncation.
- Re-hashing the model at app open.
- A disk-space precheck or a VC++ runtime check.

## Further Notes

- **Traps already hit** (do not rediscover): GitHub `releases/latest` carries
  no binaries; HF's `xetHash` is not a SHA256 (`lfs.oid` is); `/health` says
  `ok` while sleeping; `cached_tokens` is nested under
  `usage.prompt_tokens_details`; without `--reasoning off` Qwen3 spends all 128
  tokens thinking and returns empty content.
- **The prompt language decides the output language.** With the English §10
  prompt, both GGUFs answered in English on 3 of 5 emails (ticket 07). The
  ggml-org pin and the Italian prompt belong together.
- Evidence: `docs/llama.cpp/fixtures/` (ticket 05),
  `docs/llama.cpp/fixtures/italian/` (ticket 07),
  `.scratch/local-llama-provider/research/` (tickets 01, 02, 06).
- Measured on the dev box (CPU, winget build 10853): startup 5–8 s, warm request
  ~5 s, cold ~11 s, ~20% of 24 GB RAM while the model is loaded.
