from pydantic import BaseModel
from typing import List, Literal, Optional, Dict, Any

Role = Literal["system", "user", "assistant"]

class Message(BaseModel):
    role: Role
    content: str

class ChatRequest(BaseModel):
    messages: List[Message]
    mode: Optional[Literal["coach", "generate", "debug", "refactor", "test"]] = None
    codeOnly: bool = False
    extra: Optional[Dict[str, Any]] = None

class ChatResponse(BaseModel):
    reply: str
