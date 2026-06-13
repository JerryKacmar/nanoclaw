#!/usr/bin/env bash
# agent-cancel.sh — STOP in-flight NanoClaw agent work immediately.
#
# Use when you sent bad/wrong instructions and want the agent to stop NOW.
# (A "stop" message in Telegram does NOT interrupt promptly — the agent only
# checks for new input between turns. Killing the container is the real stop.)
#
# Kills any running agent container (work halts instantly) and drops any
# still-queued messages so the aborted instruction does not respawn. The bot
# stays ON — just send a new message to start fresh.
#
#   bash ~/stacks/nanoclaw/agent-cancel.sh
cd "$(dirname "$0")" || exit 1

running=$(docker ps --format '{{.Names}}' | grep '^nanoclaw-v2-' || true)
if [ -n "$running" ]; then
  echo "$running" | xargs docker rm -f >/dev/null
  echo "Stopped agent(s): $running"
else
  echo "No agent currently running."
fi

# Drop any messages still queued (not yet picked up) so they don't respawn.
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh" >/dev/null 2>&1; nvm use 22 >/dev/null 2>&1
for db in data/v2-sessions/*/*/inbound.db; do
  [ -f "$db" ] || continue
  pnpm exec tsx scripts/q.ts "$db" \
    "UPDATE messages_in SET status='completed' WHERE status='pending';" >/dev/null 2>&1 || true
done

echo "Cancelled. The bot is still on — send a new message to start fresh."
