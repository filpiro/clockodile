# Research: llama.cpp Windows x64 release — assets, flags, endpoints

Answers the 8 questions in `.scratch/local-llama-provider/issues/01-llama-cpp-windows-release.md`.

## Release examined

- **Tag:** `b10900` (ggml-org/llama.cpp uses two tag families: `v0.x.y` "stable" tags that carry no binaries — only a `nightly-tag.txt` pointer — and per-commit `bNNNNN` tags, marked `prerelease: true` on the API, that carry the actual 27 binary assets. `b10900` is the newest `bNNNNN` at research time.)
- **Published:** 2026-09-10T19:00:20Z
- **Commit:** `50182a53fa2c26bd2a7fc31d855231effdc2f4ad` (release `target_commitish`)
- **Release page:** https://github.com/ggml-org/llama.cpp/releases/tag/b10900
- **API used:** `https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/b10900` (and `/releases?per_page=10` to find it — `/releases/latest` resolves to `v0.4.0`, which is the no-binaries pointer tag, so it is the wrong endpoint to use for asset discovery)
- **Docs pinned to the same commit:** `tools/server/README.md` and `common/arg.cpp` fetched at raw.githubusercontent.com/.../50182a53fa2c26bd2a7fc31d855231effdc2f4ad/... — byte-identical to the `master`-branch copies fetched the same session, confirming no drift between "master docs" and "the commit this binary was built from" as of 2026-09-11.
- **Research date:** 2026-09-11

Everything below is sourced from these three primary artifacts (release API JSON, `tools/server/README.md`, `common/arg.cpp`) plus direct inspection of the downloaded `.zip` (unzipped and disassembled locally), except where explicitly marked "not confirmed."

---

## 1. Release assets

Full Windows asset list for `b10900` (27 assets total, all platforms):

| Asset | Size | Backend |
|---|---|---|
| `llama-b10900-bin-win-cpu-x64.zip` | 18,423,427 B (~17.6 MB) | CPU, x64 |
| `llama-b10900-bin-win-cpu-arm64.zip` | 11,990,644 B | CPU, arm64 |
| `llama-b10900-bin-win-vulkan-x64.zip` | 31,666,109 B | Vulkan (GPU, vendor-neutral) |
| `llama-b10900-bin-win-cuda-12.4-x64.zip` | 254,079,820 B | CUDA 12.4 (NVIDIA) |
| `llama-b10900-bin-win-cuda-13.3-x64.zip` | 149,706,788 B | CUDA 13.3 (NVIDIA) |
| `llama-b10900-bin-win-cuda-13.4-arm64.zip` | 142,955,926 B | CUDA 13.4, arm64 |
| `cudart-llama-bin-win-cuda-12.4-x64.zip` | 391,443,627 B | CUDA 12.4 **runtime DLLs only** (companion to the cuda-12.4 build above) |
| `cudart-llama-bin-win-cuda-13.3-x64.zip` | 390,970,417 B | CUDA 13.3 runtime DLLs |
| `cudart-llama-bin-win-cuda-13.4-arm64.zip` | 153,262,407 B | CUDA 13.4 arm64 runtime DLLs |
| `llama-b10900-bin-win-rocm-10.0-x64.zip` | 244,151,207 B | ROCm 10.0 (AMD) — **note: not called `hip` in this release** |
| `llama-b10900-bin-win-sycl-x64.zip` | 119,781,153 B | SYCL (Intel oneAPI) |
| `llama-b10900-bin-win-openvino-2026.3.1-x64.zip` | 80,300,376 B | Intel OpenVINO |
| `llama-b10900-bin-win-opencl-adreno-arm64.zip` | 12,782,822 B | OpenCL, Qualcomm Adreno arm64 |

