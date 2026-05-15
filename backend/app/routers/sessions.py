import uuid
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.session import ConversationTurn, Session
from app.models.user import User
from app.schemas.session import (
    ConversationTurnCreate,
    ConversationTurnResponse,
    SessionComplete,
    SessionCreate,
    SessionDetailResponse,
    SessionListResponse,
    SessionResponse,
    SessionSyncPayload,
    SessionSyncResponse,
)

router = APIRouter(prefix="/sessions", tags=["sessions"])


async def _upsert_session(
    db: AsyncSession, user_id: uuid.UUID, data: SessionCreate
) -> tuple[Session, bool]:
    """Create or return existing session by local_id. Returns (session, created)."""
    if data.local_id is not None:
        result = await db.execute(
            select(Session).where(Session.user_id == user_id, Session.local_id == data.local_id)
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            return existing, False

    session = Session(
        user_id=user_id,
        local_id=data.local_id,
        disease_id=data.disease_id,
        disease_name=data.disease_name,
        disease_category=data.disease_category,
        mode=data.mode,
        difficulty=data.difficulty,
        started_at=data.started_at or datetime.now(timezone.utc),
    )
    db.add(session)
    await db.flush()
    return session, True


@router.post("", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    body: SessionCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    session, _ = await _upsert_session(db, current_user.id, body)
    await db.commit()
    await db.refresh(session)
    return SessionResponse.model_validate(session)


@router.put("/{session_id}/complete", response_model=SessionResponse)
async def complete_session(
    session_id: uuid.UUID,
    body: SessionComplete,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == current_user.id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    update_data = body.model_dump(exclude_unset=True)
    if "ended_at" not in update_data or update_data["ended_at"] is None:
        update_data["ended_at"] = datetime.now(timezone.utc)

    for key, value in update_data.items():
        setattr(session, key, value)

    await db.commit()
    await db.refresh(session)
    return SessionResponse.model_validate(session)


@router.post("/{session_id}/conversation", status_code=status.HTTP_201_CREATED)
async def add_conversation_turns(
    session_id: uuid.UUID,
    body: list[ConversationTurnCreate],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == current_user.id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    for turn_data in body:
        turn = ConversationTurn(
            session_id=session.id,
            turn_index=turn_data.turn_index,
            question=turn_data.question,
            response=turn_data.response,
            is_test=turn_data.is_test,
            rating=turn_data.rating,
            tokens_input=turn_data.tokens_input,
            tokens_output=turn_data.tokens_output,
            model_used=turn_data.model_used,
        )
        db.add(turn)

    await db.commit()
    return {"added": len(body)}


@router.get("", response_model=SessionListResponse)
async def list_sessions(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    mode: str | None = None,
    disease_category: str | None = None,
    is_correct: bool | None = None,
):
    query = select(Session).where(Session.user_id == current_user.id)
    count_query = select(func.count()).select_from(Session).where(Session.user_id == current_user.id)

    if mode is not None:
        query = query.where(Session.mode == mode)
        count_query = count_query.where(Session.mode == mode)
    if disease_category is not None:
        query = query.where(Session.disease_category == disease_category)
        count_query = count_query.where(Session.disease_category == disease_category)
    if is_correct is not None:
        query = query.where(Session.is_correct == is_correct)
        count_query = count_query.where(Session.is_correct == is_correct)

    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    query = query.order_by(Session.started_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    sessions = result.scalars().all()

    return SessionListResponse(
        sessions=[SessionResponse.model_validate(s) for s in sessions],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{session_id}", response_model=SessionDetailResponse)
async def get_session(
    session_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == current_user.id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    turns_result = await db.execute(
        select(ConversationTurn)
        .where(ConversationTurn.session_id == session.id)
        .order_by(ConversationTurn.turn_index)
    )
    turns = turns_result.scalars().all()

    session_data = SessionResponse.model_validate(session).model_dump()
    session_data["conversation_turns"] = [ConversationTurnResponse.model_validate(t) for t in turns]
    return SessionDetailResponse(**session_data)


@router.post("/sync", response_model=SessionSyncResponse)
async def sync_sessions(
    body: SessionSyncPayload,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    synced = 0
    skipped = 0
    errors: list[str] = []

    for item in body.sessions:
        try:
            session, created = await _upsert_session(db, current_user.id, item.session)

            if not created:
                skipped += 1
                continue

            # Apply completion data if present
            if item.completion is not None:
                update_data = item.completion.model_dump(exclude_unset=True)
                if "ended_at" not in update_data or update_data["ended_at"] is None:
                    update_data["ended_at"] = datetime.now(timezone.utc)
                for key, value in update_data.items():
                    setattr(session, key, value)

            # Add conversation turns
            for turn_data in item.conversation_turns:
                turn = ConversationTurn(
                    session_id=session.id,
                    turn_index=turn_data.turn_index,
                    question=turn_data.question,
                    response=turn_data.response,
                    is_test=turn_data.is_test,
                    rating=turn_data.rating,
                    tokens_input=turn_data.tokens_input,
                    tokens_output=turn_data.tokens_output,
                    model_used=turn_data.model_used,
                )
                db.add(turn)

            synced += 1

        except Exception as e:
            local_id = item.session.local_id or "unknown"
            errors.append(f"Session {local_id}: {str(e)}")

    await db.commit()
    return SessionSyncResponse(synced=synced, skipped=skipped, errors=errors)
