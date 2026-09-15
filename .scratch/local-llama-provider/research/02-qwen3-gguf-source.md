# 02 — Qwen3-1.7B-Q4_K_M GGUF: canonical source and integrity

Research findings for `.scratch/local-llama-provider/issues/02-qwen3-gguf-source.md`.
All facts below were pulled live on 2026-09-11 from the Hugging Face API
(`https://huggingface.co/api/models/<repo>` and `.../tree/main`) and `curl -I`
against `resolve` URLs — no mirrors, no aggregator sites. Raw JSON is not
attached; every number here was read directly off the API responses quoted
inline.

## 1. Canonical repo

Three repos were checked. Only two actually publish a `Q4_K_M` file:

| Repo | Q4_K_M present? | Exact filename | Size (bytes) |
|---|---|---|---|
| `Qwen/Qwen3-1.7B-GGUF` (official) | **No** | — | — |
| `unsloth/Qwen3-1.7B-GGUF` | Yes | `Qwen3-1.7B-Q4_K_M.gguf` | 1,107,409,472 |
| `bartowski/Qwen_Qwen3-1.7B-GGUF` | Yes | `Qwen_Qwen3-1.7B-Q4_K_M.gguf` | 1,282,439,584 |

Source: `GET https://huggingface.co/api/models/Qwen/Qwen3-1.7B-GGUF/tree/main`
returns only 5 entries — `.gitattributes`, `LICENSE`, `README.md`, `params`,
and a single weight file `Qwen3-1.7B-Q8_0.gguf` (1,834,426,016 bytes). The
official Qwen repo does not ship a Q4_K_M quant at all, so it is ruled out
for this ticket.

`GET https://huggingface.co/api/models/unsloth/Qwen3-1.7B-GGUF/tree/main` and
`GET https://huggingface.co/api/models/bartowski/Qwen_Qwen3-1.7B-GGUF/tree/main`
each list a full ladder of GGUF quants including a `Q4_K_M`, but under
**different filenames** and **different byte sizes** — they are not the same
underlying quantization (different imatrix/calibration data, different
llama.cpp version at quantization time), so the two are not interchangeable.

**Recommendation:** the ticket's own "~1.28 GB" hint matches only one of the
two candidates exactly — `bartowski/Qwen_Qwen3-1.7B-GGUF`, file
`Qwen_Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,584 bytes. Unsloth's `Q4_K_M` is
1,107,409,472 bytes (~1.03 GB), which does not match. Pin
**`bartowski/Qwen_Qwen3-1.7B-GGUF`** and the filename
**`Qwen_Qwen3-1.7B-Q4_K_M.gguf`** (note the `Qwen_` prefix — easy to drop by
mistake when porting the string from the unsloth naming convention).

Repo commit (`sha`) at fetch time, from
`GET https://huggingface.co/api/models/bartowski/Qwen_Qwen3-1.7B-GGUF`:
`dcb19155b962dbb6389f4691a982043a8e651022` (`lastModified`:
2025-04-28T17:18:17Z). Pin this commit hash as the revision, not `main`.

## 2. Direct download URL

Pattern: `https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-GGUF/resolve/<rev>/Qwen_Qwen3-1.7B-Q4_K_M.gguf`

Verified both forms work identically:
- Moving-target: `.../resolve/main/Qwen_Qwen3-1.7B-Q4_K_M.gguf`
- Pinned: `.../resolve/dcb19155b962dbb6389f4691a982043a8e651022/Qwen_Qwen3-1.7B-Q4_K_M.gguf`

`curl -I` against either URL, unauthenticated, returns:

```
HTTP/2 302
location: https://us.aws.cdn.hf.co/xet-bridge-us/680fb1c6c824b5a0d1c5d9b6/e864889bee68f907ecb7cec2a713a4fb12280600c4a291e23ae5362d92ef4bfd?...&user_id=public&X-Xet-Cas-Uid=public&Expires=...&Policy=...&Signature=...
x-linked-size: 1282439584
x-linked-etag: "72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb"
```

Following the redirect (`curl -I` on the `location` URL) returns the actual
CDN response:

```
HTTP/2 200
content-type: application/octet-stream
accept-ranges: bytes
content-length: 1282439584
etag: "e864889bee68f907ecb7cec2a713a4fb12280600c4a291e23ae5362d92ef4bfd"
x-hf-cdn-pop: aws-eu-west-3
```

