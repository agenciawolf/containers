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

# Diretórios de dados persistentes (crítico para isolamento multi-instance)
AGENT_DATA_DIR="/workspace/agents/${AGENT}"

# OpenClaw Multi-Instance Isolation (conforme documentação oficial)
# https://docs.openclaw.ai/gateway/configuration#multi-instance-isolation
export OPENCLAW_CONFIG_PATH="${AGENT_DATA_DIR}/.openclaw/openclaw.json"
export OPENCLAW_STATE_DIR="${AGENT_DATA_DIR}/.openclaw"

# OpenClaw Gateway auth via env vars (conforme documentação)
# OpenClaw Gateway auth via env vars (conforme documentação)
# NOTA: Token é lido do arquivo de configuração (JSON).
# NÃO exportar default aqui para não sobrescrever o token seguro gerado no entrypoint.
# export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-openclaw-${AGENT}-token}"

# SEGURANÇA: Exigir senha configurada, não usar fallback inseguro
if [[ -z "${OPENCLAW_WEB_PASSWORD:-}" ]]; then
    echo "[ERROR] OPENCLAW_WEB_PASSWORD não configurada!" >&2
    echo "[INFO] Configure a variável de ambiente no deploy RunPod" >&2
    exit 1
fi
export OPENCLAW_GATEWAY_PASSWORD="${OPENCLAW_WEB_PASSWORD}"

# Dados persistentes em /workspace via symlink
export OPENCLAW_HOME="${AGENT_DATA_DIR}/.openclaw"
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
if [[ ! -f "${OPENCLAW_CONFIG_PATH}" ]]; then
    echo "[ERROR] Config file not found: ${OPENCLAW_CONFIG_PATH}" >&2
    echo "[INFO] Checking if entrypoint.sh created the config..." >&2
    ls -la "${AGENT_DATA_DIR}/.openclaw/" 2>&1 >&2 || true
    exit 1
fi

echo "[$(date)] Using config: ${OPENCLAW_CONFIG_PATH}" >&2
echo "[$(date)] State dir: ${OPENCLAW_STATE_DIR}" >&2

cd "${AGENT_DATA_DIR}"

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
# Usar --config para especificar arquivo de configuração explicitamente
echo "[$(date)] Starting OpenClaw gateway for ${AGENT} on port ${PORT}..." >&2
exec openclaw gateway --port "${PORT}" --bind lan --allow-unconfigured

