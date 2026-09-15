# 07 — Re-pin the model (or harden the prompt) for Italian output

**Type:** grilling
**Blocked by:** 06
**Status:** resolved

## Question

The pinned GGUF from ticket 03 produces English summaries (ticket 05, finding 5).
Which of these fixes it?

- **Re-pin** to the file ticket 06 identified: `ggml-org/Qwen3-1.7B-GGUF` @
  `daeb8e2`, which has no imatrix, the same template and apache-2.0. This replaces the URL, size and
  SHA256 in `AiConfig` and reopens the parts of 02/03 that depend on bartowski.
- **Keep bartowski and harden spec §10's prompt.** For example, write the
  instruction itself in Italian, add "Rispondi in italiano", or make the JSON
  Schema `description` Italian. Verify with a rerun of
  `docs/llama.cpp/fixtures/llama-verify.ps1`.
- **Both.**

Rerun against more than one email before locking the answer; 05 was n=1.

## Answer

**Both.** Re-pin to ggml-org and replace spec §10's prompt with a short Italian
one. Grilled 2026-09-15.

Evidence was run on the Windows box with winget `llama-server`, `--reasoning off`,
constrained JSON and temperature 0, over 5 realistic Italian client emails
(`docs/llama.cpp/fixtures/italian/email{1..5}.txt`). Script:
`docs/llama.cpp/fixtures/italian/llama-italian.ps1`. Raw output:
`results.tsv` (2 models × en/it) and `results-ggml-org.tsv` (ggml-org × en/it/it2).

| model | `en` (spec §10) | `it` | `it2` (adds "niente articoli, verbo + oggetto") |
|---|---|---|---|
| bartowski @ `dcb1915` | English 3/5, mixed 1/5 | Italian 5/5, wordier (email5: 17 words) | not run |
| ggml-org @ `daeb8e2` | English 3/5 | Italian 5/5, shortest | Italian 5/5, longer than `it` |

Findings:

- **The prompt language decides the output language.** The model doesn't.
  ggml-org also answers in English on the English prompt. Ticket 05 only saw
  Italian because n=1.
- **Pin: ggml-org.** It is shorter and closer to telegram style, it is the file
  the user already runs, and HF `main` == `daeb8e2` today. The size and `lfs.oid`
  were rechecked against the tree API.

Decisions:

1. **Pin** `ggml-org/Qwen3-1.7B-GGUF` at commit
   `daeb8e2d528a760970442092f6bf1e55c3b659eb`, never `main`, because `main` can
   move and break the checksum. File `Qwen3-1.7B-Q4_K_M.gguf`, 1,282,439,264
   bytes, SHA256 `d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5`,
   apache-2.0. This replaces the bartowski constants from 02/03 (URL, filename,
   size, SHA256). Everything else in 03 stands, including keeping the upstream
   filename.
2. **Prompt** = the `it` variant, verbatim:

   ```text
   Scrivi in italiano una nota di time-tracking brevissima, in stile telegrafico.

   Massimo 15 parole.
   Usa parole chiave e brevi frasi nome/azione.
   Non serve una frase completa.
   Tieni solo il lavoro essenziale richiesto.
   Ometti saluti, riempitivi, esempi, citazioni e dettagli non essenziali.

   Testo:
   """
   <INPUT>
   """
   ```

   No untested additions: no "Rispondi solo in italiano", no Schema
   `description`. The user's own tests agree that long prompts full of format
   rules make output worse. **Keep the prompt short and plain.** `it2` is the
   proof: more rules gave longer notes.
3. **15 words is only guidance inside the prompt.** The app does not count or
   validate words. The Nota should be as short as possible.
4. **Infinitive or imperative verbs both pass.** The prompt does not enforce one.
5. **No language detection in the parser.** Notes legitimately carry English
   terms (SMTP, export CSV, out of memory, B2B).
6. **Input fact:** client emails are always Italian, with common English tech
   terms. English emails are not a case to design for.
