# Hardening e Análise de Riscos - OpenClaw Multi-Agent

## RISCOS IDENTIFICADOS

### 1. Risco: Agente Hacker com Acesso Total
**Nível:** Alto
**Descrição:** O agente hacker tem sudo NOPASSWD para executar qualquer comando.
**Mitigação:**
- Isolamento por usuário Linux (UID 1003)
- Restrito ao diretório /workspace/agents/hacker
- Logs auditáveis em /workspace/logs/hacker.log
- Sem acesso a dados de outros agentes

### 2. Risco: Exposição de APIs
**Nível:** Médio
**Descrição:** Portas 11434, 18790-18792 expostas podem ser acessadas externamente.
**Mitigação:**
- Tokens de autenticação por agente
- RunPod Secure Cloud isola rede por padrão
- Considerar VPN/WireGuard para acesso remoto

### 3. Risco: Consumo Excessivo de GPU
**Nível:** Médio
**Descrição:** 3 agentes simultâneos podem sobrecarregar RTX 5090.
**Mitigação:**
- OLLAMA_NUM_PARALLEL=3 limita concorrência
- OLLAMA_MAX_LOADED_MODELS=1 (um modelo na VRAM)
- Flash Attention otimiza uso de memória
- Monitoramento via nvidia-smi

### 4. Risco: Persistência de Dados Sensíveis
**Nível:** Médio
**Descrição:** Dados em /workspace persistem no NFS.
**Mitigação:**
- Criptografia em repouso (responsabilidade RunPod)
- Rotatividade de tokens regulares
- Não armazenar credenciais em código

## HARDENING IMPLEMENTADO

### Isolamento de Processos
- Supervisord gerencia reinício automático
- Cada agente roda como usuário dedicado
- Separação de diretórios home

### Controle de Recursos
- Limites de memória via cgroups (adicionar)
- Prioridade de CPU ajustável
- Monitoramento de logs centralizado

### Segurança de Rede
- Tokens únicos por agente gerados no setup
- Binding em 0.0.0.0 apenas dentro do container
- Sem exposição de portas sensíveis

## RECOMENDAÇÕES ADICIONAIS

1. **VPN:** Configurar WireGuard para acesso seguro
2. **Backup:** Snapshot diário do /workspace
3. **Alertas:** Notificações se agente parar de responder
4. **Rotation:** Trocar tokens a cada 30 dias
5. **Audit:** Log de todos comandos executados pelo hacker
