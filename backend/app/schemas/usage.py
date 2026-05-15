from datetime import date

from pydantic import BaseModel


class DailyUsage(BaseModel):
    date: date
    input_tokens: int
    output_tokens: int
    total_tokens: int
    requests_count: int
    estimated_cost_usd: float

    model_config = {"from_attributes": True}


class UsageSummary(BaseModel):
    daily: list[DailyUsage]
    monthly_total_tokens: int
    monthly_total_requests: int
    monthly_estimated_cost: float
