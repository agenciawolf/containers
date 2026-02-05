# 📋 Checklist: Configuração do Template no RunPod

Para extrair o máximo poder do container `openclaw-multiagent` otimizado, configure seu **Pod Template** no painel da RunPod exatamente assim:

## 1. Container Image
*   **Image Name:** `blacktech/openclaw-multiagent:latest` (ou sua tag específica)
*   **Container Disk:** Pelo menos **20 GB** (recomendado 40GB+ para baixar múltiplos modelos LLM)
*   **Volume Disk:** Pelo menos **50 GB** (Este será montado em `/workspace`. É aqui que modelos e memórias viverão)
*   **Volume Mount Path:** `/workspace` (CRÍTICO: não mude isso, nosso script depende dessa estrutura)

## 2. Environment Variables (Variáveis de Ambiente)
Adicione estas chaves para ativar as otimizações e segurança:

| Key | Value (Exemplo) | Descrição |
| :--- | :--- | :--- |
| `OPENCLAW_WEB_PASSWORD` | `SuaSenhaForte123` | **Obrigatório**. Senha mestra para acessar os dashboards. |
| `OPENCLAW_NUM_AGENTS` | `3` | Número de agentes a iniciar (1 a 10). |
| `OPENCLAW_MODEL` | `glm-4.7-flash:latest` | Modelo LLM inicial (será baixado automaticamente). |
| `OLLAMA_KEEP_ALIVE` | `-1` | Mantém modelo na VRAM infinitamente (Máxima Performance). |
| `OLLAMA_NUM_GPU` | `1` | Defina conforme a quantidade de GPUs do seu Pod. |

## 3. Ports (Exposição de Portas)
Para acessar o Dashboard via Proxy, você deve expor as portas HTTP.
*   **Expose HTTP Ports:** `18790,18791,18792` (uma para cada agente que você planeja usar)
*   **Expose TCP Ports:** `11434` (Opcional, se quiser acesso direto à API do Ollama via TCP tunnel)

> **Nota:** O RunPod cria URLs públicas automáticas para portas HTTP expostas.
> Ex: `https://<POD_ID>-18790.proxy.runpod.net`

## 4. Docker Command
*   **Docker Command:** Deixe em branco (nosso `ENTRYPOINT` no Dockerfile cuida de tudo).

---

### ✅ Verificação Pós-Deploy
1.  Aguarde o status **Running**.
2.  Clique em **Logs** no painel do RunPod.
3.  Você deverá ver nossa mensagem customizada:
    ```text
    ☁️ Ambiente RunPod Detectado!
       Dashboard (Proxy): https://v2p4j8...-18790.proxy.runpod.net/
    ```
4.  Clique no link e faça login com sua `OPENCLAW_WEB_PASSWORD`.
