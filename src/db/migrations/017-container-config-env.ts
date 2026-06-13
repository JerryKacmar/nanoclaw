import type Database from 'better-sqlite3';
import type { Migration } from './index.js';

// Path-B fork delta (P2 — Ollama provider). Adds per-agent-group container env
// overrides + blocked-hosts to the DB-backed container config so an agent can be
// pointed at the local Ollama (`ANTHROPIC_BASE_URL=http://ollama:11434`) with
// `api.anthropic.com` pinned unreachable. See nanoclaw/PATCHES.md + ~/stacks/PLAN.md.
export const migration017: Migration = {
  version: 17,
  name: 'container-config-env',
  up(db: Database.Database) {
    db.prepare("ALTER TABLE container_configs ADD COLUMN env TEXT NOT NULL DEFAULT '{}'").run();
    db.prepare("ALTER TABLE container_configs ADD COLUMN blocked_hosts TEXT NOT NULL DEFAULT '[]'").run();
  },
};
