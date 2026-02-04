#!/bin/bash
set -euo pipefail
echo "[SETUP] OpenClaw Multi-Agent Infrastructure"
echo "[SETUP] Workspace: /workspace"
mkdir -p /workspace/{logs,config,scripts,cache,.ollama}
mkdir -p /workspace/agents/{planner,coder,hacker}/workspace
chown -R planner:planner /workspace/agents/planner
chown -R coder:coder /workspace/agents/coder
chown -R hacker:hacker /workspace/agents/hacker
echo "[SETUP] Diretorios criados"
