# 🔑 Guia de Acesso: OpenClaw no RunPod

Este container foi configurado para **máxima facilidade de acesso** utilizando o Proxy Seguro do RunPod. Ao contrário da instalação local padrão (que gera tokens aleatórios), aqui usamos uma **Senha Mestra Fixa**.

## 🚀 Como Acessar

O OpenClaw Dashboard (Control UI) está habilitado em cada agente.

### 1. URLs de Acesso (RunPod Proxy)

O padrão de URL no RunPod é:
`https://<POD_ID>-<PORTA>.proxy.runpod.net/`

Assumindo a configuração padrão (`OPENCLAW_BASE_PORT=18790`):

| Agente | Porta | URL Estimada |
| :--- | :--- | :--- |
| **Agent 1** (Planner) | `18790` | `https://<SEU_POD_ID>-18790.proxy.runpod.net/` |
| **Agent 2** (Manager) | `18791` | `https://<SEU_POD_ID>-18791.proxy.runpod.net/` |
| **Agent 3** (Worker) | `18792` | `https://<SEU_POD_ID>-18792.proxy.runpod.net/` |
| ... | ... | ... |

*(Substitua `<SEU_POD_ID>` pelo ID do seu Pod, ex: `v2p4j8...`)*

### 2. Autenticação (Login)

Mudamos o método de "Token Aleatório" para **Senha Fixa** para você não precisar caçar logs a cada restart.

*   **Método:** Senha (Password)
*   **Senha:** O valor que você definiu na variável de ambiente `OPENCLAW_WEB_PASSWORD`.

> 💡 **Dica:** Ao acessar o dashboard pela primeira vez, se solicitado, selecione "Password" e digite sua senha.

## ❓ Perguntas Comuns

### "Ainda posso usar Token?"
O sistema foi forçado para `auth.mode = "password"` no `entrypoint.sh` para garantir que a variável de ambiente funcione. Se você tentar usar um token gerado manualmente, ele pode não ser aceito dependendo da precedência, mas a senha é garantida.

### "Tela Branca ou Erro de Conexão?"
1.  Certifique-se de usar `https://` (o RunPod Proxy exige SSL).
2.  Se o Dashboard não carregar, verifique se o container já terminou o "Warmup" (pode levar 1-2 min na primeira vez baixando modelos).
3.  Verifique os logs no RunPod para garantir que o serviço subiu: `Conectado na porta 18790`.

### "Onde está o Swagger/Docs da API?"
O OpenClaw não expõe Swagger por padrão na mesma porta, mas o Dashboard serve como cliente principal.
