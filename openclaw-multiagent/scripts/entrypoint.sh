#!/bin/bash
# Script de inicialização otimizado para OpenClaw Multi-Agent no RunPod
# Inclui: retry exponencial, circuit breaker, health checks avançados

set -euo pipefail

# Configurações de retry
MAX_RETRIES=5
INITIAL_BACKOFF=1
MAX_BACKOFF=30
CIRCUIT_BREAKER_THRESHOLD=3

# Cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
WORKSPACE="/workspace"
LOGS_DIR="${WORKSPACE}/logs"
AGENTS_DIR="${WORKSPACE}/agents"
OLLAMA_PORT=11434
CIRCUIT_BREAKER_FILE="${WORKSPACE}/.circuit-breaker"

# Mascarar dados sensíveis (tokens, senhas)
mask_sensitive() {
    local msg="$1"
    # Mascarar tokens OpenClaw
    msg=$(echo "$msg" | sed 's/openclaw-[a-zA-Z0-9-]\{10,\}/openclaw-***MASKED***/g')
    # Mascarar senhas genéricas
    msg=$(echo "$msg" | sed 's/password[=:][^ "]*/password=***MASKED***/gi')
    echo "$msg"
}

log_info() { echo -e "${GREEN}[$(date -Iseconds)] [INFO]${NC} $(mask_sensitive "$1")"; }
log_warn() { echo -e "${YELLOW}[$(date -Iseconds)] [WARN]${NC} $(mask_sensitive "$1")"; }
log_error() { echo -e "${RED}[$(date -Iseconds)] [ERROR]${NC} $(mask_sensitive "$1")"; }
log_step() { echo -e "${BLUE}[$(date -Iseconds)] [STEP]${NC} $(mask_sensitive "$1")"; }

# Retry com backoff exponencial
retry_with_backoff() {
    local cmd="$1"
    local retries=0
    local backoff=$INITIAL_BACKOFF
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        if eval "$cmd"; then
            return 0
        fi
        
        ((retries++))
        log_warn "Comando falhou (tentativa $retries/$MAX_RETRIES). Aguardando ${backoff}s..."
        sleep $backoff
        
        # Exponential backoff com jitter
        backoff=$((backoff * 2))
        [[ $backoff -gt $MAX_BACKOFF ]] && backoff=$MAX_BACKOFF
        backoff=$((backoff + RANDOM % 5))
    done
    
    return 1
}

# Circuit breaker pattern
check_circuit_breaker() {
    local service="$1"
    local count_file="${CIRCUIT_BREAKER_FILE}.${service}"
    
    if [[ -f "$count_file" ]]; then
        local count=$(cat "$count_file" 2>/dev/null || echo 0)
        if [[ $count -ge $CIRCUIT_BREAKER_THRESHOLD ]]; then
            log_error "Circuit breaker aberto para ${service} (${count} falhas)"
            return 1
        fi
    fi
    return 0
}

