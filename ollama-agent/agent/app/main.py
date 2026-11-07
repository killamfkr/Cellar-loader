from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .agent import run_agent_turn, store, stream_agent_turn
from .config import settings
from .ollama_client import OllamaClient

app = FastAPI(title="Ollama Cursor Agent", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str
    session_id: str | None = None
    model: str | None = None
    title: str | None = None


class PullRequest(BaseModel):
    model: str


@app.get("/api/health")
async def health() -> dict[str, Any]:
    ollama = OllamaClient()
    try:
        models = await ollama.list_models()
        return {"ok": True, "ollama": True, "models": models}
    except Exception as e:
        return {"ok": False, "ollama": False, "error": str(e)}


@app.get("/api/config")
async def get_config() -> dict[str, Any]:
    return {
        "default_model": settings.default_model,
        "workspace_root": settings.workspace_root,
        "max_agent_steps": settings.max_agent_steps,
    }


@app.get("/api/models")
async def list_models() -> dict[str, Any]:
    ollama = OllamaClient()
    try:
        return {"models": await ollama.list_models()}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e)) from e


@app.post("/api/models/pull")
async def pull_model(body: PullRequest) -> StreamingResponse:
    ollama = OllamaClient()

    async def gen():
        try:
            async for chunk in ollama.pull_model(body.model):
                yield json.dumps(chunk) + "\n"
        except Exception as e:
            yield json.dumps({"error": str(e)}) + "\n"

    return StreamingResponse(gen(), media_type="application/x-ndjson")


@app.get("/api/sessions")
async def list_sessions() -> dict[str, Any]:
    return {
        "sessions": [
            {
                "id": s.id,
                "title": s.title,
                "model": s.model,
                "message_count": len(s.messages),
            }
            for s in store.sessions.values()
        ]
    }


@app.get("/api/sessions/{session_id}")
async def get_session(session_id: str) -> dict[str, Any]:
    session = store.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return {
        "id": session.id,
        "title": session.title,
        "model": session.model,
        "messages": session.messages,
        "events": [
            {"type": e.type, "data": e.data, "ts": e.ts} for e in session.events
        ],
    }


@app.post("/api/chat")
async def chat(req: ChatRequest) -> dict[str, Any]:
    model = req.model or settings.default_model
    if req.session_id:
        session = store.get(req.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
    else:
        title = req.title or (req.message[:60] + ("…" if len(req.message) > 60 else ""))
        session = store.create(model=model, title=title)

    reply = await run_agent_turn(session, req.message)
    return {
        "session_id": session.id,
        "reply": reply,
        "events": [
            {"type": e.type, "data": e.data, "ts": e.ts} for e in session.events[-50:]
        ],
    }


@app.post("/api/chat/stream")
async def chat_stream(req: ChatRequest) -> StreamingResponse:
    model = req.model or settings.default_model
    if req.session_id:
        session = store.get(req.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
    else:
        title = req.title or (req.message[:60] + ("…" if len(req.message) > 60 else ""))
        session = store.create(model=model, title=title)

    async def event_stream():
        meta = {"type": "session", "session_id": session.id, "model": session.model}
        yield f"data: {json.dumps(meta)}\n\n"
        async for ev in stream_agent_turn(session, req.message):
            payload = {"type": ev.type, "data": ev.data, "ts": ev.ts}
            yield f"data: {json.dumps(payload)}\n\n"
        yield "data: {\"type\": \"done\"}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
if not STATIC_DIR.is_dir():
    STATIC_DIR = Path("/app/static")

# Static UI mounted last
app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")
