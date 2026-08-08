"""Ferramentas mock para teste."""

from agent_sdk import tool


@tool("echo_repetir")
def repetir(texto: str) -> str:
    """Repete o texto recebido."""
    return f"ECHO: {texto}"


@tool("math_somar")
def somar(a: int, b: int) -> int:
    """Soma dois números."""
    return a + b