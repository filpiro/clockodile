# Map — Local llama.cpp provider

**Label:** `wayfinder:map`

## Destination

A handoff spec (`.scratch/local-llama-provider/spec.md`) plus ADR 0003 and the
`CONTEXT.md` Language additions, complete enough that one build session can
implement the local Qwen3 provider — download, lifecycle, toast, provider
abstraction — without reopening a decision. **Decisions only; no production code
is written from this map.**

## Notes

- Domain: Flutter desktop, Windows-only target. Flutter runs on Windows, agents
  run from WSL — every Flutter/Dart command goes through `pws -c ...`.
- Source spec: `docs/llama.cpp/flutter_llama_cpp_provider_spec.md` (draft, has
  open questions this map answers), plus
  `docs/llama.cpp/llama_server_postman_collection.json`.
- Existing AI code: `lib/features/ai/summary_command.dart` (pure: argv, prompt,
  parsing) and `summary_runner.dart` (impure: spawn). Consumed by
  `lib/features/entries/entry_edit_page.dart` and
  `lib/features/settings/settings_view.dart`. Settings columns live in
  `lib/data/db/database.dart` (schema v6).
- Prior art: `docs/adr/0002-local-cli-ai-provider.md`.
- Every session: `/grilling` and `/domain-modeling`. Read a file before editing
  it; `ast-grep` for callers before changing a function.
- House style: `flutter_bloc` cubits, `catui` widgets, Italian UI strings.

## Decisions so far

<!-- one line per closed ticket; detail lives in the ticket -->

- [00 — Charting round (grilling)](issues/00-charting-decisions.md) — the 22
  decisions taken while charting: handoff-spec destination, download both binary
  and model, native Windows, checklist out, other providers hidden not deleted,
  `%LOCALAPPDATA%` storage, blocking non-resumable download, checksums on both
  files, `LocalAiStatus` drives the UI, no schema migration, `const AiConfig`,
  port probing, spec §10 prompt + JSON Schema, status strip in
  `MaterialApp.builder`, PID file for orphans, interface keeps the name
  `AiProvider` (enum becomes `AiProviderKind`), an `AiCubit` owns it,
  constructor-injected seams, keep-model-on-disable with an explicit delete,
  three timeouts (120/90/30 s), install confirm on the Settings switch.
- [02 — Qwen3-1.7B-Q4_K_M GGUF: canonical source and integrity](issues/02-qwen3-gguf-source.md)
  — _(pin superseded by 07: ggml-org; the integrity method still stands)_ `bartowski/Qwen_Qwen3-1.7B-GGUF` @ `dcb1915`, file
  `Qwen_Qwen3-1.7B-Q4_K_M.gguf`, exactly 1,282,439,584 bytes, SHA256 from the HF
  tree API's `lfs.oid` (**not** `xetHash`). Anonymous download, one 302,
  `Content-Length` honoured. This GGUF's embedded template branches on
  `enable_thinking`, so `--chat-template-kwargs '{"enable_thinking": false}'` is
  the switch it actually reads — whether `--reasoning off` alone suffices is
  ticket 05's job. The official Qwen repo publishes no `Q4_K_M`.
- [01 — llama.cpp Windows x64 release: assets, flags, endpoints](issues/01-llama-cpp-windows-release.md)
  — `llama-b10900-bin-win-cpu-x64.zip`: one CPU package with runtime microarch
  dispatch, no more `avx2`/`noavx` variants. All seven spec flags confirmed
  verbatim. Per-asset `digest: sha256:` straight from the GitHub API. Three
  traps: `releases/latest` carries **no binaries** (per-commit `bNNNNN` tags
  only), the zip omits `VCRUNTIME140.dll`/UCRT, and `/health` answers 200 `ok`
  while sleeping — only `/props.is_sleeping` knows.
- [03 — Pin the runtime build, the model revision and the version policy](issues/03-pin-runtime-and-model.md)
  — CPU zip `b10900` and bartowski @ `dcb1915` _(model superseded by 07: ggml-org @ `daeb8e2`)_ as hand-bumped `AiConfig`
  constants, no GitHub API at runtime. Flat `ai/` + `installed.json` written last
  as the install marker; a pin mismatch reads as `notInstalled` and prompts an
  update of only the changed file _(strip text superseded by 08)_. VC++ gap moot — `clockodile.exe` already
  imports the same runtime. No disk precheck. Whole zip unpacked; upstream model
  filename kept; "elimina modello" wipes all of `ai/`.
