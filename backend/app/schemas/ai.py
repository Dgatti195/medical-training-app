from pydantic import BaseModel, Field


class MessageItem(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str


class ChatRequest(BaseModel):
    system_prompt: str
    messages: list[MessageItem]
    model: str = "claude-sonnet-4-6"
    max_tokens: int = Field(default=150, ge=1, le=4096)
    session_id: str | None = None


class ChatResponse(BaseModel):
    text: str
    model: str
    input_tokens: int
    output_tokens: int


class TestResultRequest(BaseModel):
    system_prompt: str
    messages: list[MessageItem]
    model: str = "claude-sonnet-4-6"
    max_tokens: int = Field(default=300, ge=1, le=4096)
    session_id: str | None = None
