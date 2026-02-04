# OpenClaw Multi-Agent Infrastructure for RunPod Secure Cloud
# Arquitetura: Ollama (GLM 4.7 Flash) + 3 Agentes OpenClaw (planner, coder, hacker)
# Persistência total em /workspace
# GPU: RTX 5090

FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# ============================================================================
# ARGUMENTOS E CONFIGURAÇÕES
# ============================================================================
ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=22

ENV SHELL=/bin/bash
ENV PYTHONUNBUFFERED=True
ENV TZ=Etc/UTC

# ============================================================================
# DIRETÓRIOS DE PERSISTÊNCIA (RUNPOD /WORKSPACE)
# ============================================================================
ENV RP_WORKSPACE=/workspace
ENV OLLAMA_HOME=/workspace/.ollama
ENV OLLAMA_MODELS=/workspace/.ollama/models
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_PORT=11434
ENV OLLAMA_NUM_PARALLEL=3
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_FLASH_ATTENTION=1

# OpenClaw configurações
ENV OPENCLAW_HOME=/workspace/.openclaw
ENV OPENCLAW_WORKSPACE=/workspace/openclaw-workspace
ENV PNPM_HOME=/opt/pnpm
ENV NODE_PATH=/opt/nodejs/lib/node_modules
ENV PATH="/opt/pnpm:/opt/nodejs/bin:/usr/local/cuda/bin:${PATH}"

# Cache compartilhado - diretórios serão criados no runtime
ENV HF_HOME="/workspace/.cache/huggingface"
ENV PIP_CACHE_DIR="/workspace/.cache/pip"
ENV UV_CACHE_DIR="/workspace/.cache/uv"
ENV NPM_CONFIG_CACHE="/workspace/.cache/npm"
ENV YARN_CACHE_FOLDER="/workspace/.cache/yarn"

# ============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS DO SISTEMA
# ============================================================================
RUN apt-get update --yes && apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # Build essentials
    build-essential ca-certificates cmake curl git wget unzip zip \
    # Python e ferramentas
    python3.10 python3.10-dev python3.10-venv python3-pip \
    # Ferramentas de rede e segurança (para o agente hacker)
    nmap netcat-openbsd traceroute dnsutils whois masscan nikto \
    # Ferramentas de desenvolvimento
    vim nano tmux htop iotools jq yq tree rsync \
    # Ferramentas de sistema
    sudo cron supervisor logrotate inotify-tools \
    # SSH e acesso remoto
    openssh-server sshpass \
    # Outras dependências
    libssl-dev libffi-dev libgl1 libgomp1 \
    ffmpeg libsm6 libxext6 && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================================================
# CONFIGURAÇÃO DE LOCALE E TIMEZONE
# ============================================================================
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ============================================================================
# INSTALAÇÃO DO OLLAMA (GPU NATIVO)
# ============================================================================
RUN curl -fsSL https://ollama.com/install.sh | sh && \
    mkdir -p /workspace/.ollama/models

# ============================================================================
# INSTALAÇÃO DO NODE.JS 22 (FORA DO /WORKSPACE - EVITA CONFLITO COM VOLUME NFS)
# ============================================================================
RUN mkdir -p /opt/nodejs && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}.0.0/node-v${NODE_VERSION}.0.0-linux-x64.tar.xz" | \
    tar -xJf - -C /opt/nodejs --strip-components=1 && \
    ln -sf /opt/nodejs/bin/node /usr/local/bin/node && \
    ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm

# Instalar pnpm em /opt (não em /workspace)
RUN npm install -g pnpm && \
    mkdir -p /opt/pnpm && \
    pnpm config set store-dir /opt/pnpm-store

# ============================================================================
# CRIAÇÃO DE USUÁRIOS ISOLADOS (3 AGENTES)
# PERMISSÕES SERÃO AJUSTADAS NO RUNTIME (entrypoint.sh)
# ============================================================================
# Agente Planner: planejamento e arquitetura
RUN useradd -m -d /home/planner -s /bin/bash -u 1001 planner

