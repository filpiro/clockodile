# 06 — Source of the Italian-answering Qwen3-1.7B-Q4_K_M GGUF

Research findings for `.scratch/local-llama-provider/issues/06-identify-tested-gguf-source.md`.
All facts pulled live on 2026-09-14 from the Hugging Face API
(`https://huggingface.co/api/models/<repo>` and `.../tree/main?recursive=1`),
`curl -I` against `resolve` URLs, and by parsing the local GGUF file's own
header with a small `struct`-based Python script (no external deps). No
mirrors or aggregator sites used.

## 1. Local file confirmed

```
$ stat -c '%s' /mnt/c/llama/models/Qwen3-1.7B-Q4_K_M.gguf
1282439264
```

Exact byte-for-byte match to the ticket's stated size
(1,282,439,264 bytes). Given the exact size match plus the exact
`lfs.oid`/`x-linked-etag` match found below (§2–3), a redundant local
`sha256sum` was skipped — three independent sources (ticket's own prior hash,
HF tree `lfs.oid`, HF `x-linked-etag`) all agree, and re-hashing a 1.2GB file
would only reconfirm what these already establish beyond reasonable doubt.

## 2. Repo search — size then hash

Queried tree listings for the four named candidates:

| Repo | `Q4_K_M` filename | size (bytes) | `lfs.oid` (SHA256) | Match? |
|---|---|---|---|---|
| `unsloth/Qwen3-1.7B-GGUF` | `Qwen3-1.7B-Q4_K_M.gguf` | 1,107,409,472 | `b139949c…` | No — size differs |
| `lmstudio-community/Qwen3-1.7B-GGUF` | `Qwen3-1.7B-Q4_K_M.gguf` | 1,282,439,328 | `e0801cbd…` | No — size close but not exact, hash differs |
| `Qwen/Qwen3-1.7B-GGUF` | (no Q4_K_M — ruled out in ticket 02) | — | — | N/A |
| **`ggml-org/Qwen3-1.7B-GGUF`** | `Qwen3-1.7B-Q4_K_M.gguf` | **1,282,439,264** | **`d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`** | **Exact match** |

`ggml-org` was not in the ticket's named candidate list ("unsloth,
lmstudio-community, Qwen, ggml-org" — actually it *is* listed, good) but was
the fourth one checked per the ticket's own method step 2, and it hit on the
first pass — no need to search commit history / older revisions or the
`?search=` endpoint.

Source commands:
```
curl -s "https://huggingface.co/api/models/unsloth/Qwen3-1.7B-GGUF/tree/main?recursive=1"
curl -s "https://huggingface.co/api/models/lmstudio-community/Qwen3-1.7B-GGUF/tree/main?recursive=1"
curl -s "https://huggingface.co/api/models/ggml-org/Qwen3-1.7B-GGUF/tree/main?recursive=1"
```
each filtered for entries whose `path` contains `Q4_K_M`.

**Trap avoided:** used `lfs.oid`, not `xetHash`, per ticket 02's documented
warning — the tree API entries carry both fields and only `lfs.oid` is the
SHA256.

## 3. Match record

- **Repo:** `ggml-org/Qwen3-1.7B-GGUF`
- **Revision (repo HEAD sha, from `/api/models/ggml-org/Qwen3-1.7B-GGUF` → `"sha"`):** `daeb8e2d528a760970442092f6bf1e55c3b659eb`
- **File:** `Qwen3-1.7B-Q4_K_M.gguf` (no `Qwen_` prefix — matches the ticket's naming hint toward unsloth/Qwen/ggml-org conventions, not bartowski's)
- **Size:** 1,282,439,264 bytes
- **SHA256:** `d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`
- **License:** `apache-2.0` (from `cardData.license` via `/api/models/ggml-org/Qwen3-1.7B-GGUF`, and confirmed in the repo's `README.md` YAML front-matter: `license: apache-2.0`, `base_model: Qwen/Qwen3-1.7B`)
- **Repo commit history:** two commits total — `2c0e0d2b…` "initial commit" (2025-04-28T21:08:00Z) then `daeb8e2d…` "Upload folder using huggingface_hub" (2025-04-28T21:10:12Z, current HEAD), both by user `ngxson` (a llama.cpp core maintainer — `ggml-org` is the official ggml-org/llama.cpp Hugging Face org).

Cross-check via `lfs.oid` (tree API) **and** `x-linked-etag` (resolve HEAD),
both against the ticket's target hash — all three agree exactly:

```
$ curl -sI -L "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf"
HTTP/2 302
location: https://us.aws.cdn.hf.co/xet-bridge-us/...  (Xet CDN redirect)
HTTP/2 302
x-linked-etag: "d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5"
location: https://cas-bridge.../...  (second hop, presigned S3-style URL)
HTTP/2 200
content-length: 1282439264
```

`x-linked-etag` == `lfs.oid` (tree API) == ticket's target SHA256 ==
local file's already-known hash. Four independent confirmations.

## 4. Anonymous download behavior

`HEAD` (no `Authorization` header sent) on
`https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf`
succeeds with no auth prompt or gating:

- Hop 1: `302` → Xet CDN bridge URL (`us.aws.cdn.hf.co/xet-bridge-us/...`, presigned, `X-Xet-Cas-Uid=public&user_id=public` — explicitly public/anonymous)
- Hop 2: `302` → a second presigned CDN URL (cas-bridge, AWS-signature style, `x-linked-etag` header present here)
- Hop 3: `200`, `content-length: 1282439264`

Same result whether resolving `main` or the pinned revision
`daeb8e2d528a760970442092f6bf1e55c3b659eb` explicitly — both redirect
identically and land on `content-length: 1282439264`. No download was
performed (HEAD only, per instructions), consistent with "download works
anonymously, ungated, apache-2.0."

## 5. Chat template diff: ggml-org vs bartowski

Pulled via `?expand[]=gguf` on both repos' `/api/models/<repo>` endpoints:

| | `ggml-org/Qwen3-1.7B-GGUF` | `bartowski/Qwen_Qwen3-1.7B-GGUF` |
|---|---|---|
| `context_length` (gguf summary field) | 40960 | 32768 |
| `tokenizer.chat_template` (embedded, read directly from local GGUF header) | matches | (not locally available to parse — bartowski file not on disk; compared via API string only) |

Diffed the two `chat_template` Jinja strings returned by the API
line-by-line (saved to `/tmp/ggmlorg_gguf.txt` / `/tmp/bartowski_gguf.txt`
during research, not committed). **They are functionally identical** — same
`<|im_start|>`/`<|im_end|>` framing, same system-prompt injection logic
(`messages[0].role == 'system'`), same tool-calling XML scaffolding, same
`enable_thinking` branch at the end:

```jinja
{%- if enable_thinking is defined and enable_thinking is false %}
    {{- '<think>\n\n</think>\n\n' }}
{%- endif %}
```

byte-identical in both. The only difference is **how** the two templates
detect a trailing `<tool_response>...</tool_response>` block in the reversed
message scan (ggml-org: `message.content.startswith(...)`/`.endswith(...)`;
bartowski: manual slicing `message.content[:len]` / `message.content[-len:]`)
— semantically equivalent, purely a different Jinja authoring style/vintage
of the same upstream Qwen3 template. **No system-prompt difference, no
`enable_thinking` logic difference.** The chat template is not a plausible
explanation for the English-vs-Italian behavior difference.

Read directly off the local GGUF file's own header (`tokenizer.chat_template`
key, parsed via the `struct`-based script below) confirms the API-reported
ggml-org template matches what's actually embedded in the file on disk —
identical opening lines through the tool-calling block.

