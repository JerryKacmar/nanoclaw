# Local patches (maintained fork delta)

This fork (`JerryKacmar/nanoclaw`) carries deliberate deltas from upstream `nanocoai/nanoclaw`.
**Re-apply / re-verify these after any upstream merge or `/update-nanoclaw`.**
Context: `~/stacks/PLAN.md` and `~/stacks/docs/adr/0001-ai-tools-network-segmentation.md`.

## P1 — OneCLI optional (Path B: local-only, contained agents)

- **File:** `src/container-runner.ts` (commit `dad2996`)
- **What:** the OneCLI block — `onecli.ensureAgent()` + `onecli.applyContainerConfig()` + the
  `"refusing to spawn container without credentials"` throw — is wrapped in `if (ONECLI_API_KEY) { … }`
  (with an `else` log). When the key is unset, OneCLI wiring is skipped instead of throwing; when set,
  behaviour is identical to upstream.
- **Why:** this install runs agents on **local Ollama with no cloud credentials**, contained on an
  `--internal` Docker network (`ai-sandbox`) with **no credential proxy**. Upstream `main` throws
  without a working OneCLI gateway. OneCLI's gateway is also an open forward-proxy for non-intercepted
  hosts (+ a hardcoded LLM-host bypass) — an exfiltration channel incompatible with running untrusted /
  red-team agents. So OneCLI is dropped, not self-hosted.
- **Companion config (not in this repo):** `ONECLI_API_KEY` is left **unset**; a no-op container named
  `onecli` runs on `ai-sandbox` solely to satisfy `egress-lockdown.ts`'s presence check;
  `NANOCLAW_EGRESS_LOCKDOWN=true` + `NANOCLAW_EGRESS_NETWORK=ai-sandbox`.
- **Re-apply test:** with `ONECLI_API_KEY` unset, an agent spawns; from inside it (on `ai-sandbox`)
  `curl http://ollama:11434/api/tags` succeeds and `curl https://example.com` fails.

## P2 — Per-group container `env` + `blockedHosts` (route agents to local Ollama)

- **Files:** new migration `src/db/migrations/017-container-config-env.ts` (registered in
  `src/db/migrations/index.ts`); `src/types.ts` (`ContainerConfigRow.env` / `.blocked_hosts`);
  `src/container-config.ts` (`ContainerConfig.env` / `.blockedHosts` + `configFromDb` parse);
  `src/db/container-configs.ts` (`env`/`blocked_hosts` in `JSON_COLUMNS` + `updateContainerConfigJson`
  union); `src/backfill-container-configs.ts` (defaults in the row literal);
  `src/container-runner.ts` (`buildContainerArgs` emits `-e KEY=VAL` per `env` entry and
  `--add-host HOST:0.0.0.0` per `blockedHosts` entry, applied just before egress-lockdown so the
  group config wins).
- **What:** adds two DB-backed, per-agent-group container-config fields — `env` (JSON object) and
  `blocked_hosts` (JSON array). Upstream's DB-backed config (the `container_configs` table) had no way
  to inject arbitrary env or pin hosts unreachable; the `add-ollama-provider` skill predates that table
  and assumed a hand-edited `container.json` (which `materializeContainerJson` now overwrites at spawn).
- **Why:** lets an agent group be routed to the local Ollama with **no provider code** — Ollama speaks
  the Anthropic API natively. Set the group's `env` to
  `{"ANTHROPIC_BASE_URL":"http://ollama:11434","ANTHROPIC_API_KEY":"ollama"}` and
  `blocked_hosts` to `["api.anthropic.com"]` (pinned to 0.0.0.0 so config drift can't reach/bill the
  real API). No `NO_PROXY` needed under Path B (no proxy is injected). The model is set separately in
  `data/v2-sessions/<group-id>/.claude-shared/settings.json` (`"model":"qwen3.6:35b"`).
- **Migration note:** `017` is additive (`ALTER TABLE … ADD COLUMN … DEFAULT`). Runs automatically on
  host boot; existing rows default to `'{}'` / `'[]'`.
- **Re-apply test:** set a group's `env`/`blocked_hosts` (e.g. via
  `UPDATE container_configs …`), spawn, then `docker inspect <ctr>` shows the `ANTHROPIC_*` env and
  `api.anthropic.com:0.0.0.0` in `ExtraHosts`; Ollama (`ollama ps`) shows the model loading.
