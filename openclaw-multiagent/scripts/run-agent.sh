#!/bin/bash
set -euo pipefail
AGENT="${1:-planner}"
PORT="${2:-18790}"
# HOME padrão Linux (/home/<user>) - OpenClaw espera essa estrutura
export HOME="/home/${AGENT}"
# Dados persistentes em /workspace via symlink
export OPENCLAW_HOME="${HOME}/.openclaw"
export PATH="/opt/pnpm:/opt/nodejs/bin:${PATH}"
cd "${HOME}"
exec openclaw gateway --port "${PORT}" --config "${OPENCLAW_HOME}/config.yaml" 2>&1 | tee -a "/workspace/logs/${AGENT}.log"
