#!/bin/bash
# Script para build e push da imagem OpenClaw Multi-Agent

set -euo pipefail

# Configurações
IMAGE_NAME="${DOCKER_USERNAME:-seuuser}/openclaw-multiagent"
TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

echo "========================================"
echo "OpenClaw Multi-Agent - Build & Push"
echo "========================================"
echo ""

# Verificar se está logado no Docker Hub
echo "[1/5] Verificando login Docker Hub..."
if ! docker info | grep -q "Username"; then
    echo "❌ Você não está logado no Docker Hub"
    echo ""
    echo "Execute: docker login"
    echo ""
    exit 1
fi
echo "✅ Logado no Docker Hub"

# Build da imagem
echo ""
echo "[2/5] Buildando imagem: ${FULL_IMAGE}"
echo "Isso pode levar 10-15 minutos..."
docker build -t "${FULL_IMAGE}" .
echo "✅ Build completo"

# Tag adicional como latest (se não for latest)
if [ "${TAG}" != "latest" ]; then
    echo ""
    echo "[3/5] Criando tag 'latest' também..."
    docker tag "${FULL_IMAGE}" "${IMAGE_NAME}:latest"
    echo "✅ Tag latest criada"
else
    echo ""
    echo "[3/5] Pulando tag adicional (já é latest)"
fi

# Push da imagem
echo ""
echo "[4/5] Fazendo push para Docker Hub..."
echo "Upload: ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

if [ "${TAG}" != "latest" ]; then
    echo "Upload: ${IMAGE_NAME}:latest"
    docker push "${IMAGE_NAME}:latest"
fi
echo "✅ Push completo"

# Resumo
echo ""
echo "========================================"
echo "✅ IMAGEM PUBLICADA COM SUCESSO!"
echo "========================================"
echo ""
echo "Imagem: ${FULL_IMAGE}"
echo ""
echo "Para usar no RunPod:"
echo "1. Crie um novo Pod"
echo "2. Escolha 'Custom Image'"
echo "3. Cole: ${FULL_IMAGE}"
echo "4. Configure GPU RTX 5090"
echo "5. Exponha portas: 11434, 18790, 18791, 18792"
echo ""
echo "Ou use diretamente via docker:"
echo "docker run -d --gpus all -p 11434:11434 -p 18790:18790 -p 18791:18791 -p 18792:18792 ${FULL_IMAGE}"
echo ""
