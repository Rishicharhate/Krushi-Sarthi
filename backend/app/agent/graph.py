"""Builds and compiles the farm advisory LangGraph. See state.py for the
schema and docs/IMPLEMENTATION_PLAN.md §3 for the design this follows,
scoped to the 3 specialists with real data behind them today:

    START --> weather  --\\
          --> soil      ---> synthesis --> writer --> safety_gate --> END
          --> disease   --/

weather/soil/disease run in parallel (LangGraph's fan-out) and their
`findings` merge via the additive reducer in state.py; synthesis/writer are
the only two LLM calls per question. A SQLite checkpointer persists state per
(user, farm) thread — same zero-infrastructure philosophy as the rest of this
backend (see app/core/config.py's database_url comment); swap for Postgres
if this ever needs to survive concurrent production load.
"""
from pathlib import Path

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.graph import END, START, StateGraph

from app.agent import nodes
from app.agent.state import FarmState

_DB_PATH = Path(__file__).resolve().parents[2] / "agent_checkpoints.db"

_checkpointer_cm = None
_compiled = None


def _build() -> StateGraph:
    builder = StateGraph(FarmState)
    builder.add_node("weather", nodes.weather_node)
    builder.add_node("soil", nodes.soil_node)
    builder.add_node("disease", nodes.disease_node)
    builder.add_node("synthesis", nodes.synthesis_node)
    builder.add_node("writer", nodes.writer_node)
    builder.add_node("safety_gate", nodes.safety_gate_node)

    builder.add_edge(START, "weather")
    builder.add_edge(START, "soil")
    builder.add_edge(START, "disease")
    builder.add_edge(["weather", "soil", "disease"], "synthesis")
    builder.add_edge("synthesis", "writer")
    builder.add_edge("writer", "safety_gate")
    builder.add_edge("safety_gate", END)
    return builder


async def init_agent() -> None:
    """Called once from main.py's startup event. Opens the checkpointer's
    connection for the lifetime of the process — see shutdown_agent()."""
    global _checkpointer_cm, _compiled
    _checkpointer_cm = AsyncSqliteSaver.from_conn_string(str(_DB_PATH))
    saver = await _checkpointer_cm.__aenter__()
    _compiled = _build().compile(checkpointer=saver)


async def shutdown_agent() -> None:
    global _checkpointer_cm, _compiled
    if _checkpointer_cm is not None:
        await _checkpointer_cm.__aexit__(None, None, None)
        _checkpointer_cm = None
    _compiled = None


def get_graph():
    if _compiled is None:
        raise RuntimeError("Agent not initialized — init_agent() must run at app startup.")
    return _compiled
