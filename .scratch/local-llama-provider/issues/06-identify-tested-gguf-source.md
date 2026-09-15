# 06 — Identify the source of the Italian-answering Qwen3 GGUF

**Type:** research
**Blocked by:** none
**Status:** resolved

## Question

Ticket 05 found that the pinned bartowski `Qwen_Qwen3-1.7B-Q4_K_M.gguf`
(`72c5c3cb…`) answers the spec §10 prompt in English. The file already on the dev
machine answers in Italian: `C:\llama\models\Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,264
bytes, SHA256 `d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`,
dated 2026-09-08.

Which Hugging Face repo and revision publishes a file with that exact SHA256?
Candidates are `unsloth`, `lmstudio-community`, `Qwen`, `ggml-org` and
second-hand mirrors. Check `lfs.oid` in the tree API, as ticket 02 did. For the
match, record repo, revision, filename, size and license. Also record whether
anonymous download works and how its embedded chat template differs from
bartowski's: system prompt, `enable_thinking` branch, or quant/imatrix
(bartowski uses an imatrix calibrated mostly on English, which is a plausible
cause).

## Answer

Findings: [research/06-identify-tested-gguf-source.md](../research/06-identify-tested-gguf-source.md).

- **Match (high confidence):** `ggml-org/Qwen3-1.7B-GGUF` @
  `daeb8e2d528a760970442092f6bf1e55c3b659eb`, file `Qwen3-1.7B-Q4_K_M.gguf`,
  1,282,439,264 bytes, SHA256 `d2387ca2…c7b5` (matches `lfs.oid`), license
  `apache-2.0`.
- **Ruled out:** `unsloth` (same name, different size/quant),
  `lmstudio-community` (similar size, hash `e0801cbd…`), `Qwen/Qwen3-1.7B-GGUF`
  (no `Q4_K_M`).
- **Download:** anonymous, not gated. `resolve/<rev>` gives 302 → 302 (public
  Xet CDN) → 200, with `Content-Length: 1282439264`. One more redirect hop than
  bartowski.
- **Chat template:** same behaviour as bartowski's. The system prompt matches,
  and the `enable_thinking` branch is byte-identical. Only the tool-response
  slicing code is written differently. **The template does not cause the English
  output.** Unrelated difference: `context_length` is 40960 here vs 32768 on
  bartowski.
- **Imatrix (moderate confidence, best lead):** ggml-org's file has no imatrix
  (no `quantize.imatrix.*` keys, nothing in the README). bartowski uses an
  imatrix built on the kalomaze/Dampf community calibration set. That set is
  plausibly English-heavy, but its language mix was not checked.
