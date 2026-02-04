#!/bin/bash
set -euo pipefail
echo "[BUILD] Buildando imagem OpenClaw Multi-Agent..."
IMAGE_NAME="${1:-openclaw-multiagent}"
TAG="${2:-latest}"
docker build -t "${IMAGE_NAME}:${TAG}" .
echo "[BUILD] Imagem ${IMAGE_NAME}:${TAG} criada com sucesso"
