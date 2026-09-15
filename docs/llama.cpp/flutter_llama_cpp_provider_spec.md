# Draft Engineering Spec — Local llama.cpp Provider for Flutter

> Status: brainstorming draft for a coding agent.
> Goal: integrate a local llama.cpp-backed SLM into the existing Flutter application without coupling the frontend to any specific AI source.

## 1. Objective

Add a new **local Llama provider** alongside the currently supported Codex CLI, Claude CLI, and OpenCode CLI integrations.

The application should expose a **single stable domain interface** to the Flutter frontend. Each backend/provider may have different execution models, response formats, processes, and parsers, but those differences must remain behind the abstraction layer.

The local provider will use:

- `llama.cpp`
- `llama-server`
- Qwen3 1.7B GGUF
- initial quantization: `Q4_K_M`
- local OpenAI-compatible HTTP API

Primary local tasks:

1. generate a very short time-tracking note;
2. optionally generate a detailed checklist.

These are intentionally separate operations.

---

## 2. Reference Local Model

Initial model:

`Qwen3-1.7B-Q4_K_M.gguf`

Approximate model file size:

~1.28 GB

Current tested runtime configuration:

```text
--reasoning off
--parallel 1
--ctx-size 8192
--sleep-idle-seconds 60
```

Current test server endpoint:

```text
http://127.0.0.1:18080
```

The port must not be hard-coded in domain/business logic. It should be configuration-driven and ideally selectable dynamically if the preferred port is unavailable.

---

## 3. llama-server Lifecycle

The Flutter application must manage `llama-server` automatically.

### Startup

When the local Llama provider is required:

1. resolve the llama.cpp executable path;
2. resolve the GGUF model path;
3. verify that required files exist;
4. find/validate the configured local port;
5. start `llama-server` as a child process;
6. bind only to localhost;
7. wait until `/health` reports ready;
8. only then mark the provider as available.

Reference command:

```text
llama-server
  -m <MODEL_PATH>
  --host 127.0.0.1
  --port <PORT>
  --reasoning off
  --parallel 1
  --ctx-size 8192
  --sleep-idle-seconds 60
```

### Shutdown

When the application exits:

- gracefully terminate the child `llama-server` process;
- if graceful termination fails, kill only the process owned by this application;
- never kill unrelated llama.cpp processes.

Also handle:

- application crashes where possible;
- hot restart/development lifecycle;
- duplicate startup attempts;
- stale process/PID state.

### Process supervision

The app should detect:

- server process exited unexpectedly;
- health endpoint stopped responding;
- model failed to load;
- port already in use;
- executable missing;
- model missing/corrupt.

The provider should expose a normalized status to the frontend rather than raw process errors.

Suggested states:

```text
unavailable
starting
ready
sleeping
busy
error
stopping
```

Exact state names can be adjusted during implementation.

---

## 4. Resource Strategy

The previous default model context (`40960`) consumed too much RAM for the target machine.

Observed during testing:

- `n_ctx = 40960` -> roughly 42% total RAM usage on a 24 GB machine;
- `n_ctx = 8192` -> roughly 20% total RAM usage.

Therefore the initial production candidate is:

```text
--ctx-size 8192
```

`--sleep-idle-seconds 60` should allow llama.cpp to release most model memory after inactivity.

Important UX implication:

- warm request: faster;
- first request after sleep: cold-start penalty;
- do not treat the cold-start delay as a request failure.

The sleep timeout should be configurable.

---

## 5. Provider Architecture

Do not let the frontend know whether output came from:

- Codex CLI;
- Claude CLI;
- OpenCode CLI;
- llama.cpp;
- a future provider.

Introduce/refactor toward a provider abstraction.

Conceptually:

```text
Frontend
   |
Application / AI Service
   |
AI Provider Interface
   |
   +-- ClaudeCliProvider
   +-- CodexCliProvider
   +-- OpenCodeCliProvider
   +-- LlamaCppProvider
   +-- future providers
```

A provider is responsible for transport/execution only.

Provider-specific parsing must not leak into UI code.

---

