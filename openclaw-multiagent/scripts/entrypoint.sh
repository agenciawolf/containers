#!/bin/bash
# Script de inicialização principal para OpenClaw Multi-Agent no RunPod
# Responsável por: setup inicial, health checks, e inicialização de serviços

set -euo pipefail

# Cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
WORKSPACE="/workspace"
LOGS_DIR="${WORKSPACE}/logs"
AGENTS_DIR="${WORKSPACE}/agents"
OLLAMA_PORT=11434

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================================================
# FUNÇÃO: Verificar GPU e CUDA
# ============================================================================
check_gpu() {
    log_step "Verificando GPU e CUDA..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi não encontrado. GPU pode não estar disponível."
        exit 1
    fi
    
    nvidia-smi
    
    if [ -z "${CUDA_VISIBLE_DEVICES:-}" ]; then
        export CUDA_VISIBLE_DEVICES=0
    fi
    
    log_info "GPU detectada: CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
}

# ============================================================================
# FUNÇÃO: Inicializar estrutura de diretórios
# ============================================================================
init_directories() {
    log_step "Inicializando estrutura de diretórios..."
    
    # Diretórios principais em /workspace (persistência NFS)
    mkdir -p "${WORKSPACE}"/{logs,config,scripts,cache,.ollama}
    mkdir -p "${WORKSPACE}/.cache"/{pip,npm,yarn,pnpm-store,huggingface}
    
    # Diretórios dos agentes - dados persistentes
    for agent in planner coder hacker; do
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
    
    # Symlinks de /home/<user> para /workspace/agents/<user> (OpenClaw compatibilidade)
    for agent in planner coder hacker; do
        local USER_HOME="/home/${agent}"
        local AGENT_DATA="${AGENTS_DIR}/${agent}"
        
        # Remover .openclaw existente em /home se houver
        rm -rf "${USER_HOME}/.openclaw" 2>/dev/null || true
        
        # Criar symlink para dados persistentes
        ln -sf "${AGENT_DATA}/.openclaw" "${USER_HOME}/.openclaw"
        
        # Criar symlink para workspace
        rm -rf "${USER_HOME}/workspace" 2>/dev/null || true
        ln -sf "${AGENT_DATA}/workspace" "${USER_HOME}/workspace"
        
        # Ajustar permissões do home
        chmod 755 "${USER_HOME}"
    done
    
    log_info "Estrutura de diretórios criada com sucesso (symlinks para persistência)"
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
    
    # Verificar se modelo GLM-4.7-Flash existe, senão fazer pull
    log_info "Verificando modelo glm-4.7-flash..."
    if ! ollama list | grep -q "glm-4.7-flash"; then
        log_info "Baixando modelo glm-4.7-flash (isso pode levar alguns minutos)..."
        ollama pull glm-4.7-flash || {
            log_warn "Modelo glm-4.7-flash não encontrado no registry padrão"
            log_info "Tentando alternativas..."
            # Tentar nome alternativo ou similar
            ollama pull qwen2.5:14b
        }
    else
        log_info "Modelo glm-4.7-flash já disponível"
    fi
    
    # Parar Ollama temporário
    kill $OLLAMA_PID 2>/dev/null || true
    wait $OLLAMA_PID 2>/dev/null || true
    
    log_info "Ollama configurado com sucesso"
}

