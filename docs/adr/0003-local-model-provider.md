# 3. Note Summaries come from a local model by default; the CLI providers survive hidden

Date: 2026-09-15

## Status

Accepted. Amends the consequences of ADR 0002; supersedes nothing in it.

## Context

ADR 0002 made Note Summaries a job for a coding-agent CLI the user already had:
Claude Code, Codex or OpenCode. Using it showed three costs that ADR did not
weigh:

- **Only a developer can use it.** The feature needs one of those CLIs installed
  and signed in. On Windows that usually also means WSL and WSL Mode.
- **An agent is slow at a small job.** A CLI starts an agentic session to write
  fifteen words, and the 60 s timeout exists because it sometimes needs it.
- **The client's email goes to a remote model.** A local-only time tracker sends
  the most sensitive text it handles off the machine.

ADR 0002 rejected a bundled local model as "hundreds of megabytes of weights".
Two facts have changed that verdict since. A 1.7B model quantized to Q4_K_M
(1.28 GB) writes the line in ~5 s warm and ~11 s cold on a CPU. `llama.cpp`'s
`llama-server` also runs that model behind a localhost HTTP API, with
JSON-Schema-constrained output. Both were measured on the dev box, with
evidence under `docs/llama.cpp/fixtures/`.

## Decision

The default and only visible AI provider is a **Local Model**: `llama-server`
from `llama.cpp` running Qwen3-1.7B Q4_K_M on `127.0.0.1`, started and stopped
by Clockodile.

- **Downloaded on first enable, not bundled.** The installer stays small, and
  users who never enable AI never pay 1.3 GB. The CPU-only Windows x64 build and
  the GGUF go to `%LOCALAPPDATA%\Clockodile\ai\`.
- **Pinned and verified.** Exact `llama.cpp` tag, exact Hugging Face commit, a
  SHA256 for each, all hand-bumped constants. The app never asks GitHub or HF
  what is "latest". A pin change prompts the user before downloading.
- **Italian prompt, JSON Schema output.** The prompt language decides the output
  language on this model, so the prompt is Italian. Free text never parsed, so
  the schema is required.
- **One interface, `AiProvider`,** sits between the UI and every source. The
  existing enum that names a CLI becomes `AiProviderKind`.
- **The CLI providers are hidden, not deleted.** Their code moves behind
  `AiProvider`, keeps its tests, and loses its Settings controls. There is no
  escape hatch to select them.
- **No fallback.** If local inference fails, the user sees an Italian error. The
  request is never retried through a CLI, because that would silently send the
  text to a remote model.

Alternatives rejected:

- **Bundle the binary and model in the installer.** It adds 1.3 GB to every
  install and every update, for a feature that is off by default.
- **Keep the CLI as the default, with local as an option.** It keeps the
  developer-only default and the remote-by-default privacy position.
- **Delete the CLI providers.** Keeping them behind the interface costs little,
  and deleting them throws away working, tested code that a later effort may
  want to offer again.
- **An API-key provider.** Still rejected, for ADR 0002's reasons.

## Consequences

ADR 0002 said Clockodile "still holds no credentials and still opens no sockets
of its own". The first half still holds. The second no longer does:

- **Clockodile now makes network requests.** They happen only when the user
  confirms a download, and only to `github.com` (runtime) and `huggingface.co`
  (model), both anonymous. Note text is never sent anywhere.
- **Clockodile now runs a child HTTP server.** It binds `127.0.0.1` only, on the
  first free port in 18080–18099. The app kills it on close, and kills a crash
  orphan on the next start, but only the PID it wrote itself.

ADR 0002's accepted limits change as follows:

- "Unavailable to anyone without one of these CLIs" no longer applies. The new
  requirement is Windows x64, about 1.3 GB of disk, and a one-time download.
- "Failures are the CLI's, surfaced not swallowed … the CLI's first stderr line"
  no longer describes what users see. Local failures are normalized to a short
  Italian catalogue, and raw diagnostics go to `dart:developer` logs only.
- The agentic-CLI limits (temp-dir cwd, 60 s timeout) and the WSL Mode limits
  now apply only to the hidden providers.
- A successful generation is still destructive, with no undo. That part of ADR
  0002 is unchanged.

New costs accepted:

- **~20% of RAM on a 24 GB machine** while the model is loaded. After 60 s idle
  the server sleeps, and the next request pays a ~6 s cold start.
- **Pins age.** A newer `llama.cpp` or model arrives only with a Clockodile
  release. Every bump reruns the verification scripts under
  `docs/llama.cpp/fixtures/`.
- **Upstream availability.** If GitHub or HF moves or removes a pinned file,
  first installs fail with the download error until a release re-pins.
- **Windows only.** macOS and Linux have no AI until a later effort.
