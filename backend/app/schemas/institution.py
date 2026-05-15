import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class InstitutionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    plan_type: str = Field(default="basic", max_length=50)
    max_students: int = Field(default=100, ge=1)
    monthly_token_limit: int = Field(default=10_000_000, ge=0)
    monthly_request_limit: int = Field(default=50_000, ge=0)


class InstitutionResponse(BaseModel):
    id: uuid.UUID
    name: str
    plan_type: str
    max_students: int
    monthly_token_limit: int
    monthly_request_limit: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ClassCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class ClassResponse(BaseModel):
    id: uuid.UUID
    institution_id: uuid.UUID
    teacher_id: uuid.UUID
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class EnrollRequest(BaseModel):
    student_id: uuid.UUID


class StudentSummary(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    total_sessions: int
    correct_diagnoses: int
    last_session_at: datetime | None


class InstitutionAnalytics(BaseModel):
    total_students: int
    total_sessions: int
    total_correct: int
    accuracy_rate: float
    total_tokens_this_month: int
    total_requests_this_month: int
