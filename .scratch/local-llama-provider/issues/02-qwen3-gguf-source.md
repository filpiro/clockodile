# 02 — Qwen3-1.7B-Q4_K_M GGUF: canonical source and integrity

**Type:** research
**Blocked by:** none
**Status:** resolved

## Question

Where does `Qwen3-1.7B-Q4_K_M.gguf` come from, and how does the app verify it
arrived intact?

Answer against Hugging Face itself — the model repo pages and the HF API — not
mirrors or aggregator sites.

1. **Canonical repo.** Which Hugging Face repo is the one to pin: the official
   `Qwen/Qwen3-1.7B-GGUF`, `unsloth/Qwen3-1.7B-GGUF`, `bartowski/...`? Which
   actually publishes a `Q4_K_M` file, under exactly what filename?
2. **Direct download URL.** The `.../resolve/main/<file>` pattern, and — since
   `main` is a moving target — the pinned-revision form. Does it require an
   `Authorization` header or accepted terms for this model, or is it anonymous?
   What redirect chain does it serve (CDN hand-off), and does it honour
   `Content-Length` so a progress bar is possible?
3. **Exact size.** Confirm the ~1.28 GB figure in bytes, so the Italian confirm
   dialog and the disk-space precheck quote a true number.
4. **Integrity.** Does HF expose a checksum for the file (the LFS pointer's
   `sha256`, the `X-Linked-Etag` header, the API's file metadata)? Record where a
   pinned SHA256 is read from and how to obtain it for the pinned revision.
5. **Licence.** What licence does the pinned repo ship the GGUF under, and does
   redistributing-by-download inside a desktop app carry any attribution
   obligation worth a line in the Aiuto page?
6. **Chat template.** Does the GGUF embed a chat template Qwen3 needs, or must
   `llama-server` be given one? Qwen3 has a thinking mode — confirm how it is
   disabled for this file (the `--reasoning` flag from ticket 01, a template
   kwarg, or an `/no_think` prompt convention).

Capture findings as a Markdown file in the repo and link it here.

## Answer

Full findings: [`research/02-qwen3-gguf-source.md`](../research/02-qwen3-gguf-source.md).

1. **Repo and filename.** `bartowski/Qwen_Qwen3-1.7B-GGUF`, file
   `Qwen_Qwen3-1.7B-Q4_K_M.gguf` — note the `Qwen_` prefix, it is part of the
   filename. The official `Qwen/Qwen3-1.7B-GGUF` ships **no `Q4_K_M` at all**,
   only `Q8_0`, so the spec's implied source does not exist.
   `unsloth/Qwen3-1.7B-GGUF` does have a `Q4_K_M`, differently named and
   1,107,409,472 bytes — a different quantization, not the one the user
   benchmarked at ~1.28 GB.
2. **Download.** Anonymous, no token, no accepted terms. One 302 hop to HF's Xet
   CDN. `Content-Length` honoured at both hops, so a progress bar works;
   `accept-ranges: bytes` is served, which keeps resumable download available
   later even though the first cut does not use it.
3. **Exact size: 1,282,439,584 bytes.** Confirmed twice — the tree API's
   `size`/`lfs.size`, and the `x-linked-size`/`content-length` headers on the
   real redirect.
4. **SHA256:** `72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb`,
   read from the tree API's `lfs.oid`, independently reproduced by the
   `X-Linked-ETag` header. **Trap:** the same API payload carries `xetHash`
   (`e864889b...`), HF's newer Xet content hash, which is *not* a SHA256. Pinning
   that value would fail every verification.
   Pinned revision: `dcb19155b962dbb6389f4691a982043a8e651022`. `main` moves, so
   the checksum only means anything against this commit.
5. **Licence.** Apache-2.0, inherited from the base model `Qwen/Qwen3-1.7B`.
   bartowski's card does not restate a licence for the quantization itself — not
   independently confirmed, worth one attribution line in Aiuto.
6. **Thinking mode off:** `--chat-template-kwargs '{"enable_thinking": false}'`
   (or per-request `chat_template_kwargs`). This is the exact kwarg the GGUF's
   own embedded Jinja template tests — confirmed by reading `gguf.chat_template`
   out of the API. `--reasoning off` / `--reasoning-budget 0` are
   template-agnostic fallbacks; the `/no_think` prompt suffix is a soft switch
   Qwen's card says the hard switch overrides. Do not rely on the suffix.

**Contradicts the draft spec** (`docs/llama.cpp/flutter_llama_cpp_provider_spec.md`):
the model filename, the source repo, and `--reasoning off` as the way to
suppress thinking.