**No `avx2` / `avx512` / `noavx` variants exist in this release.** This is the key naming-churn finding for this question: older llama.cpp releases split the CPU package by instruction set (`win-avx2-x64`, `win-avx512-x64`, `win-noavx-x64`, etc.); this release instead ships **one** `llama-b10900-bin-win-cpu-x64.zip` containing multiple `ggml-cpu-<microarch>.dll` files (`sse42`, `x64` baseline, `sandybridge`, `ivybridge`, `haswell`, `alderlake`, `skylakex`, `cascadelake`, `cooperlake`, `cannonlake`, `icelake`, `sapphirerapids`, `zen4`, `piledriver`) and dispatches to the best one for the running CPU at startup. Confirmed by enumerating the full asset list (no avx-named assets present) and by unzipping the cpu package (see §2). Do not hardcode an assumption of avx2/avx512/noavx asset names for this or newer releases — check the actual asset list at install time.

**Which are CPU-only / no extra runtime:** only `llama-b10900-bin-win-cpu-x64.zip` (and its arm64 counterpart) run with nothing beyond the OS — see §2 for the one caveat (VC++ runtime). Every other Windows variant needs a matching GPU driver/SDK:
- **cuda**: needs the matching NVIDIA driver, and either a system CUDA install or the separate `cudart-llama-bin-win-cuda-*-x64.zip` runtime-DLL bundle (confirmed as a *separate* asset from the binary zip — two downloads, not one).
- **vulkan**: needs a Vulkan-capable GPU driver (usually present with any recent GPU driver, not guaranteed on a driver-less/RDP/VM machine).
- **rocm**: needs AMD ROCm runtime installed.
- **sycl**: needs Intel oneAPI runtime.
- **openvino**: needs the Intel OpenVINO runtime.

**Recommendation for this app:** `llama-b10900-bin-win-cpu-x64.zip` — CPU-only, x64, self-dispatching across microarchitectures, no GPU dependency.

## 2. Zip contents

Downloaded and unzipped `llama-b10900-bin-win-cpu-x64.zip` directly (sha256-verified — see §4).

- **Zip size:** 18,423,427 bytes (~17.6 MB)
- **Unpacked size:** 46,746,909 bytes (~44.6 MB) across 51 files
- Contains `llama-server.exe` (9,216 B — a thin launcher), `llama-server-impl.dll` (8,893,440 B — the actual server logic), all `ggml*.dll` variants, `llama-common.dll`, `mtmd.dll`, `ggml-rpc.dll`/`ggml-rpc-server.exe`, `libomp.dll` (OpenMP runtime, bundled), and every other CLI tool (`llama-cli.exe`, `llama-bench.exe`, `llama-quantize.exe`, etc. — the zip is the full toolset, not a server-only package).
- **Not bundled:** the Microsoft Visual C++ runtime. Confirmed via `objdump -p llama-server.exe`: it dynamically imports `VCRUNTIME140.dll` and the Universal CRT (`api-ms-win-crt-heap-l1-1-0.dll`, `-locale-`, `-math-`, `-runtime-`, `-stdio-`), and **none of these DLLs are present in the zip**. The release also publishes no `vc_redist.x64.exe` asset. In practice VCRUNTIME140/UCRT are present on most updated Windows 10/11 machines (many apps install them, and Windows Update ships UCRT), but this is not guaranteed on a clean/minimal image and llama.cpp does not provide or bundle it — the app's runtime manager should treat "missing VCRUNTIME140.dll" as a possible startup failure mode and, if it needs to be bulletproof, bundle/prompt for the VC++ Redistributable separately.
- So: **no separate download is required for the CPU inference stack itself**, but the OS may be missing the VC++ redistributable it silently depends on.

## 3. Download mechanics