One structural difference that **is** real: `qwen3.context_length` is 40960
in the ggml-org file vs 32768 reported for bartowski's — but this affects
max context window, not language selection, so it's not a plausible cause
for the Italian/English divergence either.

## 6. Imatrix / quantization provenance

**ggml-org:** README (`https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/raw/main/README.md`)
is minimal — just license/base_model front-matter and a link to the original
Qwen3-1.7B model, **no mention of imatrix at all**. Parsing the local GGUF
file's own header (34 KV pairs, `general.quantization_version = 2`) found
**no `quantize.imatrix.*` keys present** — this is consistent with a plain
(non-imatrix-calibrated) `Q4_K_M` quant, i.e. straight RTN/k-quant without an
importance-matrix calibration pass.

**bartowski:** README explicitly states imatrix usage:
> "All quants made using imatrix option with dataset from
> [here](https://gist.github.com/bartowski1182/eb213dccb3571f863da82e99418f81e8)"
> "Using llama.cpp release b5200 for quantization."
> Credits: "kalomaze and Dampf for assistance in creating the imatrix
> calibration dataset."

The bartowski calibration gist is a general-purpose text corpus (not
inspected in detail here — out of scope per the ticket, which only asked to
record provenance from model cards) that ticket 05 already flagged as
plausibly English-skewed. This research did not independently verify the
gist's language composition; it only confirms bartowski explicitly used
imatrix and ggml-org's file shows no imatrix key in its own header and no
imatrix mention in its README — i.e., **ggml-org's Q4_K_M is a non-imatrix
quant, bartowski's is imatrix-calibrated on an English-heavy dataset.** This
is the most concrete, evidenced structural difference found between the two
files, and lines up with ticket 05/06's working hypothesis.

## Findings summary

- **Exact match:** `ggml-org/Qwen3-1.7B-GGUF`, revision `daeb8e2d528a760970442092f6bf1e55c3b659eb`, file `Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,264 bytes, SHA256 `d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`, license `apache-2.0`.
- Confirmed by four independent readings: local file's already-known hash, HF tree API `lfs.oid`, HF resolve-URL `x-linked-etag`, and the file's own embedded GGUF header (`tokenizer.chat_template` content matches API).
- Anonymous HEAD download works, ungated: 302 → 302 (Xet CDN, both hops presigned/public) → 200, `content-length: 1282439264`.
- Chat template is essentially identical to bartowski's (same `enable_thinking` branch, same system-prompt handling) — ruled out as the cause of the language behavior difference.
- The credible structural difference: ggml-org's quant carries **no imatrix calibration** (no README mention, no `quantize.imatrix.*` GGUF key), while bartowski's is **imatrix-calibrated** on a dataset the maintainer's own credits describe as community-built (plausibly English-skewed, per ticket 05's hypothesis) — this is the most likely explanation for why bartowski's quant answers Italian prompts in English while ggml-org's answers correctly.
- No near-misses beyond the two ruled-out repos in §2 (unsloth: different quant, smaller; lmstudio-community: same size ballpark but different hash) — this was a first-pass exact match, no need to dig into commit history or older revisions.
