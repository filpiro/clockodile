# 01 — llama.cpp Windows x64 release: assets, flags, endpoints

**Type:** research
**Blocked by:** none
**Status:** resolved

## Question

What exactly does the app download and run on Windows x64, and do the flags the
spec assumes actually exist in that release?

Answer against primary sources — the `ggml-org/llama.cpp` GitHub releases API and
the repo's own `tools/server/README.md` — not blog posts.

1. **Release assets.** For a recent tagged release, list the Windows x64 assets
   (`llama-<tag>-bin-win-*.zip`). What distinguishes `cpu`, `vulkan`, `cuda`,
   `hip`, `sycl`, and the `avx2`/`avx512`/`noavx` variants? Which are CPU-only
   and run on any x64 machine with no extra runtime installed?
2. **Zip contents.** Does the chosen zip contain `llama-server.exe` plus every
   DLL it needs (`ggml*.dll`, `llama.dll`, any MSVC redistributable), or is a
   separate download required? What is the unpacked size?
3. **Download mechanics.** The direct asset URL pattern; whether it redirects
   (`objects.githubusercontent.com`) — `dart:io` `HttpClient` does not follow
   redirects the way `http` does, so record what a client must handle. Is
   anonymous download rate-limited?
4. **Checksums.** Does the release publish per-asset SHA256 (a manifest file, the
   release body, the API payload)? If not, where does a pinned hash come from?
5. **Flag verification.** Confirm these exist and are spelled this way in that
   release: `--sleep-idle-seconds`, `--reasoning off` (or is it
   `--reasoning-budget` / `--chat-template-kwargs`?), `--ctx-size`, `--parallel`,
   `--host`, `--port`, `-m`. Flag names have churned; the spec is a draft.
6. **Endpoints.** `GET /health` — response body and status codes while the model
   is still loading, once ready, and while sleeping after
   `--sleep-idle-seconds`. Also `GET /props` and `GET /v1/models` shapes.
7. **Structured output.** How `response_format` with
   `{"type":"json_schema", ...}` is spelled on `POST /v1/chat/completions`, and
   whether that release enforces the schema (GBNF-constrained) or merely asks.
   Cross-check `docs/llama.cpp/llama_server_postman_collection.json`, which holds
   the shapes the user actually tested.
8. **Timing metadata.** Which of `prompt_tokens`, `completion_tokens`,
   `prompt_ms`, `predicted_ms`, `cached_tokens` appear in the response (`usage`
   vs `timings`), for spec §19.

Capture findings as a Markdown file in the repo and link it here.

## Answer

Full findings: [`research/01-llama-cpp-windows-release.md`](../research/01-llama-cpp-windows-release.md).
Release examined: tag `b10900`, commit `50182a53`, published 2026-09-10.

1. **Assets.** `llama-b10900-bin-win-cpu-x64.zip` is the one. This release no
   longer ships `avx2`/`avx512`/`noavx` variants — one CPU package carries several
   `ggml-cpu-<microarch>.dll`s (haswell, alderlake, zen4, sse42, …) and dispatches
   at runtime. `vulkan`/`cuda`/`hip`/`sycl` all need a driver or toolkit present.
2. **Zip contents.** 18.4 MB zipped, 44.6 MB unpacked, 51 files, `llama-server.exe`
   plus its `ggml*.dll`/`llama.dll` included. **Gap:** the exe dynamically links
   `VCRUNTIME140.dll` and the UCRT, and neither is in the zip or published as a
   separate asset — a machine without the VC++ redistributable fails at spawn with
   a Windows loader error, not a llama.cpp message.
3. **Download.** Asset URLs redirect to `release-assets.githubusercontent.com`
   (not `objects.githubusercontent.com`, as the ticket guessed). **Trap:**
   `GET /releases/latest` resolves to `v0.4.0`, a version tag carrying **no
   binaries** — only a `nightly-tag.txt` pointer. The binaries live under
   per-commit `bNNNNN` tags. Any code that follows "latest" gets nothing.
4. **Checksums.** The GitHub API returns a per-asset `digest: sha256:...` field
   directly; verified byte-for-byte against the downloaded zip. No manifest needed.
5. **Flags — all seven exist, exactly as the spec spells them**, with
   `common/arg.cpp` line numbers quoted in the report: `--sleep-idle-seconds`,
   `-rea/--reasoning [on|off|auto]`, `-c/--ctx-size`, `-np/--parallel`, `--host`,
   `--port`, `-m/--model`. The draft spec's flag list survives contact.
6. **Endpoints.** `/health` returns 200 `{"status":"ok"}` **even while sleeping**
   (confirmed in `server-context.cpp`). It answers "is the server up", never "is
   the model resident". Only `GET /props`'s `is_sleeping` distinguishes them. Good
   enough for the startup gate; useless for sleep detection.
7. **Structured output.** `response_format` with `{"type":"json_schema", ...}` is
   genuinely GBNF-enforced upstream, not merely requested. **But** the local
   `llama_server_postman_collection.json` never sends `response_format` at all and
   saves no response bodies — so the user's own testing gives zero evidence for
   spec §9. See ticket 05.
8. **Timing metadata.** Present, but `cached_tokens` sits at
   `usage.prompt_tokens_details.cached_tokens`, not as a flat field.
