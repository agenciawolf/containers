# OpenClaw Multi-Agent para RunPod Secure Cloud RTX A4500

Infraestrutura completa para executar 3 agentes OpenClaw isolados com Ollama GPU nativo no RunPod Secure Cloud.

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
Usar imagem custom com GPU RTX A4500, expor portas 11434,18790-18792.
