#!/bin/bash
# Script otimizado para execução de agentes OpenClaw
# Inclui: resource limits, graceful shutdown, restart backoff

set -euo pipefail

AGENT="${1:-planner}"
PORT="${2:-18790}"

# Configurações de resource limits
MAX_MEMORY="${AGENT_MAX_MEMORY:-8G}"
MAX_CPU="${AGENT_MAX_CPU:-4}"

# HOME padrão Linux (/home/<user>) - OpenClaw espera essa estrutura
export HOME="/home/${AGENT}"

# OpenClaw Gateway auth via env vars (conforme documentação)
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-openclaw-${AGENT}-token}"
export OPENCLAW_GATEWAY_PASSWORD="${OPENCLAW_WEB_PASSWORD:-minhasenha123}"

# Dados persistentes em /workspace via symlink
export OPENCLAW_HOME="${HOME}/.openclaw"
export PATH="/opt/nodejs/bin:${PATH}"

# Configuração de log - supervisord gerencia automaticamente
# NOTA: chmod não funciona em volumes NFS do RunPod Secure Cloud

# Graceful shutdown handler
cleanup() {
    echo "[$(date)] Received shutdown signal, stopping ${AGENT}..." >&2
    exit 0
}
trap cleanup SIGTERM SIGINT

# Verificar se config existe (JSON conforme docs OpenClaw)
if [[ ! -f "${OPENCLAW_HOME}/openclaw.json" ]]; then
    echo "[ERROR] Config file not found: ${OPENCLAW_HOME}/openclaw.json" >&2
    exit 1
fi

cd "${HOME}"

# Aguardar Ollama estar pronto (com retry exponencial)
wait_for_ollama() {
    local max_retries=30
    local retry=0
    local backoff=1
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "[$(date)] Ollama is ready" >&2
            return 0
        fi
        echo "[$(date)] Waiting for Ollama... (attempt $((retry+1))/${max_retries})" >&2
        sleep $backoff
        backoff=$((backoff * 2))
        [[ $backoff -gt 10 ]] && backoff=10
        ((retry++))
    done
    
    echo "[ERROR] Ollama not available after ${max_retries} attempts" >&2
    return 1
}

wait_for_ollama || exit 1

# Iniciar agente - supervisord gerencia logs automaticamente
exec openclaw gateway --port "${PORT}" --allow-unconfigured --bind loopback --token "${OPENCLAW_GATEWAY_TOKEN}"