# ============================================================================
# FUNÇÃO: Configurar Agentes OpenClaw
# ============================================================================
setup_agents() {
    log_step "Configurando agentes OpenClaw..."
    
    local AGENTS=("planner" "coder" "hacker")
    local PORTS=(18790 18791 18792)
    
    for i in "${!AGENTS[@]}"; do
        local AGENT="${AGENTS[$i]}"
        local PORT="${PORTS[$i]}"
        local AGENT_DIR="${AGENTS_DIR}/${AGENT}"
        
        log_info "Configurando agente: ${AGENT} (porta ${PORT})"
        
        # Criar configuração específica do agente
        local CONFIG_FILE="${AGENT_DIR}/.openclaw/config.yaml"
        mkdir -p "${AGENT_DIR}/.openclaw"
        
        cat > "${CONFIG_FILE}" << EOF
# Configuração OpenClaw para agente: ${AGENT}
# Persistência em: ${AGENT_DIR}/.openclaw

gateway:
  port: ${PORT}
  host: 0.0.0.0
  # Trusted proxies para RunPod (evita erro de pairing)
  trustedProxies: ["127.0.0.1", "10.0.0.0/8", "100.64.0.0/10"]
  auth:
    token: "${OPENCLAW_WEB_PASSWORD:-minhasenha123}"

agents:
  defaults:
    model:
      primary: "ollama/glm-4.7-flash"
      fallback: ["ollama/qwen2.5-coder:32b"]
    systemPrompt: |
      Você é o agente ${AGENT} de uma equipe multi-agente.
      Seu papel: $(case ${AGENT} in
        planner) echo "arquitetura de soluções, planejamento e design de sistemas" ;;
        coder) echo "desenvolvimento de código, debugging e otimização" ;;
        hacker) echo "segurança, testes de penetração e análise de vulnerabilidades" ;;
      esac)
      
      Diretrizes:
      - Sempre justifique suas decisões
      - Considere segurança e performance
      - Documente seu raciocínio
      
  ${AGENT}:
    name: "${AGENT^}"
    description: "Agente especializado em ${AGENT}"
    
    # Configuração de ferramentas
    tools:
      bash:
        enabled: true
      browser:
        enabled: true
      web:
        enabled: true
        search:
          enabled: true
      files:
        enabled: true

models:
  defaults:
    provider: ollama
    model: ollama/glm-4.7-flash
  providers:
    ollama:
      apiKey: "ollama-local"
      baseUrl: "http://localhost:11434/v1"
      models:
        - id: "glm-4.7-flash"
          name: "GLM-4.7-Flash"
          reasoning: true
          input: ["text"]
          cost:
            input: 0
            output: 0
            cacheRead: 0
            cacheWrite: 0
          contextWindow: 32768
          maxTokens: 32768

logging:
  level: info
  file: "${WORKSPACE}/logs/${AGENT}-openclaw.log"

memory:
  persistence:
    enabled: true
    directory: "${AGENT_DIR}/.openclaw/memory"
EOF
        
        # Ajustar permissões 777 para NFS (sem chown)
        chmod -R 777 "${AGENT_DIR}"
        
        log_info "Configuração criada para ${AGENT} em ${CONFIG_FILE}"
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
# FUNÇÃO: Health Check
# ============================================================================
health_check() {
    log_step "Executando health check..."
    
    local FAILURES=0
    
    # Verificar Ollama
    if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        log_info "✓ Ollama está respondendo"
    else
        log_error "✗ Ollama não está respondendo"
        ((FAILURES++))
    fi
    
    # Verificar agentes
    local PORTS=(18790 18791 18792)
    local NAMES=("planner" "coder" "hacker")
    
    for i in "${!PORTS[@]}"; do
        if curl -s "http://localhost:${PORTS[$i]}/health" > /dev/null 2>&1; then
            log_info "✓ Agente ${NAMES[$i]} está respondendo na porta ${PORTS[$i]}"
        else
            log_warn "✗ Agente ${NAMES[$i]} não está respondendo na porta ${PORTS[$i]}"
        fi
    done
    
    return $FAILURES
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
    
    log_info "Setup completo finalizado com sucesso!"
    log_info ""
    log_info "Resumo:"
    log_info "  - Ollama: http://localhost:${OLLAMA_PORT}"
    log_info "  - Planner: http://localhost:18790"
    log_info "  - Coder:   http://localhost:18791"
    log_info "  - Hacker:  http://localhost:18792"
    log_info ""
    log_info "Persistência em: ${WORKSPACE}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "========================================"
    log_info "OpenClaw Multi-Agent Infrastructure"
    log_info "RunPod Secure Cloud - RTX 5090"
    log_info "========================================"
    
    # Verificar se é primeira execução
    local SETUP_MARKER="${WORKSPACE}/.setup-complete"
    
    if [ ! -f "${SETUP_MARKER}" ]; then
        full_setup
        touch "${SETUP_MARKER}"
        date > "${SETUP_MARKER}"
    else
        log_info "Setup já realizado em: $(cat "${SETUP_MARKER}")"
        log_info "Pulando configuração inicial..."
    fi
    
    # Executar comando passado ou iniciar supervisord
    if [ $# -eq 0 ]; then
        log_step "Iniciando supervisord..."
        exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
    else
        exec "$@"
    fi
}

main "$@"