- **Asset URL pattern:** `https://github.com/ggml-org/llama.cpp/releases/download/<tag>/<asset-name>` (this is the stable, permanent `browser_download_url` from the API).
- **Redirect:** confirmed via `curl -I`: this URL returns **HTTP 302** with `Location:` pointing to `https://release-assets.githubusercontent.com/github-production-release-asset/...` with a signed, time-limited query string (`se=...` expiry ~1 hour from generation, SAS-style signature). **Note this is `release-assets.githubusercontent.com`, not `objects.githubusercontent.com`** — the ticket's guessed domain is the old one; GitHub migrated release-asset delivery to `release-assets.githubusercontent.com` at some point before this research date. A client must follow this redirect and must not cache/reuse the resolved signed URL beyond its short expiry — always re-resolve from the stable `github.com/.../releases/download/...` URL. `dart:io HttpClient` needs `followRedirects` (default `true`) and enough `maxRedirects` (default 5, sufficient here — one hop observed); if code has set `followRedirects = false` or relies on manual redirect handling, it must explicitly follow the `302`/`Location` header itself. (This is a Dart-runtime behavior claim, not verifiable against llama.cpp's own docs — flagging it as a general dart:io fact rather than something confirmed from the llama.cpp primary sources.)
- **Rate limiting:** the GitHub REST API itself is rate-limited for anonymous callers — confirmed via response headers: `x-ratelimit-limit: 60` (60 requests/hour per IP for unauthenticated API calls). This applies to calls like `/releases/tags/<tag>`, not to the asset bytes themselves. **Whether the actual asset download (through the `release-assets.githubusercontent.com` redirect) is separately rate-limited or throttled for anonymous/high-volume use could not be confirmed from a primary source** — GitHub does not publish an explicit anonymous-download rate limit for release assets. Treat this as an open risk (add retry/backoff) rather than assume it's unlimited.

## 4. Checksums

**Yes** — the GitHub Releases API returns a per-asset `digest` field directly in the JSON payload (no separate manifest file needed), e.g. for this asset:

```
"digest": "sha256:47f6fe584bc8a6510c00f40ed103ec43db66a52f4eee23126b8379c9028fd107"
```

This was verified against the actual downloaded bytes:

```
$ sha256sum llama-cpu.zip
47f6fe584bc8a6510c00f40ed103ec43db66a52f4eee23126b8379c9028fd107  llama-cpu.zip
```

