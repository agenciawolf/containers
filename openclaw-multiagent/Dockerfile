# BuildKit optimizado
# syntax=docker/dockerfile:1.4

# ============================================================================
# STAGE 1: Builder (compilações pesadas isoladas)
# ============================================================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=22

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Node.js em stage separado para cache eficiente
RUN mkdir -p /opt/nodejs && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}.0.0/node-v${NODE_VERSION}.0.0-linux-x64.tar.xz" | \
    tar -xJf - -C /opt/nodejs --strip-components=1 && \
    ln -sf /opt/nodejs/bin/node /usr/local/bin/node && \
    ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm

# ============================================================================
# STAGE 2: Runtime (imagem final enxuta)
# ============================================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash \
    PYTHONUNBUFFERED=True \
    TZ=Etc/UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8
# =============================================================================
# VARIÁVEIS CONFIGURÁVEIS PELA COMUNIDADE (override via ENV no deploy)
# =============================================================================

# Agentes OpenClaw
ENV OPENCLAW_NUM_AGENTS=3 \
    OPENCLAW_AGENT_PREFIX=agent \
    OPENCLAW_BASE_PORT=18790 \
    OPENCLAW_MODEL=glm-4.7-flash:latest \
    OPENCLAW_MODEL_AUTO_PULL=true \
    OPENCLAW_WARMUP_ENABLED=true

# Parâmetros do Modelo (enviados na request API)
ENV OPENCLAW_TEMPERATURE=0.7 \
    OPENCLAW_TOP_P=0.95 \
    OPENCLAW_REPEAT_PENALTY=1.0 \
    OPENCLAW_NUM_CTX=131072 \
    OPENCLAW_MAX_TOKENS=32768

# Thinking/Behavior do Agente
ENV OPENCLAW_THINKING_DEFAULT=low \
    OPENCLAW_VERBOSE_DEFAULT=off \
    OPENCLAW_ELEVATED_DEFAULT=on

# Contexto e Memória
ENV OPENCLAW_CONTEXT_TOKENS=131072 \
    OPENCLAW_TIMEOUT_SECONDS=600 \
    OPENCLAW_MAX_CONCURRENT=3

# Context Pruning (avançado)
ENV OPENCLAW_PRUNING_MODE=adaptive \
    OPENCLAW_KEEP_LAST_ASSISTANTS=3 \
    OPENCLAW_SOFT_TRIM_RATIO=0.3 \
    OPENCLAW_HARD_CLEAR_RATIO=0.5

# Ollama Server - GPU & Performance
ENV OLLAMA_NUM_PARALLEL=4 \
    OLLAMA_KV_CACHE_TYPE=q8_0 \
    OLLAMA_NUM_GPU=999 \
    OLLAMA_KEEP_ALIVE=-1 \
    OLLAMA_FLASH_ATTENTION=1 \
    OLLAMA_MAX_LOADED_MODELS=1 \
    OLLAMA_CONTEXT_LENGTH=131072 \
    OLLAMA_MAX_QUEUE=512

# Ollama Server - Rede & Logs
ENV OLLAMA_HOST=0.0.0.0 \
    OLLAMA_PORT=11434 \
    OLLAMA_DEBUG=false \
    LOG_LEVEL=info

# =============================================================================
# VARIÁVEIS INTERNAS (não alterar)
# =============================================================================
ENV RP_WORKSPACE=/workspace \
    OLLAMA_HOME=/workspace/.ollama \
    OLLAMA_MODELS=/workspace/.ollama/models \
    OPENCLAW_HOME=/workspace/.openclaw \
    OPENCLAW_WORKSPACE=/workspace/openclaw-workspace \
    NODE_PATH=/opt/nodejs/lib/node_modules \
    PATH="/opt/nodejs/bin:/usr/local/cuda/bin:${PATH}" \
    # Cache directories (NFS persistent)
    HF_HOME="/workspace/.cache/huggingface" \
    PIP_CACHE_DIR="/workspace/.cache/pip" \
    UV_CACHE_DIR="/workspace/.cache/uv" \
    NPM_CONFIG_CACHE="/workspace/.cache/npm" \
    YARN_CACHE_FOLDER="/workspace/.cache/yarn" \
    # CUDA Performance Tuning
    CUDA_DEVICE_ORDER="PCI_BUS_ID" \
    CUDA_CACHE_PATH="/workspace/.cache/cuda" \
    CUDA_CACHE_MAXSIZE="2147483648" \
    NVIDIA_DISABLE_REQUIRE="true" \
    NVIDIA_DRIVER_CAPABILITIES="compute,utility"

# Instalação otimizada - limpeza em uma única camada
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # Build essentials (mínimo necessário)
    build-essential ca-certificates cmake curl git wget unzip zip zstd dos2unix \
    # Python otimizado
    python3.10 python3.10-venv python3-pip \
    # Segurança: apenas ferramentas essenciais
    nmap netcat-openbsd dnsutils \
    # Dev tools
    vim nano tmux htop jq tree rsync \
    locales \
    sudo supervisor logrotate inotify-tools \
    openssh-server sshpass \
    libssl-dev libffi-dev libgl1 libgomp1 \
    ffmpeg libsm6 libxext6 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configuração de locale otimizada
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Ollama instalado diretamente (sem dev packages)
RUN curl -fsSL https://ollama.com/install.sh | sh && \
    mkdir -p /workspace/.ollama/models && \
    rm -rf /root/.ollama/models/* 2>/dev/null || true

# Copiar Node.js do stage builder
COPY --from=builder /opt/nodejs /opt/nodejs
RUN ln -sf /opt/nodejs/bin/node /usr/local/bin/node && \
    ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm && \
    ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx

# Security: criar usuários sem shell de login
RUN useradd -m -d /home/planner -s /usr/sbin/nologin -u 1001 planner && \
    useradd -m -d /home/coder -s /usr/sbin/nologin -u 1002 coder && \
    useradd -m -d /home/hacker -s /bin/bash -u 1003 hacker && \
    usermod -aG sudo hacker

# Sudo restrito apenas para ferramentas específicas
RUN echo "hacker ALL=(ALL) NOPASSWD: /usr/bin/nmap, /usr/bin/nikto, /usr/bin/masscan" > /etc/sudoers.d/hacker && \
    chmod 440 /etc/sudoers.d/hacker

# Security: remover capabilities desnecessárias
RUN apt-get remove -y --purge linux-libc-dev 2>/dev/null || true

# OpenClaw - instalar versão específica com suporte a contextPruning
RUN npm install -g openclaw@2026.2.3 && \
    npm cache clean --force

# Diretórios criados no runtime para evitar problemas com volumes NFS
RUN mkdir -p /var/log/supervisor /var/run /etc/supervisor/conf.d

# Copiar configurações e scripts
COPY --chmod=755 scripts/*.sh /opt/scripts/
RUN dos2unix /opt/scripts/*.sh

COPY config/*.yaml /opt/config/
COPY config/supervisord.conf /etc/supervisor/conf.d/

# Health check nativo do Docker - verifica Ollama + agentes
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=3 \
    CMD /opt/scripts/health-check.sh

# Portas expostas (Ollama + até 10 agentes + SSH)
EXPOSE 11434 18790-18799 22

WORKDIR /workspace

COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