## 6. Stable Domain Contract

The frontend should always consume normalized domain objects.

Example conceptual API:

```dart
abstract interface class AiProvider {
  Future<SummaryResult> summarize(SummaryRequest request);
  Future<ChecklistResult> createChecklist(ChecklistRequest request);
}
```

Possible domain objects:

```dart
class SummaryRequest {
  final String text;
}

class SummaryResult {
  final String summary;
}

class ChecklistRequest {
  final String text;
}

class ChecklistResult {
  final List<String> items;
}
```

This is conceptual only; adapt names to the existing codebase.

The key rule is:

> Provider response formats must be converted into stable application/domain models before reaching the frontend.

---

## 7. Parser / Mapper Layer

Create a parser/mapper layer between raw provider output and domain models.

Desired philosophy: similar to an ORM/model layer such as Laravel Eloquent:

- transport details stay outside the domain model;
- raw JSON / CLI stdout / provider-specific structures are parsed centrally;
- the frontend receives predictable typed objects;
- adding a new provider should normally require a provider adapter + parser, not UI changes.

Conceptually:

```text
Raw Provider Response
        |
Provider Parser / Mapper
        |
Normalized Domain Result
        |
Frontend
```

Examples:

```text
LlamaChatCompletionParser
ClaudeCliResponseParser
CodexCliResponseParser
OpenCodeCliResponseParser
```

Avoid one giant parser with provider-specific `if/else` logic if separate parsers make the code clearer.

---

## 8. Local HTTP Client

`llama-server` exposes an OpenAI-compatible API.

Primary endpoint:

```text
POST /v1/chat/completions
```

Operational endpoints used by the app:

```text
GET /health
GET /props
GET /v1/models
```

The Llama provider should hide all HTTP details from callers.

Bind only to:

```text
127.0.0.1
```

Do not expose the local inference server to the LAN by default.

---

## 9. Structured Output

Use JSON Schema constrained output through `response_format` for local inference.

Do not rely on parsing arbitrary natural-language output when a stable schema is available.

### Summary response

Expected domain shape:

```json
{
  "summary": "..."
}
```

### Checklist response

Expected domain shape:

```json
{
  "checklist": [
    "...",
    "..."
  ]
}
```

Summary and checklist should remain **two independent model operations**.

Do not ask the model to generate both in one call by default: testing showed that Qwen3 1.7B performs more reliably when the tasks are isolated.

---

## 10. Summary Prompt

Current candidate prompt:

```text
Write a very short Italian time-tracking note in telegram style.

Maximum 15 words.
Use terse keywords and short noun/action phrases.
No need for a complete sentence.
Keep only the essential work requested.
Omit greetings, filler, examples, quotes and non-essential details.

Text:
"""
<INPUT>
"""
```

Target style:

```text
aggiungere frase, nascondere prezzo, spazio tra prodotti, controllare nomi su mobile
```

The 15-word limit is a semantic instruction, not a token limit.

The application may optionally validate the final word count and flag/log violations, but avoid aggressive automatic rewriting unless explicitly required.

---

## 11. Checklist Prompt

Current candidate prompt:

```text
Extract the actionable tasks from the following text as a short Italian checklist.

Use telegram style.
Each item should be a terse action phrase, not a complete sentence.
Keep each item as short as possible while preserving the essential action.
One distinct action per item.
Do not invent or infer work not requested.
Skip greetings, context, completed work and non-actionable information.
Keep specific details only when necessary to understand or execute the task.

Text:
"""
<INPUT>
"""
```

Checklist length is not a hard UX constraint.

The checklist is optional from the user's perspective. The application should not ask the model to decide whether a checklist is needed unless a future product requirement introduces that behavior.

---

## 12. Generation Parameters

Initial deterministic configuration:

```json
{
  "temperature": 0,
  "max_tokens": 128,
  "cache_prompt": false
}
```

Notes:

- `temperature = 0` improves repeatability.
- `max_tokens = 128` is a technical safety ceiling, not the 15-word summary constraint.
- too-small `max_tokens` values can truncate valid JSON.
- `cache_prompt = false` was useful for clean benchmarks.