Match confirmed. So a pinned hash should come from `GET /repos/ggml-org/llama.cpp/releases/tags/<tag>` → `assets[].digest`, not from the release body/description (the release body for `b10900` contains no checksum manifest — it's just a changelog and a Markdown list of per-platform download links) and not from a separate `.sha256` file (none is published as an asset).

## 5. Flag verification

All confirmed **in `common/arg.cpp` at commit `50182a53fa2c26bd2a7fc31d855231effdc2f4ad`** (the exact commit tagged `b10900`), and cross-checked against `tools/server/README.md` at the same commit (identical wording). Every flag the spec assumes exists, spelled exactly as the spec wrote it:

| Flag | Exists? | Exact spelling | Source line (`common/arg.cpp`) |
|---|---|---|---|
| `--sleep-idle-seconds` | Yes | `--sleep-idle-seconds SECONDS` (no short form) | `L3797: {"--sleep-idle-seconds"}, "SECONDS", string_format("number of seconds of idleness after which the server will sleep (default: %d; -1 = disabled)", ...)` |
| `--reasoning off` | Yes | `-rea, --reasoning [on\|off\|auto]` | `L3677: {"-rea", "--reasoning"}, "[on\|off\|auto]", "Use reasoning/thinking in the chat ('on', 'off', or 'auto', default: 'auto' ...)"` — takes a value, so `--reasoning off` is correct (not `--reasoning-budget`, that flag doesn't exist under that name; there is a separate `--reasoning-effort LEVEL` for a different purpose — see below) |
| `--ctx-size` | Yes | `-c, --ctx-size N` | `L1636: {"-c", "--ctx-size"}, "N", string_format("size of the prompt context (default: %d, 0 = loaded from model)", ...)` |
| `--parallel` | Yes | `-np, --parallel N` | `L2541/2552: {"-np", "--parallel"}, "N", string_format("number of server slots (default: %d, -1 = auto)", ...)` |
| `--host` | Yes | `--host HOST` (no short form) | `L3310: {"--host"}, "HOST", string_format("ip address to listen, or bind to an UNIX socket if the address ends with .sock (default: %s)", ...)` |
| `--port` | Yes | `--port PORT` (no short form) | `L3317: {"--port"}, "PORT", string_format("port to listen (default: %d)", ...)` |
| `-m` | Yes | `-m, --model FNAME` | `L3031: {"-m", "--model"}, "FNAME", "model path to load"` |

Related flags that exist but are **not** what the spec named (confirming the spec's parenthetical worry was right to raise, wrong in outcome — `--reasoning` is fine as spelled):
- `--reasoning-effort LEVEL` (`'default'`, `'minimal'`, `'low'`, `'medium'`, `'high'`, `'xhigh'`...) — a template-facing knob, separate from `-rea/--reasoning`.
- `--reasoning-format FORMAT` (`none`/`deepseek`/`deepseek-legacy`) — controls how `<think>` output is parsed/returned, also separate.
- `--chat-template-kwargs` was not found as a top-level CLI flag name in `arg.cpp`; the equivalent per-request JSON body field is `chat_template_kwargs` (e.g. `{"enable_thinking": false}`), documented in `tools/server/README.md` line 1318. If a CLI-level default for template kwargs is needed, it isn't under that exact flag spelling — not confirmed to exist as a CLI arg at all in this release.

Every flag every server option also exposes an environment-variable equivalent (`LLAMA_ARG_*`), which the spec doesn't currently use — worth keeping in mind as an alternative to building an argv array (e.g. `LLAMA_ARG_MODEL`, `LLAMA_ARG_HOST`, `LLAMA_ARG_PORT`, `LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_N_PARALLEL`, `LLAMA_ARG_REASONING`). No env var was found for `--sleep-idle-seconds` (no `.set_env(...)` call on that `add_opt` — confirmed by reading the surrounding source, only argv works for it).

## 6. Endpoints

Source: `tools/server/README.md` + `tools/server/server-context.cpp` (source code, same commit).

**`GET /health`:**
- **503**, body `{"error": {"code": 503, "message": "Loading model", "type": "unavailable_error"}}` — while the model is still loading (handled by middleware, before the route body runs).
- **200**, body `{"status": "ok"}` — once ready.
- **While sleeping (post `--sleep-idle-seconds`): also 200 `{"status":"ok"}`.** Confirmed directly in source (`server-context.cpp`, `get_health` lambda): the comment reads "this endpoint can be accessed during sleeping" and the handler unconditionally returns `res->ok({{"status", "ok"}})` without touching server/model state. **`/health` does not distinguish "ready" from "sleeping"** — both return 200. To detect sleep state, the app must call `GET /props` and read `is_sleeping`. This is an important correction to any assumption that `/health` alone reflects the full lifecycle in §3 of the spec ("wait until `/health` reports ready") — fine for the startup wait, but insufficient for detecting sleep/cold-start state later.
- `README.md` also confirms `GET /health`, `GET /props`, `GET /models`, `GET /metrics` are all exempt from waking the server / resetting the idle timer — polling health for liveness will not keep the model warm.

**`GET /props`:** returns (among other fields) `total_slots`, `model_path`, `chat_template`, `build_info`, and **`is_sleeping`** (boolean) — this is the only place sleep state is exposed.

**`GET /v1/models`:** OpenAI-shaped list, always exactly one element:
```json
{
  "object": "list",
  "data": [{
    "id": "<model path, or --alias if set>",
    "object": "model",
    "created": 1735142223,
    "owned_by": "llamacpp",
    "meta": { "vocab_type": 2, "n_vocab": ..., "n_ctx_train": ..., "n_embd": ..., "n_params": ..., "size": ... }
  }]
}
```
`meta` can be `null` while the model is still loading.

## 7. Structured output

`tools/server/README.md` (line 1316): `response_format` supports both `{"type": "json_object"}` (plain JSON, optionally with a bare `"schema"` for light validation) and **`{"type": "json_schema", "schema": {...}}`** for schema-constrained output — this is grammar/GBNF-backed constrained sampling (`-j/--json-schema` CLI flag description at line 153 says explicitly "JSON schema to constrain generations", i.e. it **enforces**, not merely requests, the schema via grammar-based sampling — same mechanism documented at line 571 ("Set a JSON schema for grammar-based sampling")). So: enforced, not advisory.

**Cross-check against `docs/llama.cpp/llama_server_postman_collection.json`: disagreement found.** The collection's "Chat Completion" request body is:
```json
{
  "model": "{{model}}",
  "messages": [{"role": "user", "content": "Rispondi solo con: OK"}],
  "temperature": 0,
  "max_tokens": 20
}
```
**No `response_format` field appears anywhere in the collection.** The user's actually-tested request never exercised `json_schema`/structured output at all — only a bare, unconstrained chat completion. The collection also has no saved response bodies (no `response: [...]` arrays under any item), so it records *what was sent*, not *what came back*. This means: the spec's §9 assumption ("use JSON Schema constrained output through `response_format`") is **untested** by the artifact that's supposed to reflect real usage — it's aspirational from upstream docs, not yet validated locally. That gap should be closed with an actual test request (add a `response_format: {"type":"json_schema", "schema": {...}}` item to the collection) before relying on it in the provider implementation.

The collection also never exercises `GET /props` (only `/health`, `/v1/models`, `/v1/chat/completions`), so the `is_sleeping` behavior from §6 is likewise unverified locally, only from upstream docs/source.

## 8. Timing metadata

Confirmed from `tools/server/README.md` (lines ~1399–1437), for `/v1/chat/completions` (and `/completion`) responses — both objects appear in the same response, unconditionally (not gated behind `timings_per_token`, which only controls *per-token streaming* timing entries and defaults to `false`):

- **`usage` object** (OpenAI-standard shape): `completion_tokens`, `prompt_tokens`, `total_tokens`, and `prompt_tokens_details.cached_tokens` (nested, not top-level).
- **`timings` object** (llama.cpp-specific extension): `cache_n`, `prompt_n`, `prompt_ms`, `prompt_per_token_ms`, `prompt_per_second`, `predicted_n`, `predicted_ms`, `predicted_per_token_ms`, `predicted_per_second`.

Mapping to the spec's §19 field list:
- `prompt_tokens` → `usage.prompt_tokens`
- `completion_tokens` → `usage.completion_tokens`
- `cached_tokens` → `usage.prompt_tokens_details.cached_tokens` (nested; the spec's flat naming needs adjusting)
- `prompt_ms` → `timings.prompt_ms`
- `predicted_ms` → `timings.predicted_ms`
- `prompt_per_second` / `predicted_per_second` (spec §19 also lists these) → `timings.prompt_per_second` / `timings.predicted_per_second`

All present by default on a normal (non-streaming) chat completion response; no request flag needed to get the top-level `timings`/`usage` blocks.

---

## Summary of contradictions / corrections vs. the draft spec

1. **CPU asset naming**: no `avx2`/`avx512`/`noavx` variants exist in this release — one `llama-b10900-bin-win-cpu-x64.zip` with runtime microarchitecture dispatch. Don't hardcode old naming.
2. **Redirect domain**: asset downloads redirect to `release-assets.githubusercontent.com`, not `objects.githubusercontent.com`.
3. **VC++ runtime**: `llama-server.exe` needs `VCRUNTIME140.dll` + UCRT at runtime; neither is bundled in the zip nor published as a separate release asset. Not a certainty on every clean Windows box.
4. **`/health` during sleep**: still returns 200 `{"status":"ok"}` — cannot be used to detect sleep. Must poll `/props.is_sleeping` instead.
5. **Structured output is untested locally**: the Postman collection never sends `response_format`, so §9's schema-constrained approach has upstream doc support (and is genuinely enforced via GBNF grammar) but zero local validation evidence yet.
6. **`cached_tokens` is nested** under `usage.prompt_tokens_details`, not a flat top-level field.
7. All 7 flags in question 5 (`--sleep-idle-seconds`, `--reasoning`, `--ctx-size`, `--parallel`, `--host`, `--port`, `-m`) are confirmed to exist with exactly the spelling the spec used.