record_failure() {
    local service="$1"
    local count_file="${CIRCUIT_BREAKER_FILE}.${service}"
    local count=$(cat "$count_file" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$count_file"
}

record_success() {
    local service="$1"
    local count_file="${CIRCUIT_BREAKER_FILE}.${service}"
    rm -f "$count_file"
}

# Verificar GPU com timeout
check_gpu() {
    log_step "Verificando GPU e CUDA..."
    
    local gpu_ready=false
    local attempts=0
    local max_attempts=30
    
    while [[ $attempts -lt $max_attempts ]]; do
        if command -v nvidia-smi &> /dev/null && nvidia-smi > /dev/null 2>&1; then
            gpu_ready=true
            break
        fi
        ((attempts++))
        log_info "Aguardando GPU... ($attempts/$max_attempts)"
        sleep 2
    done
    
    if [[ "$gpu_ready" == "false" ]]; then
        log_error "GPU não disponível após ${max_attempts} tentativas"
        return 1
    fi
    
    nvidia-smi --query-gpu=name,memory.total,memory.free,temperature.gpu --format=csv,noheader
    
    if [[ -z "${CUDA_VISIBLE_DEVICES:-}" ]]; then
        export CUDA_VISIBLE_DEVICES=0
    fi
    
    log_info "GPU detectada: CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
    record_success "gpu"
}

# ============================================================================
# FUNÇÃO: Inicializar estrutura de diretórios
# ============================================================================
init_directories() {
    log_step "Inicializando estrutura de diretórios persistentes (NFS /workspace)..."
    
    # Diretórios principais em /workspace (persistência NFS RunPod)
    # CRÍTICO: Tudo em /workspace sobrevive restart/redeploy do pod
    mkdir -p "${WORKSPACE}"/{logs,config,scripts}
    mkdir -p "${WORKSPACE}/.ollama/models"  # Modelos Ollama persistentes
    mkdir -p "${WORKSPACE}/.cache"/{pip,npm,yarn,pnpm-store,huggingface,cuda}
    mkdir -p "${WORKSPACE}/.supervisor"      # Socket supervisord
    
    # Limpar circuit breaker de execuções anteriores (evita bloqueio persistente)
    rm -f "${WORKSPACE}/.circuit-breaker."* 2>/dev/null || true
    
    # Variáveis dinâmicas
    local NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
    local AGENT_PREFIX="${OPENCLAW_AGENT_PREFIX:-agent}"
    
    # Diretórios dos agentes - dados persistentes (DINÂMICO)
    for i in $(seq 1 $NUM_AGENTS); do
        local agent="${AGENT_PREFIX}_${i}"
        mkdir -p "${AGENTS_DIR}/${agent}"/.openclaw
        mkdir -p "${AGENTS_DIR}/${agent}"/workspace
        # Diretório de sessões do OpenClaw (crítico para persistência de conversas)
        mkdir -p "${AGENTS_DIR}/${agent}"/.openclaw/agents/${agent}/sessions
        mkdir -p "${AGENTS_DIR}/${agent}"/.openclaw/memory
    done
    
    # Permissões 777 para volumes NFS (runtime) - necessário para funcionar no RunPod
    chmod -R 777 "${AGENTS_DIR}"
    chmod -R 777 "${WORKSPACE}/.ollama"
    chmod -R 777 "${WORKSPACE}/.cache"
    chmod -R 777 "${WORKSPACE}/logs"
    
    # CRÍTICO: Symlink de /root/.ollama para /workspace/.ollama (persistência no RunPod)
    # Ollama por padrão usa ~/.ollama que no container é /root/.ollama
    # Com symlink, modelos ficam em /workspace/.ollama/models (NFS persistente)
    if [[ -d /root/.ollama && ! -L /root/.ollama ]]; then
        # Backup se existir conteúdo
        mv /root/.ollama /root/.ollama.bak 2>/dev/null || true
    fi
    rm -rf /root/.ollama 2>/dev/null || true
    ln -sf "${WORKSPACE}/.ollama" /root/.ollama
    log_info "📁 Modelos Ollama: /root/.ollama → ${WORKSPACE}/.ollama/models (persistente)"
    
    # Symlinks de /home/<user> para /workspace/agents/<user> (OpenClaw compatibilidade)
    for i in $(seq 1 $NUM_AGENTS); do
        local agent="${AGENT_PREFIX}_${i}"
        local USER_HOME="/home/${agent}"
        local AGENT_DATA="${AGENTS_DIR}/${agent}"
        
        # Criar user se não existir
        if ! id "${agent}" &>/dev/null; then
            useradd -m -d "${USER_HOME}" -s /usr/sbin/nologin "${agent}" 2>/dev/null || true
        fi
        
        # Remover .openclaw existente em /home se houver
        rm -rf "${USER_HOME}/.openclaw" 2>/dev/null || true
        
        # Criar symlink para dados persistentes
        ln -sf "${AGENT_DATA}/.openclaw" "${USER_HOME}/.openclaw"
        
        # Criar symlink para workspace
        rm -rf "${USER_HOME}/workspace" 2>/dev/null || true
        ln -sf "${AGENT_DATA}/workspace" "${USER_HOME}/workspace"
        
        # Ajustar permissões do home
        chmod 755 "${USER_HOME}"
        
        log_info "📁 Agent ${agent}: ${USER_HOME}/.openclaw → ${AGENT_DATA}/.openclaw (persistente)"
    done
    
    log_info "✅ Estrutura de diretórios persistentes configurada"
}

# ============================================================================
# FUNÇÃO: Otimização GPU
# ============================================================================
optimize_gpu() {
    log_step "Otimizando GPU para máximo desempenho..."
    
    # Verificar memória disponível
    local mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    local mem_free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader 2>/dev/null | head -1)
    log_info "GPU Memory: ${mem_free} livre de ${mem_total}"
    
    # Habilitar persistence mode (reduz latência de cold start)
    nvidia-smi -pm ENABLED 2>/dev/null || log_warn "Persistence mode não disponível"
    
    # NOTA: NÃO usar EXCLUSIVE_PROCESS - pode bloquear Ollama de acessar GPU
    # nvidia-smi -c DEFAULT mantém modo padrão que permite múltiplos processos
    
    log_info "GPU otimizada"
}