For production, whether prompt caching should remain disabled should be benchmarked separately rather than assumed.

---

## 13. Concurrency

Current decision:

```text
--parallel 1
```

Reasoning:

- checklist generation is optional;
- operations do not need to run concurrently by default;
- single-slot inference gave better single-request performance;
- 8192 context tokens are sufficient for the intended email/ticket use case.

If future product behavior requires concurrent inference, revisit `--parallel 2`.

Do not bake this assumption deeply into the architecture.

---

## 14. Model Packaging / Distribution

This needs explicit investigation during implementation.

The model is ~1.28 GB, therefore bundling it directly into every Flutter build may be undesirable or impossible depending on target platform/store constraints.

The coding agent should evaluate:

### Option A — bundled model

Pros:
- works immediately offline;
- deterministic installation.

Cons:
- very large application package;
- platform packaging/update implications.

### Option B — first-run download

Pros:
- smaller application installer;
- model can be updated independently.

Cons:
- requires download progress, integrity validation, retries, storage management.

### Option C — external/configured model path

Useful for development and advanced users.

Recommended architecture:

- model location must be abstracted;
- provider should receive a resolved model path;
- do not hard-code `C:\llama\models\...`.

If downloading models, verify checksum before use.

---

## 15. llama.cpp Binary Packaging

Investigate per target desktop platform:

```text
Windows
macOS
Linux
```

The app must use the correct llama.cpp build for the target architecture.

Questions for implementation:

- ship llama.cpp binaries with the Flutter desktop build?
- download platform-specific runtime on first use?
- rely on system-installed llama.cpp only in development?
- CPU-only baseline or optional GPU backend builds?
- Windows x64 first, then other targets?

Keep binary discovery/runtime installation behind a dedicated service.

Conceptual component:

```text
LlamaRuntimeManager
```

Responsibilities:

- locate/install runtime;
- detect platform/architecture;
- return `llama-server` executable path;
- expose runtime version;
- validate compatibility.

---

## 16. Configuration

Avoid magic constants throughout the codebase.

Suggested configurable values:

```text
provider
model path
llama-server path
host
port
context size
parallel slots
sleep idle seconds
temperature
max tokens
request timeout
startup timeout
```

Provide sensible defaults.

Initial local defaults:

```text
host = 127.0.0.1
port = 18080
ctxSize = 8192
parallel = 1
sleepIdleSeconds = 60
temperature = 0
maxTokens = 128
reasoning = off
```

---

## 17. Error Normalization

Raw provider errors should map to application errors.

Examples:

```text
ProviderUnavailable
ProviderStarting
ModelMissing
RuntimeMissing
ModelLoadFailed
RequestTimeout
InvalidProviderResponse
ContextLimitExceeded
ProviderProcessExited
PortUnavailable
```

The frontend should receive actionable, provider-neutral errors where possible.

Provider-specific diagnostics should still be preserved in logs.

---

## 18. Timeouts and Cold Start

A sleeping Llama provider may need additional time to reload.

Use separate timeout concepts:

```text
server startup timeout
cold inference timeout
warm inference timeout
```

Do not use an overly aggressive HTTP timeout that makes sleep/wake unusable.

The UI may show a lightweight "loading local model" state when appropriate.

---

## 19. Observability

Capture enough metadata for real-world benchmarking without exposing it to normal UI unless needed.

For llama.cpp responses, useful fields include:

```text
prompt_tokens
completion_tokens
prompt_ms
predicted_ms
prompt_per_second
predicted_per_second
cached_tokens
```

Also consider application-level:

```text
total request latency
cold vs warm request
provider name
model name
success/failure
```

This will allow comparison with Claude/Codex/OpenCode under real workloads.

Avoid storing full user text in logs by default.

---

## 20. Security / Privacy

Local provider:

- bind only to localhost;
- do not expose a public HTTP port;
- do not transmit input text externally;
- do not log full email/ticket content by default.

The architecture should make it clear when a provider is local vs remote/CLI-backed so future privacy policies can make routing decisions.

