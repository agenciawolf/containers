# OpenClaw Multi-Agent Container 🤖

Container Docker otimizado para rodar múltiplos agentes OpenClaw com Ollama em GPUs NVIDIA, especialmente configurado para **RunPod Secure Cloud**.

## 🚀 Quick Start

```bash
docker run -d --gpus all \
  -p 18790:18790 \
  -e OPENCLAW_WEB_PASSWORD=sua_senha_forte \
  danielblack/openclaw-multiagent:latest
```

## ⚙️ Variáveis de Ambiente

### Configuração de Agentes

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OPENCLAW_NUM_AGENTS` | `3` | Número de agentes (1-10) |
| `OPENCLAW_AGENT_PREFIX` | `agent` | Prefixo do nome (ex: `agent_1`) |
| `OPENCLAW_BASE_PORT` | `18790` | Porta do primeiro agente |
| `OPENCLAW_WEB_PASSWORD` | **obrigatório** | Senha de acesso |
| `OPENCLAW_MODEL` | `glm-4.7-flash:latest` | Modelo Ollama |
| `OPENCLAW_MODEL_AUTO_PULL` | `true` | Baixar modelo se não existir |
| `OPENCLAW_WARMUP_ENABLED` | `true` | Pré-carregar modelo na VRAM |

### Performance GPU

| Variável | Default | Descrição |
|----------|---------|-----------|
| `OLLAMA_NUM_PARALLEL` | `4` | Requisições simultâneas |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Cache quantizado (~40% menos VRAM) |
| `OLLAMA_FLASH_ATTENTION` | `1` | Ativar Flash Attention |
| `OLLAMA_KEEP_ALIVE` | `-1` | Manter modelo na VRAM |
| `OLLAMA_CONTEXT_LENGTH` | `32768` | Tamanho do contexto |

## 📊 Recomendações de GPU

| GPU VRAM | Modelo Recomendado | Max Agentes | OLLAMA_NUM_PARALLEL |
|----------|-------------------|-------------|---------------------|
| **8 GB** | llama3.1:8b-q4 | 1-2 | 1 |
| **12 GB** | glm-4.7-flash | 2-3 | 2 |
| **16 GB** | glm-4.7-flash | 3-5 | 3 |
| **24 GB** | glm-4.7-flash | 5-10 | 4 |
| **48 GB+** | llama3.1:70b | 10+ | 6 |

> **Nota:** O modelo é carregado **uma única vez** e compartilhado entre todos os agentes. O consumo de VRAM escala com `OLLAMA_NUM_PARALLEL`, não com o número de agentes.

## 🔧 Configuração RunPod

### Variáveis de Ambiente Obrigatórias

```
OPENCLAW_WEB_PASSWORD=sua_senha_forte
```

### Portas a Expor

```
18790 (HTTP) - Agente 1
18791 (HTTP) - Agente 2 (se NUM_AGENTS >= 2)
18792 (HTTP) - Agente 3 (se NUM_AGENTS >= 3)
...
11434 (opcional) - Ollama API direta
```

### Exemplo com 5 Agentes

```
OPENCLAW_NUM_AGENTS=5
OPENCLAW_WEB_PASSWORD=minha_senha_ultra_segura
OLLAMA_NUM_PARALLEL=3
```

Isso criará:
- `agent_1` na porta **18790**
- `agent_2` na porta **18791**
- `agent_3` na porta **18792**
- `agent_4` na porta **18793**
- `agent_5` na porta **18794**

## 💾 Persistência

Dados persistem em `/workspace` (RunPod NFS):

```
/workspace/
├── .ollama/models/      # Modelos Ollama
├── agents/              # Configs e dados de cada agente
│   └── agent_1/
│       ├── .openclaw/   # Config e memória do agente
│       └── workspace/   # Diretório de trabalho
├── logs/                # Logs de todos os serviços
└── .supervisor/         # Configs dinâmicas do supervisor
```

## 🔒 Segurança

- **Senha obrigatória**: Não há fallback inseguro
- **Tokens únicos**: Cada agente tem seu token de autenticação
- **Logs mascarados**: Tokens e senhas não aparecem nos logs
- **Trusted Proxies**: Configurados para redes internas

## 📝 Logs

```bash
# Ver logs de um agente
tail -f /workspace/logs/agent_1.log

# Ver logs do Ollama
tail -f /workspace/logs/ollama.log

# Via supervisorctl
supervisorctl -c /etc/supervisor/conf.d/supervisord.conf tail -f openclaw-agent_1
```

## 🐳 Build Local

```bash
docker build -t openclaw-multiagent .
docker run -d --gpus all \
  -v $(pwd)/workspace:/workspace \
  -p 18790-18800:18790-18800 \
  -e OPENCLAW_WEB_PASSWORD=teste123 \
  -e OPENCLAW_NUM_AGENTS=3 \
  openclaw-multiagent
```

## 📜 Licença

MIT License - OpenClaw © 2024
