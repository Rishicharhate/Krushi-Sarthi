"""Single place that constructs the LLM every agent node uses. Groq via
langchain-groq — fast inference, usable free tier. If GROQ_MODEL in .env
stops resolving (Groq's hosted-model lineup changes over time), check
console.groq.com/docs/models and update it there; nothing else needs to change.
"""
from functools import lru_cache

from langchain_groq import ChatGroq

from app.core.config import get_settings


@lru_cache
def get_llm() -> ChatGroq:
    settings = get_settings()
    if not settings.groq_api_key:
        raise RuntimeError(
            "GROQ_API_KEY is not set. Add it to backend/.env (see .env.example) "
            "— get a free key at console.groq.com."
        )
    return ChatGroq(model=settings.groq_model, api_key=settings.groq_api_key, temperature=0.2)