# Agente Coder: desenvolvimento de código
RUN useradd -m -d /home/coder -s /bin/bash -u 1002 coder

# Agente Hacker: segurança e testes (acesso total às ferramentas)
RUN useradd -m -d /home/hacker -s /bin/bash -u 1003 hacker && \
    usermod -aG sudo hacker

# Permissões para acesso às ferramentas do sistema (especialmente para hacker)
RUN echo "hacker ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hacker && \
    chmod 440 /etc/sudoers.d/hacker

# ============================================================================
# INSTALAÇÃO DO OPENCLAW GLOBAL
# ============================================================================
RUN npm install -g openclaw@latest

# ============================================================================
# DIRETÓRIOS DE LOGS E SUPERVISOR
# ============================================================================
RUN mkdir -p /var/log/supervisor /var/run

# ============================================================================
# SCRIPTS DE INICIALIZAÇÃO (copiados para /opt/scripts - fora do /workspace)
# ============================================================================
COPY scripts/init-ollama.sh /opt/scripts/
COPY scripts/init-agents.sh /opt/scripts/
COPY scripts/health-check.sh /opt/scripts/
COPY scripts/setup.sh /opt/scripts/
COPY config/supervisord.conf /opt/config/
COPY config/openclaw-template.yaml /opt/config/

RUN chmod +x /opt/scripts/*.sh

# ============================================================================
# CONFIGURAÇÃO DO SUPERVISOR (GERENCIAMENTO DE PROCESSOS)
# ============================================================================
RUN echo '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/workspace/logs/supervisord.log\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:ollama]\n\
command=/usr/local/bin/ollama serve\n\
user=root\n\
environment=HOME="/workspace",OLLAMA_HOST="%(ENV_OLLAMA_HOST)s",OLLAMA_PORT="%(ENV_OLLAMA_PORT)s",OLLAMA_MODELS="%(ENV_OLLAMA_MODELS)s",OLLAMA_NUM_PARALLEL="%(ENV_OLLAMA_NUM_PARALLEL)s",OLLAMA_MAX_LOADED_MODELS="%(ENV_OLLAMA_MAX_LOADED_MODELS)s",OLLAMA_FLASH_ATTENTION="%(ENV_OLLAMA_FLASH_ATTENTION)s",CUDA_VISIBLE_DEVICES="0"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/workspace/logs/ollama.log\n\
stderr_logfile=/workspace/logs/ollama-error.log\n\
\n\
[program:openclaw-planner]\n\
command=/opt/scripts/run-agent.sh planner 18790\n\
user=planner\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/workspace/logs/planner.log\n\
stderr_logfile=/workspace/logs/planner-error.log\n\
priority=20\n\
startsecs=5\n\
\n\
[program:openclaw-coder]\n\
command=/opt/scripts/run-agent.sh coder 18791\n\
user=coder\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/workspace/logs/coder.log\n\
stderr_logfile=/workspace/logs/coder-error.log\n\
priority=20\n\
startsecs=5\n\
\n\
[program:openclaw-hacker]\n\
command=/opt/scripts/run-agent.sh hacker 18792\n\
user=hacker\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/workspace/logs/hacker.log\n\
stderr_logfile=/workspace/logs/hacker-error.log\n\
priority=20\n\
startsecs=5\n\
\n\
[group:openclaw]\n\
programs=openclaw-planner,openclaw-coder,openclaw-hacker' > /etc/supervisor/conf.d/supervisord.conf

# ============================================================================
# PERMISSÕES FINAIS
# ============================================================================
RUN chown -R root:root /workspace/config && \
    chmod 755 /workspace && \
    chmod 755 /workspace/.ollama && \
    chmod 755 /workspace/.cache

# ============================================================================
# PORTAS EXPOSAS
# ============================================================================
# Ollama API
EXPOSE 11434
# OpenClaw Agents (planner, coder, hacker)
EXPOSE 18790 18791 18792
# SSH
EXPOSE 22

# ============================================================================
# WORKDIR E ENTRYPOINT
# ============================================================================
WORKDIR /workspace

# Script de inicialização principal
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
