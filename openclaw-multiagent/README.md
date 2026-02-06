# 🤖 OpenClaw Multi-Agent Container (RunPod Edition)

> **O Solucionador Autônomo Definitivo para GPUs Cloud**

Este projeto é um container **all-in-one** projetado para implantar enxames de agentes **OpenClaw** rodando 100% locais via **Ollama**, otimizado especificamente para a infraestrutura da **RunPod Community Cloud**.

### 🎯 Objetivo do Projeto
Permitir que desenvolvedores e pesquisadores rodem **múltiplos agentes autônomos simultâneos** (até 10+) em uma única GPU potente (como RTX 3090/4090 ou A6000), compartilhando recursos de forma inteligente e eficiente.

### ✨ Principais Recursos
- **🧠 Múltiplos Cérebros, Uma GPU:** Roda N instâncias do OpenClaw isoladas, compartilhando o mesmo backend Ollama.
- **⚡ Otimizado para RunPod:** Configuração zero-touch com reconhecimento automático de IP e portas.
- **📦 Stack Completa:** Inclui OpenClaw (Frontend/Backend) + Ollama Server + Modelos (GLM-4 / Qwen) pré-configurados.
- **💾 Persistência Inteligente:** Cache de modelos e memórias de longo prazo sobrevivem a reinicializações do Pod.
- **🔧 Configurável via ENV:** Controle total sobre comportamento do agente, parâmetros de modelo e consumo de VRAM sem tocar em arquivos de config.

---

## 🚀 Quick Start

```bash
# RunPod - Use a imagem direto
blacktech/openclaw-multiagent:latest

# Variável OBRIGATÓRIA
OPENCLAW_WEB_PASSWORD=sua_senha_forte

# Portas HTTP OBRIGATÓRIAS (expor no RunPod)
# 18790 - Agente 1 (sempre)
# 18791 - Agente 2 (se NUM_AGENTS >= 2)
# 18792 - Agente 3 (se NUM_AGENTS >= 3)
# ... até 18799 (máx 10 agentes)
```

**Porta padrão:** `18790` (primeiro agente)

### 🔓 Como Acessar (Primeiro Acesso)

Após o container iniciar (pode levar ~30s para carregar os modelos):

1. Vá no painel do RunPod e clique em **Connect** > **Expose Port (18790)** ou copie a URL do Proxy.
2. A URL será algo como: `https://{POD_ID}-18790.proxy.runpod.net/overview`
3. Você verá uma tela de login.
4. **Input:** `Password (not stored)`
5. **Senha:** Use a mesma definida na ENV `OPENCLAW_WEB_PASSWORD`.

> 💡 **Dica:** O OpenClaw usa essa senha apenas para autenticar a sessão local no browser.

---

## 📋 Índice

