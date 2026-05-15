import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.usage import UsageTracking
from app.models.user import User, UserRole
from app.schemas.usage import DailyUsage, UsageSummary

router = APIRouter(prefix="/usage", tags=["usage"])


@router.get("/me", response_model=UsageSummary)
async def get_my_usage(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(30, ge=1, le=365),
):
    first_of_month = date.today().replace(day=1)

    # Daily breakdown
    result = await db.execute(
        select(UsageTracking)
        .where(UsageTracking.user_id == current_user.id)
        .order_by(UsageTracking.date.desc())
        .limit(days)
    )
    records = result.scalars().all()

    daily = [DailyUsage.model_validate(r) for r in records]

    # Monthly aggregates
    monthly_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageTracking.total_tokens), 0),
            func.coalesce(func.sum(UsageTracking.requests_count), 0),
            func.coalesce(func.sum(UsageTracking.estimated_cost_usd), 0.0),
        ).where(
            UsageTracking.user_id == current_user.id,
            UsageTracking.date >= first_of_month,
        )
    )
    monthly = monthly_result.one()

    return UsageSummary(
        daily=daily,
        monthly_total_tokens=monthly[0],
        monthly_total_requests=monthly[1],
        monthly_estimated_cost=round(monthly[2], 4),
    )


@router.get("/institution/{institution_id}", response_model=UsageSummary)
async def get_institution_usage(
    institution_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(30, ge=1, le=365),
):
    # Only teacher/admin of the institution
    if current_user.role == UserRole.student:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
    if current_user.role == UserRole.teacher and current_user.institution_id != institution_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a member of this institution")

    first_of_month = date.today().replace(day=1)

    # Daily breakdown — aggregate across all users in institution
    result = await db.execute(
        select(
            UsageTracking.date,
            func.sum(UsageTracking.input_tokens).label("input_tokens"),
            func.sum(UsageTracking.output_tokens).label("output_tokens"),
            func.sum(UsageTracking.total_tokens).label("total_tokens"),
            func.sum(UsageTracking.requests_count).label("requests_count"),
            func.sum(UsageTracking.estimated_cost_usd).label("estimated_cost_usd"),
        )
        .where(UsageTracking.institution_id == institution_id)
        .group_by(UsageTracking.date)
        .order_by(UsageTracking.date.desc())
        .limit(days)
    )
    rows = result.all()

    daily = [
        DailyUsage(
            date=row.date,
            input_tokens=row.input_tokens,
            output_tokens=row.output_tokens,
            total_tokens=row.total_tokens,
            requests_count=row.requests_count,
            estimated_cost_usd=round(row.estimated_cost_usd, 4),
        )
        for row in rows
    ]

    # Monthly aggregates
    monthly_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageTracking.total_tokens), 0),
            func.coalesce(func.sum(UsageTracking.requests_count), 0),
            func.coalesce(func.sum(UsageTracking.estimated_cost_usd), 0.0),
        ).where(
            UsageTracking.institution_id == institution_id,
            UsageTracking.date >= first_of_month,
        )
    )
    monthly = monthly_result.one()

    return UsageSummary(
        daily=daily,
        monthly_total_tokens=monthly[0],
        monthly_total_requests=monthly[1],
        monthly_estimated_cost=round(monthly[2], 4),
    )
