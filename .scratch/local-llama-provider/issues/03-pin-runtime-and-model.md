# 03 — Pin the runtime build, the model revision and the version policy

**Type:** grilling
**Blocked by:** 01, 02
**Status:** resolved

## Question

With the facts in from 01 and 02, decide what the app actually pins.

1. **Which llama.cpp Windows asset**: the CPU-only build that runs anywhere, or a
   Vulkan/CUDA build that is faster where the GPU exists and fails where it does
   not? A 1.7B model at ctx 8192 on CPU may already be fast enough to make the
   question moot — does the evidence from 01 say so?
2. **Which tag**, and what happens when it ages. Is the pin updated by hand in a
   release of Clockodile, or does the app ever look at "latest"? (A desktop app
   that resolves "latest" at install time gets a different binary per user and an
   unreproducible bug report.)
3. **Which model repo and revision**, given 02's answer on checksums — a moving
   `main` cannot be checksum-pinned.
4. **What happens when a pin changes** in a future Clockodile version and a user
   already has the old files on disk: silently re-download, prompt, or keep the
   old one until they ask? This decides whether the on-disk layout needs a
   version marker (`ai/bin/<tag>/`, a small `installed.json`) or a flat
   directory is enough.
5. **The VC++ runtime gap** (from 01): `llama-server.exe` links
   `VCRUNTIME140.dll` and the UCRT, which the zip does not carry. Detect it
   before spawning and tell the user to install the redistributable, ship the
   DLLs alongside the exe, or let the Windows loader error surface as-is?
6. **Tag policy, given `latest` is a trap** (from 01): the GitHub `latest`
   release carries no binaries at all — only per-commit `bNNNNN` tags do. So the
   pinned tag is a hand-updated constant by necessity. Does the app also record
   which tag it installed, so a future Clockodile can tell "old but fine" from
   "must re-download"?
7. **Disk-space precheck** before starting a ~1.4 GB download: check free space
   on the target volume, or let the write fail?

Feeds directly into ticket 04's spec sections on packaging and install.

## Answer

Grilled 2026-09-12/13; the user accepted every recommendation. Eleven decisions:

1. **CPU-only build.** `llama-<tag>-bin-win-cpu-x64.zip`. Ticket 01 has no
   throughput numbers, so "CPU is fast enough" rests on the user's own runs of
   this model; reopen only if ticket 05's latency breaks the 90 s cold timeout.
   GPU builds stay out of scope.
2. **Tag pin: a hand-bumped constant, no runtime lookup.** `const AiConfig`
   carries tag `b10900`, asset `llama-b10900-bin-win-cpu-x64.zip`, SHA256
   `47f6fe584bc8a6510c00f40ed103ec43db66a52f4eee23126b8379c9028fd107`. The app
   never calls the GitHub API (no 60/h limit, no `latest` trap, reproducible
   bug reports). Bumped by hand in a Clockodile release. Download URL:
   `https://github.com/ggml-org/llama.cpp/releases/download/<tag>/<asset>`.
3. **Model pin.** `bartowski/Qwen_Qwen3-1.7B-GGUF` @
   `dcb19155b962dbb6389f4691a982043a8e651022`, file
   `Qwen_Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,584 bytes, SHA256
   `72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb`. URL uses
   `resolve/<commit>/`, never `resolve/main/`. Also `AiConfig` constants.
4. **VC++ runtime: do nothing.** Checked 2026-09-12 with `objdump -p` on
   `build/windows/x64/runner/Release/clockodile.exe`: the app itself imports
   `MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll` and the UCRT, and
   the Release folder bundles none — a superset of what `llama-server.exe`
   needs. If Clockodile launched, the runtime is there. No precheck, no bundled
   DLLs, no Italian "installa Visual C++" message. The spec states this
   reasoning in one line so nobody "fixes" the gap.
5. **No disk-space precheck.** `dart:io` has no free-space API and `ffi` is only
   transitive. A full disk surfaces as a write `FileSystemException` (Windows
   error 112), mapped to an Italian message; decision 8's failure path already
   deletes the partial file.
6. **Pin change on an existing install: prompt, download only what changed.**
   Never silently download, never run a binary whose argv may no longer match.
   A binary-only bump prompts with the small size (~18 MB).
7. **Flat layout + `ai/installed.json`** = `{llamaTag, modelSha256}`, written
   **last**, only after both checksums pass — it is also the install-complete
   marker, so a crash mid-install reads as not installed. At app open,
   "installed" means: marker exists, matches both pins, and both files exist.
   No re-hash of the 1.3 GB model on every start.
8. **Model filename on disk keeps the upstream name**
   `models/Qwen_Qwen3-1.7B-Q4_K_M.gguf` — corrects charting decision 7's
   `Qwen3-1.7B-Q4_K_M.gguf`.
9. **Unzip the whole release into `bin/`**, wiping `bin/` first. The DLL graph
   changes per tag (`b10900` already split `llama-server.exe` from
   `llama-server-impl.dll`); filtering would break on the next bump.
10. **Mismatch at app open reuses `notInstalled`** — no new `LocalAiStatus`
    value. With `aiEnabled` true, Riassumi is disabled and the status strip
    shows "Aggiornamento AI richiesto" with an **Aggiorna (<size>)** action that
    runs the same confirm → modal download. No auto-opened dialog at launch.
11. **"Elimina modello" deletes all of `%LOCALAPPDATA%\Clockodile\ai\`** (server
    killed first) and turns the switch off. Re-enabling is a plain first install.

No ADR (ADR 0003 in ticket 04 covers the provider move); no new `CONTEXT.md`
terms — pins and markers are implementation, not domain language.
