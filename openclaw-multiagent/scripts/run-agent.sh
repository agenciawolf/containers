#!/bin/bash
set -euo pipefail
AGENT="${1:-planner}"
PORT="${2:-18790}"
export HOME="/workspace/agents/${AGENT}"
export OPENCLAW_HOME="${HOME}/.openclaw"
export PATH="/workspace/.pnpm:/workspace/.nodejs/bin:${PATH}"
cd "${HOME}"
exec openclaw gateway --port "${PORT}" --config "${OPENCLAW_HOME}/config.yaml" 2>&1 | tee -a "/workspace/logs/${AGENT}.log"