---

## 21. Testing

At minimum add:

### Unit tests

- parser -> domain mapping;
- malformed provider response;
- empty checklist;
- summary schema validation;
- provider error normalization;
- command-line argument construction.

### Integration tests

- launch llama-server;
- health readiness;
- summary request;
- checklist request;
- shutdown;
- restart after sleep;
- missing model;
- occupied port;
- server crash/recovery.

### Contract tests

Run equivalent requests against all providers and assert that they all return the same domain-level result shape.

---

## 22. Suggested Components

Names are illustrative.

```text
AiProvider
AiProviderRegistry
AiService

LlamaCppProvider
ClaudeCliProvider
CodexCliProvider
OpenCodeCliProvider

ProviderResponseParser<T>
LlamaSummaryParser
LlamaChecklistParser
...

LlamaRuntimeManager
LlamaServerProcessManager
LlamaModelManager
LlamaHttpClient

AiConfiguration
```

Prefer dependency injection so providers and parsers are independently testable.

---

## 23. Migration Strategy

Do not rewrite all provider code at once if avoidable.

Suggested sequence:

1. identify the interface currently consumed by the frontend;
2. define normalized domain request/result models;
3. wrap one existing provider behind the new interface;
4. move its parsing into a parser/mapper;
5. confirm no frontend behavior changes;
6. migrate remaining existing CLI providers;
7. add `LlamaCppProvider`;
8. add runtime/process lifecycle management;
9. add model management;
10. add integration tests.

This reduces the risk of coupling the Llama integration to legacy provider-specific behavior.

---

## 24. Important Decisions Already Made

For the initial implementation:

```text
Model: Qwen3 1.7B Q4_K_M
Runtime: llama.cpp / llama-server
Host: localhost only
Context: 8192
Parallel slots: 1
Reasoning: off
Idle sleep: 60 seconds
Temperature: 0
Max generation tokens: 128
Summary/checklist: separate calls
Checklist: explicitly requested by the user, not automatically inferred
Structured output: JSON Schema
Frontend contract: provider-neutral
```

---

## 25. Open Questions for Brainstorming

The coding agent should inspect the existing codebase before deciding these points:

1. Which Flutter targets are currently supported?
2. Where are Claude/Codex/OpenCode integrations currently located?
3. What objects does the frontend currently expect?
4. Is there already a provider/service abstraction worth extending?
5. Is there already a process-management abstraction for CLI tools?
6. Should llama.cpp be bundled or downloaded?
7. How should model updates/versioning work?
8. Where should the ~1.28 GB model live per OS?
9. Should the app expose model/runtime download progress?
10. Should localhost port allocation be fixed or dynamic?
11. Should production keep `cache_prompt=false`, or enable caching?
12. Should the app keep llama-server alive for the entire app session or start lazily on first local request?
13. What should happen if local inference fails: surface an error or optionally fall back to another configured provider?
14. Is GPU acceleration required later, and how should backend-specific llama.cpp builds be selected?
15. Should runtime/model versions be pinned for reproducibility?
16. How should long texts approaching the 8192-token context be detected before sending?
17. Should token counting be implemented locally before requests?
18. Is one local Llama provider instance shared application-wide?
19. How should application updates clean up obsolete model/runtime files?
20. What telemetry is acceptable without storing private content?

---

## 26. Definition of Done — First Iteration

The first implementation is complete when:

- the app can select Llama as a provider;
- llama.cpp is available in a build-compatible way;
- the Qwen GGUF model is resolved successfully;
- llama-server starts automatically;
- readiness is checked through `/health`;
- summary generation works through the common provider interface;
- checklist generation works through the same abstraction as a separate operation;
- JSON output is parsed into provider-neutral domain objects;
- existing Claude/Codex/OpenCode paths also use the common abstraction;
- the frontend contains no llama.cpp-specific parsing or lifecycle logic;
- llama-server sleeps after configured inactivity;
- llama-server is terminated when the application exits;
- errors are normalized;
- integration tests cover startup, inference, and shutdown.