- [05 — Verify structured output and thinking-off against a real server](issues/05-verify-structured-output-and-thinking-off.md)
  — `response_format` json_schema works and is needed, because free text never
  parses. `--reasoning off` alone suppresses thinking, so it stays in argv;
  without it the response is empty `content` with `finish_reason: length`. Parser
  fails on `finish_reason != "stop"` and on empty content. Warm 5 s, cold 11 s,
  so the timeouts hold. Real fixtures are in `docs/llama.cpp/fixtures/`.
  **The pinned bartowski file answers in English**, so the pin is reopened.
- [06 — Identify the source of the Italian-answering Qwen3 GGUF](issues/06-identify-tested-gguf-source.md)
  — `ggml-org/Qwen3-1.7B-GGUF` @ `daeb8e2`, `Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,264
  bytes, apache-2.0, anonymous download. Its chat template behaves the same as
  bartowski's. The likely difference is that ggml-org's quant has **no imatrix**,
  while bartowski's imatrix is calibrated on community data.
- [07 — Re-pin the model (or harden the prompt) for Italian output](issues/07-repin-model-for-italian-output.md)
  — **Both.** The prompt language decides the output language: with the English
  prompt, both models answered in English on 3 of 5 emails. Re-pin to ggml-org @
  `daeb8e2` (commit, not `main`), which supersedes the bartowski constants in 02
  and 03. Spec §10 becomes a short, plain Italian prompt, recorded verbatim in
  the ticket. No word-count validation and no language detection. Fixtures are
  in `docs/llama.cpp/fixtures/italian/`.
- [08 — Italian error-message catalogue for the local provider](issues/08-italian-error-catalogue.md)
  — Install failures stay in the modal with Riprova/Chiudi, and Annulla is
  silent. Server failures go to the status strip with Riprova, after one silent
  auto-restart. Request failures show as a SnackBar on `EntryEditPage`. Orphans
  are never shown. The ticket holds the exact texts. The strip text becomes
  `File AI mancanti o da aggiornare` _(supersedes 03's "Aggiornamento AI
  richiesto")_. Port probing gets 18080–18099. Context overflow is matched on
  HTTP 400 `error.type: exceed_context_size_error`. Logging uses
  `dart:developer` only, never with the user's text.
- [04 — Write the handoff spec, ADR 0003 and the CONTEXT additions](issues/04-write-handoff-spec.md)
  — **Destination reached.** [`spec.md`](spec.md) is `ready-for-agent`, and
  `docs/adr/0003-local-model-provider.md` and the `CONTEXT.md` terms are
  written. The ticket lists 11 small choices made while writing (plain `String`
  in/out plus `AiFailure`, `crypto` + `tar.exe`, `/props` picks cold or warm,
  switch acts immediately, manual pass instead of integration tests). Veto any
  of them there.

## Not yet specified

<!-- empty: the map is complete; spec.md is the handoff -->

## Out of scope

- **Checklist operation** (spec §11, §21) — the second model operation has no UI
  anywhere in Clockodile; building it now is speculative. The `AiProvider`
  interface should not forbid it later.
- **macOS and Linux targets**, and GPU builds (Vulkan/CUDA/…) — ticket 03 picked
  the CPU-only Windows x64 zip.
- **Resumable / Range-request downloads** and background download — the first
  cut blocks in a modal and restarts on failure.
- **Dropping the legacy AI settings columns** — they stay, feeding the hidden CLI
  providers.
- **Falling back to a CLI provider** when local inference fails — the CLI
  providers are hidden, so a fallback would silently send the user's text to a
  remote agent. Never implicit.
- **Tunable inference config in the UI** (ctx size, temperature, sleep idle) —
  `const AiConfig` only.
- **Log file on disk** for field diagnostics — the first cut logs through
  `dart:developer` only (ticket 08); add a file when a release needs it.
