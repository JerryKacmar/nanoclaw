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
