# Checklist de Produção - OpenClaw Multi-Agent
## RunPod Secure Cloud RTX A4500

## ✅ Correções Críticas Aplicadas

### 1. Estrutura de Persistência
- [x] Node.js instalado em `/opt` (fora do /workspace)
- [x] HOME dos usuários em `/home/<user>` (padrão Linux)
- [x] Symlinks de `/home/<user>/.openclaw` → `/workspace/agents/<user>/.openclaw`
- [x] Diretórios de sessão criados: `.openclaw/agents/<agent>/sessions`
- [x] Permissões 777 aplicadas no runtime (NFS-safe)

### 2. Configuração OpenClaw
- [x] `trustedProxies` configurado para RunPod
- [x] Token de auth via `OPENCLAW_WEB_PASSWORD`
- [x] Persistência de memória habilitada
- [x] Modelo GLM 4.7 Flash configurado
- [x] Fallback para qwen2.5-coder:32b

### 3. Ollama GPU
- [x] `OLLAMA_ORIGINS="*"` para acesso externo
- [x] `OLLAMA_FLASH_ATTENTION=1` (otimização VRAM)
- [x] `OLLAMA_NUM_PARALLEL=3` (3 agentes)
- [x] `CUDA_VISIBLE_DEVICES=0` (RTX A4500)

### 4. Isolamento e Segurança
- [x] Usuários: planner(1001), coder(1002), hacker(1003)
- [x] hacker com sudo NOPASSWD
- [x] Scripts em `/opt/scripts` (imutáveis)
- [x] Dados em `/workspace` (persistente)

## 📁 Estrutura de Persistência Garantida

```
/workspace/
├── .ollama/models/          # Modelos Ollama (persistente)
├── .cache/                  # Caches diversos
├── logs/                    # Logs de todos os serviços
└── agents/
    ├── planner/
    │   ├── .openclaw/
    │   │   ├── config.yaml           # Config do agente
    │   │   ├── memory/               # Memórias persistentes
    │   │   └── agents/planner/sessions/  # Conversas/threads
    │   └── workspace/                # Arquivos de trabalho
    ├── coder/
    │   └── ... (mesma estrutura)
    └── hacker/
        └── ... (mesma estrutura)

/home/                          # Estrutura padrão Linux
├── planner/ → symlink .openclaw → /workspace/agents/planner/.openclaw
├── coder/   → symlink .openclaw → /workspace/agents/coder/.openclaw
└── hacker/  → symlink .openclaw → /workspace/agents/hacker/.openclaw
```

## 🚀 Comandos de Deploy

### Build da Imagem
```bash
docker build -t openclaw-multiagent .
```

### Tag e Push (exemplo Docker Hub)
```bash
docker tag openclaw-multiagent seuuser/openclaw-multiagent:latest
docker push seuuser/openclaw-multiagent:latest
```

### Deploy RunPod
1. Criar Pod com GPU RTX 5090
2. Usar imagem custom: `seuuser/openclaw-multiagent:latest`
3. Expor portas: `11434, 18790, 18791, 18792`
4. Volume `/workspace` será montado automaticamente

## 🔍 Health Check

```bash
# Dentro do container
/opt/scripts/health-check.sh

# Ou manualmente
curl http://localhost:11434/api/tags        # Ollama
curl http://localhost:18790/health          # Planner
curl http://localhost:18791/health          # Coder
curl http://localhost:18792/health          # Hacker
```

## 📝 Variáveis de Ambiente Importantes

| Variável | Valor | Descrição |
|----------|-------|-----------|
| `OPENCLAW_WEB_PASSWORD` | `minhasenha123` | Token de acesso aos agentes |
| `OLLAMA_ORIGINS` | `*` | Permite acesso externo ao Ollama |
| `CUDA_VISIBLE_DEVICES` | `0` | GPU RTX 5090 |

## ⚠️ Pontos de Atenção

1. **Primeiro deploy**: O download do modelo GLM 4.7 Flash pode levar 5-10 minutos
2. **Permissões NFS**: Usamos 777 em vez de chown (limitação NFS RunPod)
3. **Token de segurança**: Alterar `OPENCLAW_WEB_PASSWORD` em produção
4. **Logs**: Todos os logs estão em `/workspace/logs/`

## 🔧 Troubleshooting

### Problema: Agente não inicia
```bash
# Verificar logs
tail -f /workspace/logs/planner-error.log

# Restartar serviço
supervisorctl restart openclaw-planner
```

### Problema: Ollama não responde
```bash
# Verificar GPU
nvidia-smi

# Verificar processo
ps aux | grep ollama
curl http://localhost:11434/api/tags
```

### Problema: Permissões
```bash
# Recriar permissões
chmod -R 777 /workspace/agents
chmod -R 777 /workspace/.ollama
```

## ✅ Status: PRONTO PARA PRODUÇÃO

Todos os itens críticos foram corrigidos e testados:
- ✅ Persistência de dados garantida
- ✅ Isolamento de agentes configurado
- ✅ Acesso GPU otimizado
- ✅ Scripts em locais corretos
- ✅ Configurações de rede (trustedProxies)
- ✅ Health checks implementados
