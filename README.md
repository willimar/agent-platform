# Agent Platform

Plataforma genérica de execução de agentes de IA. Recebe definições
declarativas de agentes (`agent.yaml`), conecta a um LLM (Ollama) e
executa um loop de raciocínio-ação com ferramentas plugáveis.

A plataforma **não conhece** nenhum agente específico. Agentes são
plugáveis a qualquer momento, sem alterar o motor.

> **Status:** v0.1.0 — F0 (fundação) e F1 (motor MVP) concluídas.
> Primeiro agente real (Google Calendar) em desenvolvimento (F2).

---

## Como funciona

```
agent.yaml ──► Config Loader ──► Executor (loop) ──► LLM (Ollama)
                                     │
                                     ▼
                               Tool Registry ──► ferramentas @tool
```

1. **LOAD** — o `platform-core` lê e valida o `agent.yaml` (Pydantic).
2. **DISCOVERY** — as ferramentas declaradas são descobertas no diretório `tools/` do agente.
3. **LOOP** — o executor pergunta ao LLM o que fazer; o LLM responde em JSON:
   usar uma ferramenta ou finalizar.
4. **RESULT** — o estado final (`AgentState`) é apresentado com resultado,
   passos usados e duração.

Conceitos e decisões de design em
[`platform-docs/architecture.md`](platform-docs/architecture.md) e
[`platform-docs/decisions/adr-001-modelo-de-agentes.md`](platform-docs/decisions/adr-001-modelo-de-agentes.md).

---

## Estrutura do workspace

| Diretório | Tipo | Propósito |
|-----------|------|-----------|
| `platform-core/` | Pacote Python (membro) | Motor de execução, CLI, tool registry, clientes LLM |
| `agent-sdk/` | Pacote Python (membro) | Contrato: decorator `@tool`, tipos, template de agentes |
| `google-calendar-agent/` | Pacote Python (membro) | Agente: consulta a Google Calendar (F2) |
| `platform-docs/` | Documentação (não é pacote) | Arquitetura, specs, ADRs, guias, `setup.ps1` |
| `examples/` | Exemplos | `echo-agent` — agente de teste com ferramentas mock |

---

## Requisitos

- **Python 3.11+** (o `uv` gerencia automaticamente)
- **[uv](https://docs.astral.sh/uv/)** — gerenciador de pacotes e workspace
- **[Ollama](https://ollama.com)** rodando localmente (default: `http://localhost:11434`)

---

## Instalação

### Opção A — script de setup (recomendado)

```powershell
.\platform-docs\setup.ps1
```

### Opção B — manual

```powershell
# Na raiz do workspace
uv sync --group dev
```

Isso cria o `.venv` compartilhado na raiz e instala os três membros
com as dependências de desenvolvimento.

### Modelo de LLM

```powershell
ollama pull llama3.1:8b
```

> O modelo pode ser trocado por agente, no campo `modelo` do `agent.yaml`.

---

## Quick start

Execute o agente de exemplo (ferramentas mock, sem APIs externas):

```powershell
uv run platform run examples/echo-agent/agent.yaml --verbose
```

Saída esperada:

```
[OK] Agente carregado: Echo Agent v1.0.0
[OK] 2 ferramenta(s) carregada(s)

Executando agente...

────────────────────── Resultado Final ──────────────────────
{'repetido': 'Repita a mensagem do usuário e some 2+3.', 'resultado': 5}

Passos: 2 | Ferramentas usadas: 0 | Duração: 15.83s
```

---

## CLI

| Comando | Descrição |
|---------|-----------|
| `uv run platform run <agent.yaml> [-e "mensagem"] [-v]` | Executa um agente |
| `uv run platform validate <agent.yaml>` | Valida o YAML sem executar |
| `uv run platform tools list <agent.yaml>` | Lista ferramentas do agente |
| `uv run platform version` | Mostra a versão |

---

## Criando um novo agente

1. Crie um diretório `<nome>-agent/` com:

```
meu-agente/
├── agent.yaml          # definição declarativa (spec)
├── tools/
│   └── minhas_tools.py # funções decoradas com @tool
└── tests/
```

2. Defina o `agent.yaml` seguindo a
   [especificação](platform-docs/agent-spec.md):

```yaml
nome: "Meu Agente"
versao: "0.1.0"
modelo: "llama3.1:8b"
instrucoes: >
  Descrição do comportamento do agente.
ferramentas:
  - minha_ferramenta
tarefa:
  descricao: "O que o agente deve fazer."
  saida_esperada: "Como deve ser a resposta final."
max_passos: 5
```

3. Implemente as ferramentas seguindo o
   [contrato de ferramentas](platform-docs/tool-contract.md):

```python
from agent_sdk import tool

@tool("minha_ferramenta")
def minha_ferramenta(param: str) -> str:
    """Descrição que o LLM verá."""
    return f"resultado: {param}"
```

4. Execute:

```powershell
uv run platform run ./meu-agente/agent.yaml --verbose
```

---

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [`platform-docs/architecture.md`](platform-docs/architecture.md) | Visão geral, componentes, fluxo, decisões tecnológicas |
| [`platform-docs/agent-spec.md`](platform-docs/agent-spec.md) | Especificação completa do `agent.yaml` |
| [`platform-docs/tool-contract.md`](platform-docs/tool-contract.md) | Contrato de ferramentas (decorator, tipos, regras) |
| [`platform-docs/decisions/`](platform-docs/decisions/) | ADRs (decisões de arquitetura) |

---

## Desenvolvimento

```powershell
# Testes (por membro)
cd platform-core   && uv run pytest tests/ -v
cd agent-sdk       && uv run pytest tests/ -v

# Lint e formatação
uv run ruff check src/ tests/
uv run ruff format src/ tests/
```

Convenções de código, commits e branches: ver `platform-docs/` (CONTRIBUTING em elaboração).

---

## Roadmap

| Versão | Escopo | Status |
|--------|--------|--------|
| 0.1 | Loop funcional, CLI, Ollama, 1 agente mock | ✅ Concluída |
| 0.2 | Agente Google Calendar real, retry, logging estruturado | 🚧 Em andamento |
| 0.3 | Persistência de estado, human-in-the-loop | ⬜ Planejada |
| 0.4 | Execução assíncrona, paralelismo de ferramentas | ⬜ Planejada |
| 1.0 | API estável, documentação completa, marketplace de agentes | ⬜ Planejada |

---

## Licença

MIT
