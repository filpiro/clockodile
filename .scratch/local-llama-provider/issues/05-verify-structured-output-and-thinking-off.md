# 05 — Verify structured output and thinking-off against a real server

**Type:** task (HITL — needs the Windows machine)
**Blocked by:** none
**Status:** resolved

## Question

Two load-bearing assumptions have no local evidence behind them:

- **Spec §9's JSON-Schema constrained output.** Ticket 01 confirms upstream
  enforces `response_format` via GBNF, but
  `docs/llama.cpp/llama_server_postman_collection.json` never sends
  `response_format` and saves no response bodies. Nobody has seen Qwen3 1.7B
  answer under that constraint.
- **Thinking-off.** Ticket 01 confirms `--reasoning off` exists as a flag;
  ticket 02 says this GGUF's own Jinja template branches on
  `enable_thinking`. Whether the flag alone actually suppresses the
  `<think>` block *for this file*, or whether
  `--chat-template-kwargs '{"enable_thinking": false}'` is required, is
  unverified — and it decides whether thinking-off lives in `AiConfig`'s argv or
  in the request builder.

The user already runs this server locally, so this is a short manual pass, not an
install.

**Checklist** — with `llama-server` started on the tested config plus
`--reasoning off`:

1. Send a summary request **with** `response_format` `{"type":"json_schema",
   "json_schema":{...}}` for `{"summary": string}`, using spec §10's prompt over
   a real pasted client email. Save the full response body.
2. Repeat **without** `response_format`. Save that body too. Does the
   unconstrained answer already parse as JSON, or is the constraint doing real
   work?
3. In both bodies, check for a `<think>` block or a `reasoning_content` field.
   If either appears, restart with `--chat-template-kwargs
   '{"enable_thinking": false}'` and repeat step 1.
4. Note whether `max_tokens: 128` truncates the JSON when the model is verbose —
   spec §12 warns that a too-small ceiling produces invalid JSON, and a truncated
   `{"summary": "…` is a parse failure the app must survive.
5. Record observed latency for a cold (post-sleep) and a warm request, to sanity
   check the 90 s / 30 s timeouts from decision 21.

Save the request/response pairs into
`docs/llama.cpp/` — either as saved examples in the Postman collection or as a
sibling `.http`/`.json` file — so the parser unit tests in ticket 04 have real
fixtures instead of invented ones.

## Answer

Run 2026-09-13 on the Windows box: winget `llama-server` **build 10853**
(`9dcf84e5a`, 47 builds behind the `b10900` pin — close enough for these flags),
spec §3 argv, spec §10 prompt over one realistic sample client email (not a real
one), `temperature 0`, `max_tokens 128`, `cache_prompt false`. Fixtures and the
rerun script live in `docs/llama.cpp/fixtures/` (`llama-verify.ps1`).

Two model files were tested:

- **pinned** — bartowski @ `dcb1915`, 1,282,439,584 bytes, SHA256 `72c5c3cb…`
  (matches ticket 02).
- **localfile** — the one already on disk at `C:\llama\models\Qwen3-1.7B-Q4_K_M.gguf`,
  1,282,439,264 bytes, SHA256 `d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`.
  Source unknown. This is almost certainly the file the spec was written against.

1. **`response_format` json_schema works and does real work.** Constrained
   output parses as `{"summary": string}` on both files with `finish_reason: stop`,
   in 37–43 tokens. Unconstrained output never parses: it comes back as markdown-ish
   lines (`prodotti: …` / `+prodotti+spedizione+…`). JSON mode is the parser's
   contract. There is no fallback to free text.
2. **Thinking-off: `--reasoning off` alone is enough — for both files.** No
   `<think>` in `content`, no `reasoning_content` field. The `--chat-template-kwargs`
   rerun was not needed. **It lives in `AiConfig`'s argv, not the request
   builder.** Control run without the flag: thinking eats the full 128 tokens, and
   the result is `content: ""` plus `reasoning_content` and `finish_reason: length`,
   on every request. The parser must treat empty content as a failure.
3. **Truncation shape** (`max_tokens: 8`): `finish_reason: "length"`, content
   `{"summary` / `{"summary":`, invalid JSON. 128 never truncated here (peak 54
   tokens). Rule for the parser: `finish_reason != "stop"` is a failure, checked
   before decoding.
4. **Latency** (CPU, pinned): startup to `/health` 200 in 4.8–8 s; warm request
   5.0–5.3 s (prompt ~1.2 s for 252 tokens, generation ~3.4 s); **cold after sleep
   11.2–11.5 s** (`/props.is_sleeping` was `true`). The 90 s / 30 s timeouts from
   decision 21 have ~3x headroom even cold. Without the flag, requests take 13–18 s
   and still fail.
5. **New problem — the pinned file answers in English.** Same prompt, same email:
   pinned gives `"add free shipping below 50€, hide price for B2B, add space in
   category grid, fix product name truncation on mobile"`. The local file gives
   `"aggiungere frase prodotto, nascondere prezzo B2B, spazio categoria, tagli nome
   mobile"`, which matches the spec §10 target. This is one email at temperature 0,
   so n=1, but the output is deterministic. This reopens the pin from ticket 03 →
   tickets 06 and 07.

Fixtures kept: `summary.{constrained,unconstrained,truncated}.request.json`;
responses `*.pinned-reasoning-off.*` (including warm and cold),
`summary.constrained.localfile-reasoning-off.response.json`,
`summary.unconstrained.localfile-reasoning-off.response.json`,
`summary.constrained.localfile-no-flag.response.json` (the empty-content case).
