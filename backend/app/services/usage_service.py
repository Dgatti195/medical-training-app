import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.usage import UsageTracking
from app.models.user import User, UserRole

# Rate limits per role
RATE_LIMITS = {
    UserRole.student: {"requests_per_hour": 60, "requests_per_day": 500},
    UserRole.teacher: {"requests_per_hour": 120, "requests_per_day": 1000},
    UserRole.admin: {"requests_per_hour": 300, "requests_per_day": 5000},
}

# Approximate costs per token (Claude Sonnet pricing)
INPUT_COST_PER_TOKEN = 3.0 / 1_000_000
OUTPUT_COST_PER_TOKEN = 15.0 / 1_000_000


class RateLimitExceeded(Exception):
    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


async def check_rate_limits(db: AsyncSession, user: User) -> None:
    """Check per-user hourly and daily rate limits."""
    limits = RATE_LIMITS.get(user.role, RATE_LIMITS[UserRole.student])
    now = datetime.now(timezone.utc)
    today = now.date()

    # Check daily limit via usage_tracking table
    result = await db.execute(
        select(UsageTracking.requests_count).where(
            UsageTracking.user_id == user.id,
            UsageTracking.date == today,
        )
    )
    daily_count = result.scalar_one_or_none() or 0
    if daily_count >= limits["requests_per_day"]:
        raise RateLimitExceeded(f"Daily request limit ({limits['requests_per_day']}) exceeded")

    # Check institution monthly token cap if applicable
    if user.institution_id is not None:
        from app.models.institution import Institution

        inst_result = await db.execute(select(Institution).where(Institution.id == user.institution_id))
        institution = inst_result.scalar_one_or_none()
        if institution is not None:
            first_of_month = today.replace(day=1)
            monthly_result = await db.execute(
                select(func.coalesce(func.sum(UsageTracking.total_tokens), 0)).where(
                    UsageTracking.institution_id == institution.id,
                    UsageTracking.date >= first_of_month,
                )
            )
            monthly_tokens = monthly_result.scalar_one()
            if monthly_tokens >= institution.monthly_token_limit:
                raise RateLimitExceeded("Institution monthly token limit exceeded")


async def record_usage(
    db: AsyncSession,
    user_id: uuid.UUID,
    institution_id: uuid.UUID | None,
    input_tokens: int,
    output_tokens: int,
) -> None:
    """Record token usage — upsert by (user_id, date)."""
    today = date.today()
    total_tokens = input_tokens + output_tokens
    estimated_cost = (input_tokens * INPUT_COST_PER_TOKEN) + (output_tokens * OUTPUT_COST_PER_TOKEN)

    stmt = insert(UsageTracking).values(
        user_id=user_id,
        institution_id=institution_id,
        date=today,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        total_tokens=total_tokens,
        requests_count=1,
        estimated_cost_usd=estimated_cost,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_usage_user_date",
        set_={
            "input_tokens": UsageTracking.input_tokens + input_tokens,
            "output_tokens": UsageTracking.output_tokens + output_tokens,
            "total_tokens": UsageTracking.total_tokens + total_tokens,
            "requests_count": UsageTracking.requests_count + 1,
            "estimated_cost_usd": UsageTracking.estimated_cost_usd + estimated_cost,
        },
    )
    await db.execute(stmt)
    await db.commit()
