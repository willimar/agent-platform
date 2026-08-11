# agent-platform/setup.ps1
# Uso: .\setup.ps1
# Clona os repos irmãos (se necessário) e configura o workspace local.

$ErrorActionPreference = "Stop"

$repos = @{
    "platform-core"         = "https://github.com/willimar/platform-core.git"
    "agent-sdk"             = "https://github.com/willimar/agent-sdk.git"
    "platform-docs"         = "https://github.com/willimar/platform-docs.git"
    "google-calendar-agent" = "https://github.com/willimar/google-calendar-agent.git"
}

# 1. Clona repos irmãos ao lado (não dentro)
$root = Split-Path -Parent $PSScriptRoot
Write-Host "Diretorio raiz: $root"

foreach ($name in $repos.Keys) {
    $path = Join-Path $root $name
    if (-not (Test-Path $path)) {
        Write-Host "Clonando $name..."
        git clone $repos[$name] $path
    } else {
        Write-Host "$name ja existe."
    }
}

# 2. Cria pyproject.toml de workspace na raiz (para desenvolvimento)
$workspaceToml = Join-Path $root "pyproject.toml"
@"
[tool.uv.workspace]
members = [
    "agent-sdk",
    "platform-core",
    "google-calendar-agent",
]
"@ | Set-Content -Path $workspaceToml -Encoding UTF8

# 3. Para cada repo consumidor, injeta [tool.uv.sources] apontando pro path local
function Add-LocalSource($repoPath) {
    $pyproject = Join-Path $repoPath "pyproject.toml"
    $content = Get-Content $pyproject -Raw
    
    # Remove qualquer [tool.uv.sources] existente
    $content = $content -replace '(?s)\[tool\.uv\.sources\][^\[]*', ''
    
    # Adiciona a fonte local
    $content = $content.TrimEnd() + "`n`n[tool.uv.sources]`nagent-sdk = { path = `"../agent-sdk`", editable = true }`n"
    
    Set-Content -Path $pyproject -Value $content -Encoding UTF8
}

Add-LocalSource (Join-Path $root "platform-core")
Add-LocalSource (Join-Path $root "google-calendar-agent")

# 4. Sync do workspace
Write-Host "Sincronizando workspace..."
Push-Location $root
uv sync --group dev
Pop-Location

Write-Host "Setup completo."