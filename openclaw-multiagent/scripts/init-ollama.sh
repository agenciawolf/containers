#!/bin/bash
set -euo pipefail
echo "[INIT] Aguardando Ollama..."
for i in {1..60}; do
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then break; fi
  sleep 1
done
echo "[INIT] Ollama pronto!"
exec "$@"