# ============================================================================
# FUNÇÃO: Warmup do modelo (pré-carregar na VRAM)
# ============================================================================
warmup_model() {
    log_step "Executando warmup do modelo..."
    
    local MODEL="${OPENCLAW_MODEL:-glm-4.7-flash:latest}"
    local WARMUP_ENABLED="${OPENCLAW_WARMUP_ENABLED:-true}"
    
    if [[ "$WARMUP_ENABLED" != "true" ]]; then
        log_info "Warmup desabilitado via OPENCLAW_WARMUP_ENABLED"
        return 0
    fi
    
    # Aguardar Ollama responder
    local retries=0
    while [[ $retries -lt 30 ]]; do
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            break
        fi
        ((retries++))
        sleep 1
    done
    
    # Fazer requisição inicial para carregar modelo na VRAM
    log_info "Carregando ${MODEL} na VRAM..."
    curl -sf http://localhost:11434/api/generate \
        -d "{\"model\": \"${MODEL}\", \"prompt\": \"Hello\", \"stream\": false}" \
        > /dev/null 2>&1 || log_warn "Warmup inicial não completou"
    
    # Verificar memória usada
    local mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1)
    log_info "Modelo carregado - VRAM em uso: ${mem_used}"
}

# ============================================================================
# FUNÇÃO: Configurar Ollama
# ============================================================================
setup_ollama() {
    log_step "Configurando Ollama..."
    
    # Criar diretório de modelos se não existir
    mkdir -p "${OLLAMA_MODELS}"
    
    # Iniciar Ollama em background para pull do modelo
    log_info "Iniciando servidor Ollama temporário..."
    ollama serve &
    local OLLAMA_PID=$!
    
    # Aguardar Ollama estar pronto
    log_info "Aguardando Ollama estar pronto..."
    for i in {1..60}; do
        if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
            log_info "Ollama está pronto!"
            break
        fi
        log_info "Aguardando Ollama... (${i}/60)"
        sleep 1
    done
    
    # Verificar se está realmente pronto
    if ! curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        log_error "Ollama não iniciou após 60 segundos"
        exit 1
    fi
    
# =======================================================================
    # CRÍTICO: Verificar se modelo já existe antes de baixar novamente
    # Isso preserva modelos já baixados em /workspace/.ollama/models
    # =======================================================================
    local MODEL="${OPENCLAW_MODEL:-glm-4.7-flash:latest}"
    local AUTO_PULL="${OPENCLAW_MODEL_AUTO_PULL:-true}"
    
    log_info "Verificando modelo ${MODEL}..."
    
    # Extrair nome base do modelo para busca
    local MODEL_BASE=$(echo "$MODEL" | cut -d':' -f1)
    
    # Primeiro verificar se já está registrado no Ollama
    if ollama list 2>/dev/null | grep -q "${MODEL_BASE}"; then
        log_info "✅ Modelo ${MODEL} já registrado no Ollama"
    # Segundo: verificar se os arquivos existem no disco
    elif [[ -d "/workspace/.ollama/models/manifests" ]] && find /workspace/.ollama/models -name "*${MODEL_BASE}*" -type f 2>/dev/null | grep -q .; then
        log_info "📁 Arquivos do modelo encontrados em /workspace/.ollama/models"
        log_info "   Ollama detectará automaticamente ao iniciar"
    elif [[ "$AUTO_PULL" == "true" ]]; then
        log_info "📥 Baixando modelo ${MODEL} (primeira execução)..."
        if ! ollama pull "${MODEL}"; then
            log_error "Falha ao baixar ${MODEL}"
            log_error "Verifique se o modelo existe no registry Ollama"
            exit 1
        fi
        log_info "✅ Modelo baixado e salvo em /workspace/.ollama/models (persistente)"
    else
        log_warn "⚠️ Modelo ${MODEL} não encontrado e AUTO_PULL desabilitado"
    fi
    
    # Parar Ollama temporário
    kill $OLLAMA_PID 2>/dev/null || true
    wait $OLLAMA_PID 2>/dev/null || true
    
    log_info "Ollama configurado com sucesso"
}

