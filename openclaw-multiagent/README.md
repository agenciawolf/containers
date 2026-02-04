# OpenClaw Multi-Agent Infrastructure
## RunPod Secure Cloud - RTX 5090

Arquitetura Ollama (GLM 4.7 Flash) + 3 Agentes OpenClaw isolados.

### Estrutura
- Ollama: http://localhost:11434 (GPU nativa)
- Planner: http://localhost:18790 (arquitetura/planejamento)
- Coder: http://localhost:18791 (desenvolvimento)
- Hacker: http://localhost:18792 (segurança/ferramentas Linux)

### Persistência
Tudo em /workspace (volume NFS RunPod).

### Build
docker build -t openclaw-multiagent .

### Deploy RunPod
Usar imagem custom com GPU RTX 5090, expor portas 11434,18790-18792.
