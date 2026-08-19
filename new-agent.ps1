#Requires -Version 5.1
<#
.SYNOPSIS
    Cria o esqueleto completo de um novo agente da Agent Platform.
.DESCRIPTION
    Cria pasta, tools/, pyproject.toml (local), agent.yaml, tool de treino,
    teste manual e .gitignore; registra o agente no workspace raiz e roda
    uv sync. Todos os arquivos sao gravados SEM BOM.
.EXAMPLE
    .\new-agent.ps1 -Nome meu-novo-agente
.EXAMPLE
    .\new-agent.ps1 -Nome clima-agent -SkipSync
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Nome,

    [switch]$SkipSync
)

$ErrorActionPreference = "Stop"

# ---------- validacoes ----------
if ($Nome -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Host "[ERRO] Nome invalido: '$Nome'. Use kebab-case (ex: clima-agent)." -ForegroundColor Red
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot          # F:\ai-platform
$agentDir = Join-Path $root $Nome

if (Test-Path $agentDir) {
    Write-Host "[ERRO] Diretorio ja existe: $agentDir" -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "=== Criando agente: $Nome ===" -ForegroundColor Cyan

# ---------- passo 1: estrutura ----------
New-Item -ItemType Directory -Force -Path (Join-Path $agentDir "tools") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $agentDir "tests") | Out-Null
Write-Host "[OK] Estrutura criada (tools/, tests/)" -ForegroundColor Green

# ---------- tools/__init__.py ----------
Write-Utf8NoBom (Join-Path $agentDir "tools\__init__.py") @"
"""Ferramentas do $Nome."""
"@
Write-Host "[OK] tools/__init__.py" -ForegroundColor Green

# ---------- tools/minhas_tools.py (tool de treino) ----------
$toolsPy = @'
"""Ferramentas do agente."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from agent_sdk import ToolExecutionError, ToolResult, tool


@tool("hora_atual")
def hora_atual(fuso: str = "America/Sao_Paulo") -> ToolResult:
    """Retorna a data e hora atuais no fuso informado.

    Args:
        fuso: Nome do fuso horario (ex: America/Sao_Paulo).

    Returns:
        Dicionario com agora (ISO) e fuso.
    """
    try:
        agora = datetime.now(ZoneInfo(fuso))
        return ToolResult.ok({"agora": agora.isoformat(), "fuso": fuso})
    except Exception as exc:
        raise ToolExecutionError(f"Fuso invalido: {fuso} ({exc})", retry=False) from exc
'@
Write-Utf8NoBom (Join-Path $agentDir "tools\minhas_tools.py") $toolsPy
Write-Host "[OK] tools/minhas_tools.py (tool de treino: hora_atual)" -ForegroundColor Green

# ---------- test_manual.py ----------
$testPy = @'
from tools.minhas_tools import hora_atual

r = hora_atual()
print(r.sucesso, r.dados)
'@
Write-Utf8NoBom (Join-Path $agentDir "test_manual.py") $testPy
Write-Host "[OK] test_manual.py" -ForegroundColor Green

# ---------- pyproject.toml (versao LOCAL) ----------
$pyproject = @"
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$Nome"
version = "0.1.0"
description = "Descricao curta do agente $Nome."
readme = "README.md"
license = { text = "PolyForm-Noncommercial-1.0.0" }
requires-python = ">=3.11"
dependencies = [
    "agent-sdk",
]

[dependency-groups]
dev = ["pytest>=8.0", "pytest-mock>=3.14", "ruff>=0.5"]

[tool.hatch.build.targets.wheel]
packages = ["tools"]

[tool.ruff]
target-version = "py311"
line-length = 100
src = ["tools", "tests"]

[tool.ruff.lint]
select = ["E", "W", "F", "I", "N", "UP", "B", "SIM", "RUF"]
ignore = ["E501", "SIM117"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--strict-markers", "--tb=short", "-q"]
markers = ["integration: chama APIs reais"]

[tool.uv.sources]
agent-sdk = { workspace = true }
"@
Write-Utf8NoBom (Join-Path $agentDir "pyproject.toml") $pyproject
Write-Host "[OK] pyproject.toml (fonte local: workspace=true)" -ForegroundColor Green

# ---------- agent.yaml ----------
$yaml = @"
nome: "$Nome"
versao: "0.1.0"
modelo: "llama3.1:8b"
temperatura: 0.1
instrucoes: >
  Voce e um assistente prestativo.
  Use as ferramentas disponiveis antes de responder.
  NUNCA invente dados que as ferramentas podem obter.
  Responda em portugues, de forma concisa.
ferramentas:
  - hora_atual
tarefa:
  descricao: >
    Consulte a hora atual e responda que horas sao agora
    no fuso de Sao Paulo.
  saida_esperada: >
    Uma frase com a data e hora atuais.
max_passos: 5
timeout_segundos: 120
metadata:
  tags: ["exemplo"]
"@
Write-Utf8NoBom (Join-Path $agentDir "agent.yaml") $yaml
Write-Host "[OK] agent.yaml" -ForegroundColor Green

# ---------- .gitignore ----------
$gitignore = @'
__pycache__/
*.pyc
.venv/
token.json
client_secret.json
'@
Write-Utf8NoBom (Join-Path $agentDir ".gitignore") $gitignore
Write-Host "[OK] .gitignore" -ForegroundColor Green

# ---------- README.md ----------
$readme = @"
# $Nome

Agente em construcao para a Agent Platform.

## Status
- Esqueleto criado via ``new-agent.ps1``
- Tool de treino (``hora_atual``) funcional
- Proximo passo: implementar a tool real

## Uso
``````powershell
uv run python test_manual.py
uv run platform run $Nome/agent.yaml --verbose
Licenca
PolyForm Noncommercial License 1.0.0. Parte da Agent Platform.
``````
"@
Write-Utf8NoBom (Join-Path $agentDir "README.md") $readme
Write-Host "[OK] README.md" -ForegroundColor Green


# ---------- passo 3: registrar no workspace ----------
$rootPy = Join-Path $root "pyproject.toml"
$bytes = [System.IO.File]::ReadAllBytes($rootPy)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
}
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

if ($content -match "`"$Nome`"") {
    Write-Host "[i] '$Nome' ja esta no workspace raiz." -ForegroundColor Yellow
}
else {
    $lines = $content -split "`r?`n"
    $out = @()
    $inMembers = $false
    $inserted = $false
    foreach ($line in $lines) {
        if (-not $inMembers -and $line -match '^\s*members\s*=\s*\[') { $inMembers = $true }
        if ($inMembers -and -not $inserted -and $line -match '^\s*\]') {
            $out += "    `"$Nome`","
            $inserted = $true
            $inMembers = $false
        }
        $out += $line
    }
    if (-not $inserted) {
        Write-Host "[ERRO] Nao encontrei a lista members no pyproject raiz." -ForegroundColor Red
        exit 1
    }
    Write-Utf8NoBom $rootPy ($out -join "`n")
    Write-Host "[OK] Agente registrado no workspace raiz" -ForegroundColor Green
}

# ---------- uv sync ----------
if (-not $SkipSync) {
    Write-Host "[i] Rodando uv sync --group dev ..." -ForegroundColor Yellow
    Push-Location $root

    # uv escreve progresso em stderr; PS 5.1 + ErrorActionPreference=Stop
    # transformaria isso em erro fatal. Contornamos temporariamente.
    $pref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    uv sync --group dev 2>&1 | ForEach-Object { Write-Host "  $_" }
    $syncExit = $LASTEXITCODE
    $ErrorActionPreference = $pref

    Pop-Location
    if ($syncExit -ne 0) {
        Write-Host "[ERRO] uv sync falhou." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] uv sync concluido" -ForegroundColor Green
}

# ---------- proximos passos ----------
Write-Host ""
Write-Host "=== Esqueleto pronto! Proximos passos ===" -ForegroundColor Cyan
Write-Host "  cd $agentDir"
Write-Host "  uv run python test_manual.py"
Write-Host ""
Write-Host "  cd $root"
Write-Host "  uv run platform validate $Nome/agent.yaml"
Write-Host "  uv run platform tools list $Nome/agent.yaml"
Write-Host "  uv run platform run $Nome/agent.yaml --verbose"
Write-Host ""
Write-Host "Depois edite tools/minhas_tools.py e implemente o SEU agente." -ForegroundColor Yellow