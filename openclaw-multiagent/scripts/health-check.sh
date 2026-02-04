#!/bin/bash
echo "[HEALTH] Verificando servicos..."
curl -s http://localhost:11434/api/tags > /dev/null && echo "✓ Ollama OK" || echo "✗ Ollama FAIL"
for port in 18790 18791 18792; do
  curl -s http://localhost:$port/health > /dev/null && echo "✓ Agente na porta $port OK" || echo "✗ Agente na porta $port FAIL"
done
