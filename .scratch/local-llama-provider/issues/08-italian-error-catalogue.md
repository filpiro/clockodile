# 08 — Italian error-message catalogue for the local provider

**Type:** grilling
**Blocked by:** none
**Status:** resolved

## Question

Which normalized failures of the local provider (spec §17) does the user actually
see, and what exact Italian text does each one show? Where does it appear
(toast, status strip, install modal)?

Known inputs:

- 03 removed the VC++ runtime message and added **disk full during download** and
  **"Aggiornamento AI richiesto"** (pin mismatch).
- 05 merged the two model-failure shapes (truncated JSON with
  `finish_reason != "stop"`, and empty content) into one **"risposta non valida"**
  failure.
- 07 removed any "wrong language" failure: the parser does not detect language,
  and it does not validate word count.
- Still to catalogue: download failure/cancel, checksum mismatch, server start
  timeout (120 s), request timeout (90 s / 30 s), port unavailable, orphan
  process.

## Answer

Grilled 2026-09-15 in two rounds; the user accepted every recommendation.

### Where failures surface

1. **Install-time failures stay in the install modal.** The error text replaces
   the progress bar; buttons **Riprova** / **Chiudi**. Chiudi leaves the switch
   off. The partial file is deleted either way (charting decision 8).
2. **Annulla is silent.** Modal closes, partial file deleted, switch stays off.
   Not an error.
3. **Server failures → `LocalAiStatus.error` in the status strip**, one strip
   shape with **Riprova** (restart the server). Distinct text only where the
   user's remedy differs: "didn't start / crashed / model load failed" share one
   text; "no free port" has its own.
4. **One silent auto-restart** when `llama-server` dies while `ready`. The strip
   appears only if that restart fails too.
5. **Request-time failures → SnackBar on `EntryEditPage`**, as Riassumi does
   today; status stays `ready`. A single failed request says nothing about
   server health.
6. **Context overflow has its own message**; the input is never truncated
   client-side (a summary of half an email would pass as the whole).
7. **Orphan process is never user-visible.** PID-file kill is silent and logged;
   if it fails, port probing skips the busy port, so the worst case surfaces as
   "no free port".
8. **Missing files at app open reuse the pin-mismatch path** (`notInstalled`,
   Aggiorna action) with one neutral text covering both. **Supersedes ticket 03
   decision 10's "Aggiornamento AI richiesto" text.**
9. **UI shows Italian text only.** Raw diagnostics never reach the UI (unlike
   today's CLI flow, which shows the first stderr line).

### Catalogue

Install modal (buttons Riprova / Chiudi):

| Failure | Text |
|---|---|
| Network error, timeout, DNS, HTTP not 200 | `Download non riuscito. Controlla la connessione e riprova.` |
| SHA256 mismatch (zip or GGUF) | `File scaricato danneggiato. Riprova il download.` |
| Disk full (`FileSystemException`, Windows error 112) | `Spazio su disco insufficiente (servono circa 1,4 GB).` — size is the download actually in progress (~18 MB for a binary-only bump) |

Status strip:

| State | Text | Action |
|---|---|---|
| `notInstalled` with `aiEnabled` (pin mismatch or missing files) | `File AI mancanti o da aggiornare` | **Aggiorna (<size>)** |
| `starting` | `Avvio AI locale…` | none |
| `error` — start timeout (120 s), process exited twice, model load failed | `AI locale non avviata` | **Riprova** |
| `error` — no free port | `AI locale non avviata: nessuna porta libera (18080–18099)` | **Riprova** |

Port probing stops at **18099** (20 ports): new `AiConfig` constant
`portRangeEnd`.

Riassumi SnackBar (`EntryEditPage`):

| Failure | Text |
|---|---|
| Timeout (90 s cold / 30 s warm) | `L'AI locale non ha risposto in tempo. Riprova.` |
| Invalid response (`finish_reason != "stop"`, empty content, undecodable JSON) | `Risposta dell'AI non valida. Riprova.` |
| Context overflow | `Testo troppo lungo per l'AI locale. Accorcialo e riprova.` |

**Context overflow detection** — verified in llama.cpp source at tag `b10900`
(`tools/server/server-common.cpp`, `server-context.cpp`): the server answers
HTTP **400** with `{"error": {"code": 400, "type": "exceed_context_size_error",
"message": "request (N tokens) exceeds the available context size (M tokens)…",
"n_prompt_tokens": N, "n_ctx": M}}`. The parser matches on `error.type`, never
on the message string.

### Logging

`dart:developer` `log()` under name `clockodile.ai`: stderr tail, HTTP status and
body, Windows error code, timings. **Never the user's text** (spec §20). No file
on disk; a log file is out of scope until a release needs field diagnostics.

No ADR (reversible UI copy); no `CONTEXT.md` terms — messages are
implementation, not domain language.
