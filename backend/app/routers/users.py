from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.session import ConversationTurn, Session
from app.models.usage import UsageTracking
from app.models.user import User
from app.schemas.user import UserDataExport, UserProfileResponse, UserUpdateRequest

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserProfileResponse)
async def get_profile(current_user: Annotated[User, Depends(get_current_user)]):
    return UserProfileResponse.model_validate(current_user)


@router.put("/me", response_model=UserProfileResponse)
async def update_profile(
    body: UserUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(current_user, key, value)
    await db.commit()
    await db.refresh(current_user)
    return UserProfileResponse.model_validate(current_user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user_data(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """LGPD: Delete all user data. Cascading deletes handle sessions, turns, usage, tokens."""
    await db.delete(current_user)
    await db.commit()


@router.get("/me/data-export", response_model=UserDataExport)
async def export_user_data(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """LGPD: Export all user data as JSON."""
    user_resp = UserProfileResponse.model_validate(current_user)

    # Sessions + turns
    sessions_result = await db.execute(
        select(Session).where(Session.user_id == current_user.id).order_by(Session.started_at.desc())
    )
    sessions = sessions_result.scalars().all()

    session_data = []
    for s in sessions:
        turns_result = await db.execute(
            select(ConversationTurn)
            .where(ConversationTurn.session_id == s.id)
            .order_by(ConversationTurn.turn_index)
        )
        turns = turns_result.scalars().all()

        session_dict = {
            "id": str(s.id),
            "local_id": s.local_id,
            "disease_name": s.disease_name,
            "disease_category": s.disease_category,
            "mode": s.mode,
            "difficulty": s.difficulty,
            "started_at": s.started_at.isoformat() if s.started_at else None,
            "ended_at": s.ended_at.isoformat() if s.ended_at else None,
            "final_diagnosis": s.final_diagnosis,
            "is_correct": s.is_correct,
            "completion_status": s.completion_status,
            "conversation_turns": [
                {
                    "turn_index": t.turn_index,
                    "question": t.question,
                    "response": t.response,
                    "is_test": t.is_test,
                }
                for t in turns
            ],
        }
        session_data.append(session_dict)

    # Usage
    usage_result = await db.execute(
        select(UsageTracking)
        .where(UsageTracking.user_id == current_user.id)
        .order_by(UsageTracking.date.desc())
    )
    usage_records = usage_result.scalars().all()
    usage_data = [
        {
            "date": str(u.date),
            "input_tokens": u.input_tokens,
            "output_tokens": u.output_tokens,
            "total_tokens": u.total_tokens,
            "requests_count": u.requests_count,
            "estimated_cost_usd": u.estimated_cost_usd,
        }
        for u in usage_records
    ]

    return UserDataExport(user=user_resp, sessions=session_data, usage=usage_data)
