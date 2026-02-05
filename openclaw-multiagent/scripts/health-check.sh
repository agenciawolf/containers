#!/bin/bash
# Health check script para OpenClaw Multi-Agent
# Verifica: Ollama + 3 agentes OpenClaw

set -euo pipefail

# Timeout para cada check (segundos)
TIMEOUT=5

# Verificar Ollama
if ! curl -sf --max-time $TIMEOUT http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[HEALTH] Ollama not responding" >&2
    exit 1
fi

# Verificar agentes OpenClaw
AGENTS_OK=0
for port in 18790 18791 18792; do
    # OpenClaw expõe /health ou responde na raiz
    if curl -sf --max-time $TIMEOUT "http://localhost:${port}/" > /dev/null 2>&1; then
        ((AGENTS_OK++))
    fi
done

# Pelo menos 1 agente deve estar rodando para health check passar
if [[ $AGENTS_OK -lt 1 ]]; then
    echo "[HEALTH] No agents responding (checked ports 18790-18792)" >&2
    exit 1
fi

echo "[HEALTH] OK - Ollama + ${AGENTS_OK}/3 agents"
exit 0