Findings:
- **No `Authorization` header or terms acceptance required.** The repo's
  `gated` field is `false` in the API model-info response, and the
  unauthenticated `curl -I` above succeeds with a normal 302/200 — fully
  anonymous.
- **Redirect chain:** one 302 hop, `huggingface.co` → HF's Xet-backed CDN
  bridge (`us.aws.cdn.hf.co/xet-bridge-us/...`, served from the
  `aws-eu-west-3` POP in this test). This is HF's newer Xet storage backend,
  not the older `cdn-lfs.huggingface.co` S3 path — the LFS `oid` sha256
  differs in principle from the Xet content hash, see Q4.
- **`Content-Length` is honoured** at both hops: the redirect response
  carries `x-linked-size: 1282439584` and the final CDN response carries
  `content-length: 1282439584` — a progress bar can rely on either. The
  final response also sends `accept-ranges: bytes`, so range requests
  (resumable/parallel download) work too.

## 3. Exact size

**1,282,439,584 bytes** exactly (not ~1.28 GB rounded). This is
`1282439584`, confirmed identically in three independent places for the same
file:
1. `size` field of the tree-API sibling entry
   (`GET .../tree/main` → `{"path": "Qwen_Qwen3-1.7B-Q4_K_M.gguf", "size": 1282439584, ...}`)
2. The nested `lfs.size` field on that same entry (`1282439584`)
3. The `x-linked-size` response header and the final CDN `content-length`
   header on the `resolve` redirect (both `1282439584`)

In GiB that is ≈1.1945 GiB, or ≈1.282 GB (decimal) — so "~1.28 GB" in the
ticket refers to the decimal-GB figure, not GiB. Use the raw byte count
above for the Italian dialog and the disk-space precheck.

## 4. Integrity — pinned SHA256

**Source of the pinned SHA256:** the Hugging Face tree API's LFS pointer
`oid` field, read from
`GET https://huggingface.co/api/models/bartowski/Qwen_Qwen3-1.7B-GGUF/tree/main`,
on the entry for `Qwen_Qwen3-1.7B-Q4_K_M.gguf`:

```json
{
  "path": "Qwen_Qwen3-1.7B-Q4_K_M.gguf",
  "size": 1282439584,
  "lfs": {
    "oid": "72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb",
    "size": 1282439584,
    "pointerSize": 135
  },
  "xetHash": "e864889bee68f907ecb7cec2a713a4fb12280600c4a291e23ae5362d92ef4bfd"
}
```

The `lfs.oid` value is a 64-character hex string — the correct length for a
SHA256 digest (confirmed by counting: `len(oid) == 64`). This is not just an
assumption from the field name: it is independently corroborated by the
**`X-Linked-ETag`** response header on the `resolve` redirect (Q2 above),
which returns exactly the same 64-hex value,
`"72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb"`, quoted
as an ETag. HF's own LFS docs describe `X-Linked-ETag` as the SHA256 of the
underlying LFS object, so the header and the API field agree and cross-check
each other for this exact file.

Note the **`xetHash`** field (`e864889bee68f907ecb7cec2a713a4fb12280600c4a291e23ae5362d92ef4bfd`)
is a *different* hash — HF's newer Xet content-addressed storage hash, which
also happens to be the value used in the final CDN `etag` header and in the
redirect URL path. **Do not confuse the two**: for a standard SHA256
integrity check against the downloaded bytes, use `lfs.oid` /
`X-Linked-ETag` (`72c5c3cb...`), not `xetHash` (`e864889b...`).

**Pinned values to hard-code:**
- SHA256: `72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb`
- Size: `1282439584` bytes
- How to re-derive for a future revision: `GET
  https://huggingface.co/api/models/bartowski/Qwen_Qwen3-1.7B-GGUF/tree/<revision>`
  and read `lfs.oid` off the matching filename entry, or `curl -I` the
  `resolve/<revision>/<file>` URL and read `x-linked-etag`.

## 5. Licence

`bartowski/Qwen_Qwen3-1.7B-GGUF`'s own repo card does **not** declare an
explicit `license:` tag — its cardData contains only `base_model` and
`base_model_relation: quantized` (confirmed: `cardData.license` is `null`
in the API model-info response, and the repo's `README.md` front-matter has
no `license:` line). The repo is a pure llama.cpp quantization of
`Qwen/Qwen3-1.7B` with no restated licence.