# ============================================================================
# FUNÇÃO: Configurar Agentes OpenClaw (DINÂMICO)
# ============================================================================
setup_agents() {
    log_step "Configurando agentes OpenClaw..."
    
    # Variáveis dinâmicas da comunidade
    local NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
    local AGENT_PREFIX="${OPENCLAW_AGENT_PREFIX:-agent}"
    local BASE_PORT="${OPENCLAW_BASE_PORT:-18790}"
    local MODEL="${OPENCLAW_MODEL:-glm-4.7-flash:latest}"
    
    log_info "Configuração: ${NUM_AGENTS} agentes, modelo: ${MODEL}"
    
    # Validar número de agentes
    if [[ $NUM_AGENTS -lt 1 || $NUM_AGENTS -gt 10 ]]; then
        log_error "OPENCLAW_NUM_AGENTS deve ser entre 1 e 10 (recebido: ${NUM_AGENTS})"
        exit 1
    fi
    
    # Criar agentes dinamicamente
    for i in $(seq 1 $NUM_AGENTS); do
        local AGENT="${AGENT_PREFIX}_${i}"
        local PORT=$((BASE_PORT + i - 1))
        local AGENT_DIR="${AGENTS_DIR}/${AGENT}"
        
        log_info "Configurando agente: ${AGENT} (porta ${PORT})"
        
        # Criar diretórios
        local CONFIG_FILE="${AGENT_DIR}/.openclaw/openclaw.json"
        mkdir -p "${AGENT_DIR}/.openclaw"
        mkdir -p "${AGENT_DIR}/workspace"
        
        # Criar usuário Linux se não existir
        if ! id "${AGENT}" &>/dev/null; then
            useradd -m -d "/home/${AGENT}" -s /usr/sbin/nologin "${AGENT}" 2>/dev/null || true
        fi
        
        # =======================================================================
        # CRÍTICO: NÃO sobrescrever config existente para preservar:
        # - Token de autenticação (sessões ativas)
        # - Memórias e contexto do agente
        # - Configurações customizadas pelo usuário
        # =======================================================================
        if [[ -f "${CONFIG_FILE}" ]]; then
            log_info "✅ Config existente preservada: ${CONFIG_FILE}"
            
            # ATUALIZAÇÃO DINÂMICA DE MODELO E HARDENING
            # Aplica configurações de modelo, segurança e rede no JSON existente
            log_info "🔄 Atualizando configurações (modelo, rede, segurança) para ${AGENT}..."
            
            # trustedProxies: RFC1918 + CGNAT + localhost (cobre RunPod/Tailscale)
            # controlUi: Habilita Dashboard
            # bind: 0.0.0.0 para acesso externo
            # auth: password para usar OPENCLAW_WEB_PASSWORD
            
            if jq --arg model "$MODEL" \
                  --arg port "$PORT" \
               '.llm.model = $model | 
                .gateway.port = ($port | tonumber) |
                .gateway.bind = "0.0.0.0" |
                .gateway.controlUi.enabled = true |
                .gateway.controlUi.allowInsecureAuth = true |
                .gateway.auth.mode = "password" |
                .gateway.trustedProxies = ["127.0.0.1", "10.0.0.0/8", "100.64.0.0/10", "172.16.0.0/12", "192.168.0.0/16"]' \
               "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"; then
                log_info "✅ Configurações atualizadas com sucesso"
            else
                log_error "Falha ao atualizar configurações no JSON"
            fi
            
            continue
        fi
        
        log_info "📝 Criando nova config para ${AGENT}..."
        
        # Gerar token único
        local AGENT_TOKEN="openclaw-${AGENT}-$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)"
        
        # Identidade genérica para agentes dinâmicos
        local AGENT_NAME="Agent ${i}"
        local AGENT_THEME="assistente de IA multiuso"
        local AGENT_EMOJI="🤖"
        
        # NOTA: Heredoc SEM aspas para permitir interpolação de variáveis
        cat > "${CONFIG_FILE}" <<EOF
{
  "identity": {
    "name": "${AGENT_NAME}",
    "theme": "${AGENT_THEME}",
    "emoji": "${AGENT_EMOJI}"
  },
  "gateway": {
    "mode": "local",
    "port": ${PORT},
    "bind": "0.0.0.0",
    "controlUi": {
      "enabled": true,
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "password"
    },
    "trustedProxies": ["127.0.0.1", "10.0.0.0/8", "100.64.0.0/10", "172.16.0.0/12", "192.168.0.0/16"],
    "timeouts": {
      "request": "300s",
      "inference": "300s"
    }
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "agents": {
    "defaults": {
      "workspace": "${AGENT_DIR}/workspace",
      "model": {
        "primary": "ollama/${MODEL}"
      },
      "execution": {
        "timeout": "300s",
        "maxIterations": 50
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "ollama": {
        "apiKey": "ollama-local",
        "baseUrl": "http://localhost:11434/v1",
        "api": "openai-chat",
        "timeout": "300s",
        "models": [
          {
            "id": "${MODEL}",
            "name": "${MODEL}",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 32768,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "logging": {
    "level": "info",
    "directory": "/workspace/logs"
  }
}
EOF
        
        # Salvar token gerado para referência
        echo "${AGENT_TOKEN}" > "${AGENT_DIR}/.openclaw/token"
        
        log_info "Token gerado para ${AGENT}: ${AGENT_TOKEN:0:20}..."
        
        # Ajustar permissões para hardening (doc security: ~/.openclaw 700, openclaw.json 600)
        # Mas NFS RunPod não suporta chown/chmod, então mantemos 777
        chmod -R 777 "${AGENT_DIR}"
        
        # NOTA: Para hardening completo, rodar 'openclaw doctor' no container
    done
}

# ============================================================================
# FUNÇÃO: Criar script de execução dos agentes
# NOTA: run-agent.sh agora está em /opt/scripts (copiado no build)
# Esta função mantida para compatibilidade futura
# ============================================================================
create_agent_scripts() {
    log_step "Verificando scripts de execução..."
    
    # Verificar se run-agent.sh existe em /opt/scripts
    if [ ! -f "/opt/scripts/run-agent.sh" ]; then
        log_error "run-agent.sh não encontrado em /opt/scripts"
        exit 1
    fi
    
    log_info "Scripts verificados em /opt/scripts"
}

# ============================================================================
# FUNÇÃO: Health Check (DINÂMICO)
# ============================================================================
health_check() {
    log_step "Executando health check..."
    
    local NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
    local AGENT_PREFIX="${OPENCLAW_AGENT_PREFIX:-agent}"
    local BASE_PORT="${OPENCLAW_BASE_PORT:-18790}"
    local FAILURES=0
    
    # Verificar Ollama
    if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        log_info "✓ Ollama está respondendo"
    else
        log_error "✗ Ollama não está respondendo"
        ((FAILURES++))
    fi
    
    # Verificar agentes dinamicamente
    for i in $(seq 1 $NUM_AGENTS); do
        local AGENT="${AGENT_PREFIX}_${i}"
        local PORT=$((BASE_PORT + i - 1))
        
        if curl -s "http://localhost:${PORT}/" > /dev/null 2>&1; then
            log_info "✓ Agente ${AGENT} está respondendo na porta ${PORT}"
        else
            log_warn "✗ Agente ${AGENT} não está respondendo na porta ${PORT}"
        fi
    done
    
    return $FAILURES
}

# ============================================================================
# FUNÇÃO: Gerar configuração dinâmica do Supervisor
# ============================================================================
generate_supervisor_config() {
    log_step "Gerando configuração dinâmica do Supervisor..."
    
    local NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
    local AGENT_PREFIX="${OPENCLAW_AGENT_PREFIX:-agent}"
    local BASE_PORT="${OPENCLAW_BASE_PORT:-18790}"
    local SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord.conf"
    local DYNAMIC_AGENTS_CONF="/workspace/.supervisor/agents.conf"
    
    log_info "Gerando config para ${NUM_AGENTS} agentes (${AGENT_PREFIX}_1 até ${AGENT_PREFIX}_${NUM_AGENTS})"
    
    # Criar arquivo de configuração dinâmica dos agentes
    mkdir -p /workspace/.supervisor
    
    cat > "${DYNAMIC_AGENTS_CONF}" <<'HEADER'
; =============================================================================
; AGENTES OPENCLAW - GERADO DINAMICAMENTE
; Este arquivo é recriado a cada restart baseado em OPENCLAW_NUM_AGENTS
; =============================================================================
HEADER
    
    for i in $(seq 1 $NUM_AGENTS); do
        local AGENT="${AGENT_PREFIX}_${i}"
        local PORT=$((BASE_PORT + i - 1))
        local PRIORITY=$((20 + i))
        
        cat >> "${DYNAMIC_AGENTS_CONF}" <<EOF

[program:openclaw-${AGENT}]
command=/opt/scripts/run-agent.sh ${AGENT} ${PORT}
user=root
environment=HOME="/workspace/agents/${AGENT}",AGENT_NAME="${AGENT}",AGENT_PORT="${PORT}",OPENCLAW_WEB_PASSWORD="%(ENV_OPENCLAW_WEB_PASSWORD)s"
autostart=true
autorestart=true
startretries=5
startsecs=15
stopsignal=TERM
stopwaitsecs=30
stdout_logfile=/workspace/logs/${AGENT}.log
stderr_logfile=/workspace/logs/${AGENT}-error.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=3
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=3
priority=${PRIORITY}
EOF
    done
    
    log_info "✅ Configuração de ${NUM_AGENTS} agentes gerada em ${DYNAMIC_AGENTS_CONF}"
}

# ============================================================================
# FUNÇÃO: Setup completo (primeira execução)
# ============================================================================
full_setup() {
    log_step "Iniciando setup completo da infraestrutura..."
    
    check_gpu
    init_directories
    
    # Aplicar hardening de segurança
    log_step "Aplicando hardening de segurança..."
    if [ -f "/opt/scripts/hardening.sh" ]; then
        bash /opt/scripts/hardening.sh
        log_info "Hardening aplicado"
    fi
    
    setup_ollama
    setup_agents
    create_agent_scripts
    generate_supervisor_config  # Gera config dinâmica dos agentes
    
    # Variáveis para output
    local NUM_AGENTS="${OPENCLAW_NUM_AGENTS:-3}"
    local AGENT_PREFIX="${OPENCLAW_AGENT_PREFIX:-agent}"
    local BASE_PORT="${OPENCLAW_BASE_PORT:-18790}"
    
    log_info "Setup completo finalizado com sucesso!"
    log_info ""
    log_info "Resumo de Acesso:"
    
    # Detecção de ambiente RunPod para URLs precisas
    if [[ -n "${RUNPOD_POD_ID:-}" ]]; then
        log_info "☁️ Ambiente RunPod Detectado!"
        log_info "   Dashboard (Proxy): https://${RUNPOD_POD_ID}-${BASE_PORT}.proxy.runpod.net/"
        log_info "   Ollama API:        https://${RUNPOD_POD_ID}-${OLLAMA_PORT}.proxy.runpod.net/"
    else
        log_info "🏠 Ambiente Local / Desconhecido"
        log_info "   Dashboard:         http://localhost:${BASE_PORT}/"
        log_info "   Ollama:            http://localhost:${OLLAMA_PORT}/"
    fi

    log_info ""
    log_info "🤖 Agentes:"
    for i in $(seq 1 $NUM_AGENTS); do
        local PORT=$((BASE_PORT + i - 1))
        local AGENT_NAME="${AGENT_PREFIX}_${i}"
        
        if [[ -n "${RUNPOD_POD_ID:-}" ]]; then
             log_info "   - ${AGENT_NAME}: https://${RUNPOD_POD_ID}-${PORT}.proxy.runpod.net/"
        else
             log_info "   - ${AGENT_NAME}: http://localhost:${PORT}/"
        fi
    done
    log_info ""
    log_info "💾 Persistência em: ${WORKSPACE}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "========================================"
    log_info "OpenClaw Multi-Agent Infrastructure"
    log_info "RunPod Secure Cloud - RTX A4500"
    log_info "========================================"
    
    # Verificar se é primeira execução
    local SETUP_MARKER="${WORKSPACE}/.setup-complete"
    
    if [ ! -f "${SETUP_MARKER}" ]; then
        full_setup
        touch "${SETUP_MARKER}"
        date > "${SETUP_MARKER}"
    else
        log_info "Setup já realizado em: $(cat "${SETUP_MARKER}")"
        log_info "Executando setup parcial para restart..."
        
        # CRÍTICO: Mesmo em restart, precisamos:
        # 1. Verificar/criar symlinks (podem ter sido perdidos)
        init_directories
        
        # 2. Regenerar config do supervisor (variáveis podem ter mudado)
        generate_supervisor_config
        
        log_info "Setup parcial completo"
    fi
    
    # Executar comando passado ou iniciar supervisord
    if [ $# -eq 0 ]; then
        log_step "Iniciando supervisord..."
        
        # Iniciar warmup em background após supervisord subir (30s delay)
        (
            sleep 30
            if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
                warmup_model
            fi
        ) &
        
        exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
    else
        exec "$@"
    fi
}

main "$@"
