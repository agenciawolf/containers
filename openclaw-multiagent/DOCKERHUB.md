# Docker Hub - Build e Push

## 🚀 Opção 1: Script Automático (Recomendado)

Criei o script `build-and-push.sh`:

```bash
# Dar permissão de execução
chmod +x build-and-push.sh

# Executar
./build-and-push.sh
```

O script faz tudo automaticamente: build, tag e push!

## 📦 Repositório Privado - SIM, TEM COMO!

### Criar Repositório Privado

1. Acesse: https://hub.docker.com
2. Clique em **"Create Repository"**
3. Nome: `openclaw-multiagent`
4. **Visibility: PRIVATE** 🔒
5. Clique em **"Create"

### Login no Docker Hub

```bash
docker login
# Digite seu username e password/token
```

### Build e Push (Privado)

```bash
# Build
docker build -t seuuser/openclaw-multiagent:latest .

# Push (vai para seu repo privado automaticamente)
docker push seuuser/openclaw-multiagent:latest
```

## 🔧 Configuração no RunPod (Imagem Privada)

### Opção A: Docker Hub Token (Recomendado)

1. No Docker Hub, vá em **Account Settings > Security > New Access Token**
2. Crie um token com permissão **"Read"**
3. No RunPod, ao criar o Pod, em **"Container Registry Auth"**:
   - **Username:** seu username do Docker Hub
   - **Password:** o token gerado

### Opção B: Imagem Pública Temporária

Se preferir, pode subir como pública temporariamente, fazer deploy, depois deletar:

```bash
# Mudar para público temporariamente
docker tag openclaw-multiagent seuuser/openclaw-multiagent:public-temp
docker push seuuser/openclaw-multiagent:public-temp

# Usar no RunPod: seuuser/openclaw-multiagent:public-temp
```

## 📝 Comandos Manuais (Sem Script)

```bash
# 1. Login
docker login

# 2. Build
docker build -t seuuser/openclaw-multiagent:latest .
docker build -t seuuser/openclaw-multiagent:v1.0 .

# 3. Push
docker push seuuser/openclaw-multiagent:latest
docker push seuuser/openclaw-multiagent:v1.0

# 4. Verificar
 docker pull seuuser/openclaw-multiagent:latest
```

## 💰 Docker Hub - Limites Gratuitos

| Tipo | Limite |
|------|--------|
| **Repositórios Privados** | 1 gratuito |
| **Pulls anônimos** | 100/6hrs |
| **Pulls autenticados** | 200/6hrs |

**Dica:** Se precisar de mais privados, considere:
- **GitHub Container Registry** (ghcr.io) - mais espaço gratuito
- **GitLab Registry** - ilimitado em projetos privados

## 🔄 Alternativa: GitHub Container Registry (ghcr.io)

Gratuito e ilimitado para projetos públicos:

```bash
# Build
docker build -t ghcr.io/seuuser/openclaw-multiagent:latest .

# Login (use token do GitHub)
docker login ghcr.io -u seuuser

# Push
docker push ghcr.io/seuuser/openclaw-multiagent:latest
```

No RunPod, use: `ghcr.io/seuuser/openclaw-multiagent:latest`

## ✅ Checklist para Deploy

- [ ] Criar conta Docker Hub (ou usar GitHub)
- [ ] Criar repositório (privado ou público)
- [ ] Fazer login: `docker login`
- [ ] Build: `docker build -t seuuser/openclaw-multiagent .`
- [ ] Push: `docker push seuuser/openclaw-multiagent`
- [ ] No RunPod, usar a imagem com auth se for privada

**Recomendação:** Use o script `build-and-push.sh`, ele faz tudo automaticamente!