The underlying base model, `Qwen/Qwen3-1.7B`, is **Apache-2.0**
(`cardData.license: "apache-2.0"`, with `LICENSE` file present in that repo
and also re-published verbatim inside `Qwen/Qwen3-1.7B-GGUF`). Apache-2.0
is a permissive licence: redistributing the quantized weights inside a
desktop app is allowed, and the only real obligation is preserving the
licence text / attribution notice, not a runtime prompt. For comparison,
`unsloth/Qwen3-1.7B-GGUF` does explicitly restate `license: apache-2.0` with
`license_link` pointing at `Qwen/Qwen3-1.7B/LICENSE`.

**Recommendation for the Aiuto page:** one line crediting "Qwen3-1.7B model
weights, Apache License 2.0, Qwen Team; GGUF quantization by bartowski" is
good practice (bartowski's own README convention is to credit the
llama.cpp version used and the original model), but is not a strict legal
requirement beyond keeping the Apache-2.0 notice — could not find an
additional licence file specific to the GGUF quantization itself in the
bartowski repo, so this is inherited, not independently confirmed for the
quantization step.

## 6. Chat template and thinking mode

**The GGUF embeds its own chat template.** The HF API's model-info endpoint
exposes it directly under the `gguf.chat_template` key (parsed by HF from
the GGUF's own metadata, identical across all quant files in the repo since
tokenizer/template metadata doesn't vary by quantization level). Both
`bartowski/Qwen_Qwen3-1.7B-GGUF` and `unsloth/Qwen3-1.7B-GGUF` carry the
same Qwen3 Jinja template, which ends with:

```jinja
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
    {%- if enable_thinking is defined and enable_thinking is false %}
        {{- '<think>\n\n</think>\n\n' }}
    {%- endif %}
{%- endif %}
```

So `llama-server` does **not** need an externally supplied template — the
GGUF's built-in one already knows how to suppress thinking, gated on an
`enable_thinking` template kwarg. `llama-server` must be run with `--jinja`
(the default; the server README confirms `--jinja, --no-jinja` is
"(default: enabled)") so this embedded template is actually used.

**How to disable thinking, per llama.cpp's own server docs**
(`https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md`,
fetched live from `raw.githubusercontent.com`):

- Directly matching the template's `enable_thinking` kwarg — the
  documented, Qwen3-specific example in the README itself:
  > `chat_template_kwargs`: Allows sending additional parameters to the
  > json templating system. For example: `{"enable_thinking": false}`

  This can be set server-wide at startup via the CLI flag
  `--chat-template-kwargs '{"enable_thinking": false}'`
  (`LLAMA_ARG_CHAT_TEMPLATE_KWARGS` env var), or per-request via a
  `chat_template_kwargs` field in the `/v1/chat/completions` body.

- A more generic, template-agnostic flag also exists:
  `-rea, --reasoning [on|off|auto]` ("Use reasoning/thinking in the chat",
  default `auto` = detect from template; env `LLAMA_ARG_REASONING`), and
  `--reasoning-budget N` ("token budget for thinking: ... 0 for immediate
  end", env `LLAMA_ARG_THINK_BUDGET`) — `--reasoning-budget 0` forces the
  model to close the think block immediately regardless of the template
  kwarg.

- **Prompt convention (`/no_think`)** is documented on the base model card,
  `https://huggingface.co/Qwen/Qwen3-1.7B` (raw README), as a *soft* switch
  the user can append to their own message — but the same README explicitly
  warns it is overridden by the hard switch:
  > "When `enable_thinking=False`, the soft switches are not valid.
  > Regardless of any `/think` or `/no_think` tags input by the user, the
  > model will not generate think content..."

**Recommendation:** use `--chat-template-kwargs '{"enable_thinking": false}'`
(or the per-request `chat_template_kwargs` body field) as the primary,
template-native mechanism — it's the exact kwarg the embedded GGUF template
already checks for, and it's documented by name in llama.cpp's own server
README for this exact purpose. Treat `--reasoning off` /
`--reasoning-budget 0` as a defense-in-depth belt-and-suspenders option
(ticket 01's `--reasoning` flag), not a replacement. Do not rely on the
`/no_think` prompt suffix alone — it is a soft, user-facing convention, not
a hard switch, and Qwen's own docs say the hard switch overrides it anyway.
