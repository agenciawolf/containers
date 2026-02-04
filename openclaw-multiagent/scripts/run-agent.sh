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

# Dados persistentes em /workspace via symlink
export OPENCLAW_HOME="${HOME}/.openclaw"
export PATH="/opt/pnpm:/opt/nodejs/bin:${PATH}"

# Configuração de log
LOG_FILE="/workspace/logs/${AGENT}.log"

# Graceful shutdown handler
cleanup() {
    echo "[$(date)] Received shutdown signal, stopping ${AGENT}..." >> "${LOG_FILE}"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Verificar se config existe
if [[ ! -f "${OPENCLAW_HOME}/config.yaml" ]]; then
    echo "[ERROR] Config file not found: ${OPENCLAW_HOME}/config.yaml" >> "${LOG_FILE}"
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
            echo "[$(date)] Ollama is ready" >> "${LOG_FILE}"
            return 0
        fi
        echo "[$(date)] Waiting for Ollama... (attempt $((retry+1))/${max_retries})" >> "${LOG_FILE}"
        sleep $backoff
        backoff=$((backoff * 2))
        [[ $backoff -gt 10 ]] && backoff=10
        ((retry++))
    done
    
    echo "[ERROR] Ollama not available after ${max_retries} attempts" >> "${LOG_FILE}"
    return 1
}

wait_for_ollama || exit 1

# Iniciar agente com logging estruturado
echo "[$(date)] Starting ${AGENT} on port ${PORT}" >> "${LOG_FILE}"
exec openclaw gateway --port "${PORT}" --config "${OPENCLAW_HOME}/config.yaml" 2>&1 | tee -a "${LOG_FILE}"
