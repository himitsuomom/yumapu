import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from openai import OpenAI
from models import ChatRequest, ChatResponse

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
SYSTEM_PROMPT_PATH = Path(os.getenv("SYSTEM_PROMPT_PATH", "server/system_prompt.txt"))
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173").split(",")

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY not set. Create server/.env from .env.example")

system_prompt = SYSTEM_PROMPT_PATH.read_text(encoding="utf-8")

app = FastAPI(title="PromptSmith API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in CORS_ORIGINS],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = OpenAI(api_key=OPENAI_API_KEY)

@app.get("/api/health")
def health():
    return {"status": "ok"}

@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    # Compose messages: system → (optional mode hint) → user history
    messages = [{"role": "system", "content": system_prompt}]

    if req.mode:
        mode_hint = (
            f"Mode: {req.mode}. If information is missing, ask the minimal set of questions before proceeding.\n"
        )
        messages.append({"role": "system", "content": mode_hint})

    if req.codeOnly:
        messages.append({
            "role": "system",
            "content": "User requests code-only output. Respond with code blocks only, no narration, unless clarification is required."
        })

    # Forward conversation
    for m in req.messages:
        messages.append({"role": m.role, "content": m.content})

    completion = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=messages,
        temperature=0.2,
    )

    reply = completion.choices[0].message.content or ""
    return ChatResponse(reply=reply)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