1. [Variáveis de Ambiente](#-variáveis-de-ambiente)
   - [Configuração de Agentes](#configuração-de-agentes)
   - [Parâmetros do Modelo](#parâmetros-do-modelo-request-api)
   - [Thinking/Behavior](#thinkingbehavior-do-agente)
   - [Contexto e Memória](#contexto-e-memória)
   - [Ollama Server](#ollama-server-gpu--performance)
2. [Consumo de VRAM](#-consumo-de-vram-glm-47-flash)
3. [Presets por GPU](#-presets-prontos-por-gpu)
4. [Portas e Acesso](#-portas-e-acesso)
5. [Persistência](#-persistência-de-dados)
6. [Segurança](#-segurança)
7. [Troubleshooting](#-troubleshooting)

# =============================================================================
# Arquitetura: Quem Controla O Quê?
# =============================================================================

```
┌─────────────────────────────────────────────────────────────┐
│                     OLLAMA SERVER                            │
│  ENV VARS controlam o SERVIDOR:                              │
│  • OLLAMA_NUM_PARALLEL (requests simultâneos)                │
│  • OLLAMA_MAX_LOADED_MODELS (modelos na memória)             │
│  • OLLAMA_KV_CACHE_TYPE (tipo de cache)                      │
│  • OLLAMA_FLASH_ATTENTION (otimização GPU)                   │
│  • OLLAMA_CONTEXT_LENGTH (default se não especificado)       │
│  • OLLAMA_NUM_GPU (layers na GPU)                            │
│  • OLLAMA_MAX_QUEUE (fila de requests)                       │
│  • OLLAMA_DEBUG (nível de log)                               │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ API Request com params
                            │
┌─────────────────────────────────────────────────────────────┐
│                      OPENCLAW                                │
│  PARAMS são enviados na REQUEST:                             │
│  • temperature (criatividade)                                │
│  • top_p (nucleus sampling)                                  │
│  • repeat_penalty (repetição)                                │
│  • num_ctx (context window desta request)                    │
│  • think: true/false (modo reasoning)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Variáveis de Ambiente

### Configuração de Agentes

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OPENCLAW_WEB_PASSWORD` | **OBRIGATÓRIO** | 🔐 Senha de acesso aos dashboards |
| `OPENCLAW_NUM_AGENTS` | `3` | Número de agentes (1-10) |
| `OPENCLAW_AGENT_PREFIX` | `agent` | Prefixo do nome (ex: `agent_1`) |
| `OPENCLAW_BASE_PORT` | `18790` | Porta do primeiro agente |
| `OPENCLAW_MODEL` | `glm-4.7-flash:latest` | Modelo Ollama a usar |
| `OPENCLAW_MODEL_AUTO_PULL` | `true` | Baixar modelo automaticamente |
| `OPENCLAW_WARMUP_ENABLED` | `true` | Pré-carregar modelo na VRAM |

---

### Parâmetros do Modelo (Request API)

> ⚠️ **Importante:** Esses parâmetros são enviados pelo OpenClaw em cada request para o Ollama.

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OPENCLAW_TEMPERATURE` | `0.7` | Criatividade (0.0 = determinístico, 2.0 = muito criativo) |
| `OPENCLAW_TOP_P` | `0.95` | Nucleus sampling (0.0-1.0) |
| `OPENCLAW_REPEAT_PENALTY` | `1.0` | ⚠️ **CRÍTICO:** Manter em `1.0` para GLM-4.7! |
| `OPENCLAW_NUM_CTX` | `131072` | 📏 Context window (tokens). **Ajuste conforme sua GPU!** |
| `OPENCLAW_MAX_TOKENS` | `32768` | Máximo de tokens na resposta |

> 💡 **Dica:** `OPENCLAW_NUM_CTX` é o parâmetro mais importante para ajustar conforme sua GPU. Veja a [tabela de VRAM](#-consumo-de-vram-glm-47-flash).

---

### Thinking/Behavior do Agente

| Variável | Default | Opções | Descrição |
|----------|---------|--------|-----------|
| `OPENCLAW_THINKING_DEFAULT` | `on` | `on` / `off` | 🧠 Ativar raciocínio (reasoning) |
| `OPENCLAW_VERBOSE_DEFAULT` | `off` | `on` / `off` | Modo verbose |
| `OPENCLAW_ELEVATED_DEFAULT` | `on` | `on` / `off` | Permissões elevadas |

---

### Contexto e Memória

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OPENCLAW_CONTEXT_TOKENS` | `131072` | Limite de tokens do contexto da conversa |
| `OPENCLAW_TIMEOUT_SECONDS` | `600` | Timeout por request (10 min) |
| `OPENCLAW_MAX_CONCURRENT` | `3` | Requests simultâneos por agente |

---

### Context Pruning (Avançado)

> 🧹 Gerenciamento automático de memória quando o contexto fica muito grande.

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OPENCLAW_PRUNING_MODE` | `adaptive` | `adaptive` / `aggressive` / `off` |
| `OPENCLAW_KEEP_LAST_ASSISTANTS` | `3` | Quantas respostas recentes manter |
| `OPENCLAW_SOFT_TRIM_RATIO` | `0.3` | Ratio para trim suave (30%) |
| `OPENCLAW_HARD_CLEAR_RATIO` | `0.5` | Ratio para limpeza total (50%) |

---

### Ollama Server - GPU & Performance

> 🖥️ **Estas variáveis controlam o servidor Ollama**, não os parâmetros da request.

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OLLAMA_NUM_PARALLEL` | `4` | Requests paralelos simultâneos |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Tipo de cache: `q8_0` (economiza ~40% VRAM), `f16` (máx qualidade) |
| `OLLAMA_NUM_GPU` | `999` | Layers na GPU (999 = todas) |
| `OLLAMA_KEEP_ALIVE` | `-1` | Tempo modelo na VRAM (-1 = sempre) |
| `OLLAMA_FLASH_ATTENTION` | `1` | Flash Attention (+30-50% velocidade) |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Modelos simultâneos na memória |
| `OLLAMA_CONTEXT_LENGTH` | `131072` | Context length default do servidor |
| `OLLAMA_MAX_QUEUE` | `512` | Fila de requests antes de rejeitar |

---

### Ollama Server - Rede & Logs

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OLLAMA_HOST` | `0.0.0.0` | Interface de rede |
| `OLLAMA_PORT` | `11434` | Porta do servidor Ollama |
| `OLLAMA_DEBUG` | `false` | `false` / `1` (debug) / `2` (trace) |
| `LOG_LEVEL` | `info` | Nível de log geral |

---

## 📊 Consumo de VRAM (GLM-4.7-Flash)

> 📈 **O modelo GLM-4.7-Flash** usa ~17GB base + memória extra por context length.

| Context Length | VRAM Total | GPU Recomendada |
|----------------|------------|-----------------|
| **4K tokens** | ~17 GB | RTX 3090 |
| **8K tokens** | ~18 GB | RTX 3090/4090 |
| **16K tokens** | ~19 GB | RTX 3090/4090 |
| **32K tokens** | ~20 GB | RTX 3090/4090/A5000 |
| **65K tokens** | ~23 GB | RTX 4090/A5000 |
| **86K tokens** | ~25 GB | RTX 6000 Ada |
| **131K tokens** | ~30 GB | A6000/RTX 6000 Ada |
| **200K tokens** | ~48 GB | A6000/H100/H200 |

> 💡 **MLA (Multi-Latent Attention)** do GLM-4.7 economiza ~73% de VRAM no KV cache comparado a modelos tradicionais!

---

## 🎯 Presets Prontos por GPU

### RTX 3090 / RTX 4090 (24GB)

```env
OPENCLAW_NUM_CTX=65536
OPENCLAW_CONTEXT_TOKENS=65536
OLLAMA_CONTEXT_LENGTH=65536
OLLAMA_NUM_PARALLEL=2
```

### RTX A5000 (24GB)

```env
OPENCLAW_NUM_CTX=65536
OPENCLAW_CONTEXT_TOKENS=65536
OLLAMA_CONTEXT_LENGTH=65536
OLLAMA_NUM_PARALLEL=3
```

### RTX A6000 / RTX 6000 Ada (48GB)

```env
OPENCLAW_NUM_CTX=131072
OPENCLAW_CONTEXT_TOKENS=131072
OLLAMA_CONTEXT_LENGTH=131072
OLLAMA_NUM_PARALLEL=4
```

### H100 / H200 (80GB)

```env
OPENCLAW_NUM_CTX=200000
OPENCLAW_CONTEXT_TOKENS=200000
OLLAMA_CONTEXT_LENGTH=200000
OLLAMA_KV_CACHE_TYPE=f16
OLLAMA_NUM_PARALLEL=6
```

---

## 🌐 Portas e Acesso

| Porta | Serviço | Expor Pública? | Descrição |
|-------|---------|----------------|-----------|
| `18790` | Agente 1 | **SIM (Obrigatório)** | Dashboard Web do Agente 1 |
| `18791` | Agente 2 | **SIM (Obrigatório)** | Se `NUM_AGENTS >= 2` |
| `18792` | Agente 3 | **SIM (Obrigatório)** | Se `NUM_AGENTS >= 3` |
| `11434` | Ollama API | **NÃO (Opcional)** | Use apenas se precisar acessar a API direta (debug). O OpenClaw usa essa porta internamente via `localhost`. |

### Exemplo com 5 Agentes

```env
OPENCLAW_NUM_AGENTS=5
OPENCLAW_WEB_PASSWORD=minha_senha_segura
```

Resultado:
- `agent_1` → porta **18790** (Expor TCP Port)
- `agent_2` → porta **18791** (Expor TCP Port)
- ...
- `agent_5` → porta **18794** (Expor TCP Port)

---

## 💾 Persistência de Dados (Volume RunPod)

Para não perder suas memórias, conversas e modelos baixados ao reiniciar o pod, você **DEVE** configurar o Volume Path corretamente.

1. No Template do RunPod, configure **Volume Mount Path**: `/workspace`
2. Certifique-se de que seu Container Disk Size é suficiente (mínimo 50GB recomendado).

**O que é salvo em `/workspace`:**
```
/workspace/
├── .ollama/models/      # Modelos LLM baixados (evita download a cada restart)
├── agents/              # 🧠 CÉREBRO DOS AGENTES (Memórias, sessões, configs)
│   └── agent_1/
│       ├── .openclaw/   # Configurações locais do agente
│       └── workspace/   # Arquivos gerados pelo agente
├── logs/                # Histórico de logs para debug
└── .cache/              # Caches de sistema (npm, pip, cuda)
```

> ⚠️ **Atenção:** Se você não montar o volume em `/workspace`, todos os dados serão perdidos ao desligar o Pod!

### 💡 Dica Pro: RunPod Network Volumes (NFS)
Se você usa a **Secure Cloud**, recomendamos fortemente usar um **Network Volume**.
1. Crie um Network Volume na sua região.
2. Monte-o em `/workspace` no seu template.
3. **Benefício:** Você pode destruir o Pod, criar outro (até com GPU diferente), e **todas as suas memórias, agentes e histórico estarão lá intactos**. É a forma definitiva de persistência.

---

## 🔒 Segurança e Arquitetura de Isolamento

Para garantir que um agente não interfira nas memórias ou arquivos de outro, implementamos uma arquitetura de isolamento rigorosa:

### 1. 🧠 Memórias e Vector DB Isolados
Cada agente possui seu próprio banco de dados vetorial (LanceDB/Chroma) localizado em seu diretório privado.
- **Benefício:** O `Agent 1` (ex: Coder) nunca misturará conhecimento com o `Agent 2` (ex: Writer).
- **Caminho:** `/workspace/agents/agent_{N}/.openclaw/memory`

### 2. 📂 Workspaces Separados
Cada agente opera em um diretório de trabalho exclusivo (`CWD`).
- **Benefício:** Arquivos criados, código gerado e downloads ficam segregados.
- **Estrutura:**
  ```text
  /workspace/agents/
  ├── agent_1/ (Porta 18790) 🔒 Privado
  ├── agent_2/ (Porta 18791) 🔒 Privado
  └── ...
  ```

### 3. 🔑 Tokens de Autenticação Únicos
O sistema gera automaticamente um **Token de Serviço** único para cada agente na inicialização.
- Isso previne que scripts maliciosos em um agente controlem outro agente via API.
- Tokens salvos em: `/workspace/agents/agent_{N}/.openclaw/token`

---

## 🧱 Segurança

- ✅ **Senha obrigatória** - Sem fallback inseguro
- ✅ **Tokens únicos** - Cada agente tem seu token
- ✅ **Logs mascarados** - Senhas não aparecem nos logs
- ✅ **Trusted Proxies** - Configurados para redes internas
- ✅ **CORS automático** - Aceita conexões do RunPod Proxy
- ✅ **Auto-detecção RunPod** - Exibe URLs corretas de acesso

---

## 🐛 Troubleshooting

### Erro: "Out of memory"

Reduza o context:
```env
OPENCLAW_NUM_CTX=65536
OLLAMA_CONTEXT_LENGTH=65536
```

### Erro: "1008 origin not allowed"

Já corrigido automaticamente! Se persistir, verifique se está usando a imagem mais recente.

### Modelo não carrega

```env
OPENCLAW_MODEL_AUTO_PULL=true
OPENCLAW_WARMUP_ENABLED=true
```

### Performance lenta

```env
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KV_CACHE_TYPE=q8_0
OLLAMA_NUM_PARALLEL=2
```

---

## 📝 Logs

```bash
# Logs de um agente
tail -f /workspace/logs/agent_1.log

# Logs do Ollama
tail -f /workspace/logs/ollama.log

# Via supervisorctl
supervisorctl tail -f openclaw-agent_1
```

---

## 📜 Licença

MIT License - OpenClaw © 2024-2026

---

## 🔗 Links Úteis

- [Documentação OpenClaw](https://docs.openclaw.ai)
- [Documentação Ollama](https://ollama.com)
- [RunPod Templates](https://runpod.io/console/templates)
