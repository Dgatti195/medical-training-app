import httpx

from app.config import settings

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"


class ClaudeProxyError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


async def call_claude(
    system_prompt: str,
    messages: list[dict],
    model: str = "claude-sonnet-4-6",
    max_tokens: int = 150,
) -> dict:
    """Forward a chat request to the Anthropic API and return parsed response."""
    headers = {
        "x-api-key": settings.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "system": system_prompt,
        "messages": messages,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(ANTHROPIC_API_URL, headers=headers, json=payload)

    if response.status_code != 200:
        raise ClaudeProxyError(
            status_code=response.status_code,
            detail=f"Anthropic API error: {response.text}",
        )

    data = response.json()

    text = ""
    if data.get("content"):
        for block in data["content"]:
            if block.get("type") == "text":
                text += block.get("text", "")

    usage = data.get("usage", {})
    input_tokens = usage.get("input_tokens", 0)
    output_tokens = usage.get("output_tokens", 0)

    return {
        "text": text,
        "model": data.get("model", model),
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
    }
