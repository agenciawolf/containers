# Build e Push da Imagem OpenClaw Multi-Agent (PowerShell)
# Execute: .\build-and-push.ps1

$ErrorActionPreference = "Stop"

# Configurações
$DOCKER_USERNAME = if ($env:DOCKER_USERNAME) { $env:DOCKER_USERNAME } else { "agenciawolf" }
$IMAGE_NAME = "$DOCKER_USERNAME/openclaw-multiagent"
$TAG = if ($args[0]) { $args[0] } else { "1.1" }
$FULL_IMAGE = "$IMAGE_NAME`:$TAG"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Multi-Agent - Build & Push" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se está logado no Docker Hub
Write-Host "[1/5] Verificando login Docker Hub..." -ForegroundColor Yellow
try {
    # No PowerShell, verificamos se docker info contém informação de login
    $dockerInfo = docker info 2>&1 | Out-String
    $loggedIn = docker info --format "{{.ID}}" 2>$null
    
    # Tentativa alternativa: verificar se consegue pegar username
    $usernameCheck = docker info 2>&1 | Select-String -Pattern "Username|agenciawolf"
    
    if (-not $usernameCheck -and -not $loggedIn) {
        # Verificação final: tentar pegar dados do contexto
        $contextCheck = docker context ls 2>&1 | Out-String
        if ($contextCheck -match "default") {
            # Provavelmente está logado, continuar
            Write-Host "✅ Docker detectado" -ForegroundColor Green
        } else {
            Write-Host "❌ Você não está logado no Docker Hub" -ForegroundColor Red
            Write-Host ""
            Write-Host "Execute: docker login" -ForegroundColor Yellow
            Write-Host ""
            exit 1
        }
    } else {
        Write-Host "✅ Logado no Docker Hub (agenciawolf)" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Verificação de login falhou, mas tentando continuar..." -ForegroundColor Yellow
    Write-Host "Erro: $_" -ForegroundColor Gray
}

# Build da imagem
Write-Host ""
Write-Host "[2/5] Buildando imagem: $FULL_IMAGE" -ForegroundColor Yellow
Write-Host "Isso pode levar 10-15 minutos..." -ForegroundColor Gray

docker build -t "$FULL_IMAGE" .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build falhou com código: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build completo" -ForegroundColor Green

# Tag adicional como 1.1 (se não for 1.1)
if ($TAG -ne "1.1") {
    Write-Host ""
    Write-Host "[3/5] Criando tag '1.1' também..." -ForegroundColor Yellow
    docker tag "$FULL_IMAGE" "$IMAGE_NAME`:1.1"
    Write-Host "✅ Tag 1.1 criada" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[3/5] Pulando tag adicional (já é 1.1)" -ForegroundColor Gray
}

# Push da imagem
Write-Host ""
Write-Host "[4/5] Fazendo push para Docker Hub..." -ForegroundColor Yellow
Write-Host "Upload: $FULL_IMAGE" -ForegroundColor Gray
try {
    docker push "$FULL_IMAGE"
    
    if ($TAG -ne "1.1") {
        Write-Host "Upload: $IMAGE_NAME`:1.1" -ForegroundColor Gray
        docker push "$IMAGE_NAME`:1.1"
    }
    Write-Host "✅ Push completo" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro no push: $_" -ForegroundColor Red
    exit 1
}

# Resumo
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ IMAGEM PUBLICADA COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Imagem: $FULL_IMAGE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para usar no RunPod:" -ForegroundColor Yellow
Write-Host "1. Crie um novo Pod" -ForegroundColor White
Write-Host "2. Escolha 'Custom Image'" -ForegroundColor White
Write-Host "3. Cole: $FULL_IMAGE" -ForegroundColor White
Write-Host "4. Configure GPU RTX 5090" -ForegroundColor White
Write-Host "5. Exponha portas: 11434, 18790, 18791, 18792" -ForegroundColor White
Write-Host ""
Write-Host "Ou use diretamente via docker:" -ForegroundColor Yellow
Write-Host "docker run -d --gpus all -p 11434:11434 -p 18790:18790 -p 18791:18791 -p 18792:18792 $FULL_IMAGE" -ForegroundColor Gray
Write-Host ""
