#!/bin/bash
# Process monitor para supervisord event listener
# Reinicia serviços falhos com backoff exponencial

set -euo pipefail

LOG_FILE="/workspace/logs/process-monitor.log"
BACKOFF_FILE="/workspace/.process-backoff"
MAX_BACKOFF=300  # 5 minutos

log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

get_backoff() {
    local process="$1"
    local count_file="${BACKOFF_FILE}.${process}"
    local count=$(cat "$count_file" 2>/dev/null || echo 0)
    local backoff=$((2 ** count))
    [[ $backoff -gt $MAX_BACKOFF ]] && backoff=$MAX_BACKOFF
    echo $backoff
}

increment_backoff() {
    local process="$1"
    local count_file="${BACKOFF_FILE}.${process}"
    local count=$(cat "$count_file" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$count_file"
}

reset_backoff() {
    local process="$1"
    local count_file="${BACKOFF_FILE}.${process}"
    rm -f "$count_file"
}

# Ler eventos do supervisord
while IFS= read -r line; do
    log "Evento recebido: $line"
    
    # Parse do evento
    if echo "$line" | grep -q "PROCESS_STATE_EXITED\|PROCESS_STATE_FATAL"; then
        process=$(echo "$line" | grep -oP 'processname:\K[^ ]+' || echo "unknown")
        from_state=$(echo "$line" | grep -oP 'from_state:\K[^ ]+' || echo "unknown")
        
        log "Processo $process falhou (estado: $from_state)"
        
        # Calcular backoff
        backoff=$(get_backoff "$process")
        log "Aguardando ${backoff}s antes de reiniciar $process"
        sleep $backoff
        
        # Incrementar backoff para próxima falha
        increment_backoff "$process"
        
        # Enviar comando de restart para supervisord
        echo "RESULT 2\nOK" >&3
        echo "restarting $process" >&3
    else
        # Evento de sucesso - resetar backoff
        if echo "$line" | grep -q "PROCESS_STATE_RUNNING"; then
            process=$(echo "$line" | grep -oP 'processname:\K[^ ]+' || echo "unknown")
            reset_backoff "$process"
            log "Processo $process está rodando - backoff resetado"
        fi
        
        echo "RESULT 2\nOK" >&3
    fi
done
