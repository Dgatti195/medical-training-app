from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.ai import ChatRequest, ChatResponse, TestResultRequest
from app.services.claude_proxy import ClaudeProxyError, call_claude
from app.services.usage_service import RateLimitExceeded, check_rate_limits, record_usage

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Check rate limits
    try:
        await check_rate_limits(db, current_user)
    except RateLimitExceeded as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.detail)

    # Forward to Anthropic
    messages = [{"role": m.role, "content": m.content} for m in body.messages]
    try:
        result = await call_claude(
            system_prompt=body.system_prompt,
            messages=messages,
            model=body.model,
            max_tokens=body.max_tokens,
        )
    except ClaudeProxyError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)

    # Record usage
    await record_usage(
        db=db,
        user_id=current_user.id,
        institution_id=current_user.institution_id,
        input_tokens=result["input_tokens"],
        output_tokens=result["output_tokens"],
    )

    return ChatResponse(**result)


@router.post("/test-result", response_model=ChatResponse)
async def test_result(
    body: TestResultRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Check rate limits
    try:
        await check_rate_limits(db, current_user)
    except RateLimitExceeded as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.detail)

    # Forward to Anthropic
    messages = [{"role": m.role, "content": m.content} for m in body.messages]
    try:
        result = await call_claude(
            system_prompt=body.system_prompt,
            messages=messages,
            model=body.model,
            max_tokens=body.max_tokens,
        )
    except ClaudeProxyError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)

    # Record usage
    await record_usage(
        db=db,
        user_id=current_user.id,
        institution_id=current_user.institution_id,
        input_tokens=result["input_tokens"],
        output_tokens=result["output_tokens"],
    )

    return ChatResponse(**result)
