#!/bin/bash
set -euo pipefail
echo "[SETUP] OpenClaw Multi-Agent Infrastructure"
echo "[SETUP] Workspace: /workspace"
mkdir -p /workspace/{logs,config,scripts,cache,.ollama}
mkdir -p /workspace/agents/{planner,coder,hacker}/{workspace,.openclaw}
# Permissões 777 para NFS (chown não funciona em volumes NFS)
chmod -R 777 /workspace/agents
chmod -R 777 /workspace/.ollama
chmod -R 777 /workspace/logs
echo "[SETUP] Diretorios criados com permissões 777"
