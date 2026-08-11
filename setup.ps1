# agent-platform/setup.ps1
# Uso: .\setup.ps1

$repos = @{
    "platform-core"         = "https://github.com/willimar/platform-core.git"
    "agent-sdk"             = "https://github.com/willimar/agent-sdk.git"
    "platform-docs"         = "https://github.com/willimar/platform-docs.git"
    "google-calendar-agent" = "https://github.com/willimar/google-calendar-agent.git"
}

$root = Split-Path -Parent $PSScriptRoot
Write-Host "Diretorio raiz: $root"

# 1. Clona repos irmãos
foreach ($name in $repos.Keys) {
    $path = Join-Path $root $name
    if (-not (Test-Path $path)) {
        Write-Host "Clonando $name..." -ForegroundColor Cyan
        $null = git clone $repos[$name] $path 2>&1
        if (-not (Test-Path $path)) {
            Write-Host "FALHA ao clonar $name" -ForegroundColor Red
            exit 1
        }
        Write-Host "$name clonado com sucesso." -ForegroundColor Green
    } else {
        Write-Host "$name ja existe." -ForegroundColor Yellow
    }
}

# 2. Cria pyproject.toml de workspace na raiz (sem BOM)
$workspaceToml = Join-Path $root "pyproject.toml"
$workspaceContent = @"
[tool.uv.workspace]
members = [
    "agent-sdk",
    "platform-core",
    "google-calendar-agent",
]
"@
[System.IO.File]::WriteAllText($workspaceToml, $workspaceContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "Workspace criado em $workspaceToml" -ForegroundColor Green

# 3. Adiciona agent-sdk nas dependências e sources com workspace = true
function Add-WorkspaceSource($repoPath) {
    $pyproject = Join-Path $repoPath "pyproject.toml"
    if (-not (Test-Path $pyproject)) {
        Write-Host "pyproject.toml nao encontrado em $repoPath" -ForegroundColor Red
        return
    }
    
    # Lê o arquivo removendo BOM se existir
    $bytes = [System.IO.File]::ReadAllBytes($pyproject)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    
    # Remove qualquer [tool.uv.sources] existente (com regex multi-linha)
    $content = $content -replace '(?s)\[tool\.uv\.sources\]\s*\r?\n(?:[^\[]*?\r?\n)*?(?=\r?\n\[|\z)', ''
    
    # Adiciona agent-sdk nas dependências se não existir
    if ($content -notmatch '"agent-sdk"') {
        $content = $content -replace '(dependencies\s*=\s*\[)([^\]]*)', '$1$2  "agent-sdk",'
    }
    
    # Adiciona [tool.uv.sources] com workspace = true
    $content = $content.TrimEnd() + "`n`n[tool.uv.sources]`nagent-sdk = { workspace = true }`n"
    
    # Escreve SEM BOM
    [System.IO.File]::WriteAllText($pyproject, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Sources de workspace injetadas em $pyproject" -ForegroundColor Green
}

Add-WorkspaceSource (Join-Path $root "platform-core")
Add-WorkspaceSource (Join-Path $root "google-calendar-agent")

# 4. Sync do workspace
Write-Host "`nSincronizando workspace..." -ForegroundColor Cyan
Push-Location $root
uv sync --group dev
Pop-Location

Write-Host "`nSetup completo!" -ForegroundColor Green