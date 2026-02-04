#!/bin/bash
# Health check robusto com timeouts e retry logic
# Retorna código de saída 0 se tudo OK, 1 se falha

set -euo pipefail

TIMEOUT=5
MAX_RETRIES=3
LOG_FILE="/workspace/logs/health-check.log"

# Função para log structured
log() {
    echo "[$(date -Iseconds)] $1" | tee -a "${LOG_FILE}"
}

# Check com timeout e retry
check_with_retry() {
    local url="$1"
    local name="$2"
    local retry=0
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        if timeout "${TIMEOUT}" curl -sf "${url}" > /dev/null 2>&1; then
            return 0
        fi
        ((retry++))
        [[ $retry -lt $MAX_RETRIES ]] && sleep 1
    done
    return 1
}

main() {
    local failed=0
    
    log "[HEALTH] Iniciando verificação..."
    
    # Verificar Ollama
    if check_with_retry "http://localhost:11434/api/tags" "Ollama"; then
        log "[HEALTH] ✓ Ollama OK (porta 11434)"
    else
        log "[HEALTH] ✗ Ollama FAIL (porta 11434)"
        ((failed++))
    fi
    
    # Verificar agentes
    local agents=(
        "18790:planner"
        "18791:coder"
        "18792:hacker"
    )
    
    for agent_info in "${agents[@]}"; do
        IFS=':' read -r port name <<< "$agent_info"
        if check_with_retry "http://localhost:${port}/health" "$name"; then
            log "[HEALTH] ✓ Agente ${name} OK (porta ${port})"
        else
            log "[HEALTH] ✗ Agente ${name} FAIL (porta ${port})"
            ((failed++))
        fi
    done
    
    # Verificar espaço em disco
    local disk_usage=$(df /workspace | tail -1 | awk '{print $5}' | tr -d '%')
    if [[ $disk_usage -gt 90 ]]; then
        log "[HEALTH] ⚠ ALERTA: Uso de disco em ${disk_usage}%"
        ((failed++))
    else
        log "[HEALTH] ✓ Uso de disco OK (${disk_usage}%)"
    fi
    
    # Verificar memória
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 95 ]]; then
        log "[HEALTH] ⚠ ALERTA: Uso de memória em ${mem_usage}%"
        ((failed++))
    else
        log "[HEALTH] ✓ Uso de memória OK (${mem_usage}%)"
    fi
    
    if [[ $failed -eq 0 ]]; then
        log "[HEALTH] ✓ Todos os serviços OK"
        exit 0
    else
        log "[HEALTH] ✗ ${failed} serviço(s) com problema"
        exit 1
    fi
}

main "$@"
