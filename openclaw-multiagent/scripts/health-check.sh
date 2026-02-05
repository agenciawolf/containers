#!/bin/bash
# Health check script para OpenClaw Multi-Agent (DINÂMICO)
# Verifica: Ollama + agentes configurados via ENV

set -euo pipefail

# Variáveis dinâmicas
NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
BASE_PORT="${OPENCLAW_BASE_PORT:-18790}"
TIMEOUT=5

# Verificar Ollama
if ! curl -sf --max-time $TIMEOUT http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[HEALTH] Ollama not responding" >&2
    exit 1
fi

# Verificar agentes dinamicamente
AGENTS_OK=0
for i in $(seq 1 $NUM_AGENTS); do
    PORT=$((BASE_PORT + i - 1))
    # OpenClaw responde na raiz
    if curl -sf --max-time $TIMEOUT "http://localhost:${PORT}/" > /dev/null 2>&1; then
        ((AGENTS_OK++))
    fi
done

# Pelo menos 1 agente deve estar rodando para health check passar
if [[ $AGENTS_OK -lt 1 ]]; then
    echo "[HEALTH] No agents responding (checked ports ${BASE_PORT}-$((BASE_PORT + NUM_AGENTS - 1)))" >&2
    exit 1
fi

echo "[HEALTH] OK - Ollama + ${AGENTS_OK}/${NUM_AGENTS} agents"
exit 0
