import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ConversationTurnCreate(BaseModel):
    turn_index: int
    question: str
    response: str
    is_test: bool = False
    rating: int | None = None
    tokens_input: int | None = None
    tokens_output: int | None = None
    model_used: str | None = None


class ConversationTurnResponse(BaseModel):
    id: uuid.UUID
    turn_index: int
    question: str
    response: str
    is_test: bool
    rating: int | None
    tokens_input: int | None
    tokens_output: int | None
    model_used: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class SessionCreate(BaseModel):
    local_id: str | None = None
    disease_id: int | None = None
    disease_name: str | None = None
    disease_category: str | None = None
    mode: str | None = None
    difficulty: str | None = None
    started_at: datetime | None = None


class SessionComplete(BaseModel):
    ended_at: datetime | None = None
    questions_asked: int | None = None
    hints_used: int | None = None
    tests_ordered: int | None = None
    final_diagnosis: str | None = None
    is_correct: bool | None = None
    confidence_score: float | None = None
    completion_status: str | None = None
    treatment_score: float | None = None
    treatment_feedback: str | None = None
    basic_score: float | None = None
    basic_areas_covered: int | None = None
    basic_total_areas: int | None = None


class SessionResponse(BaseModel):
    id: uuid.UUID
    local_id: str | None
    disease_id: int | None
    disease_name: str | None
    disease_category: str | None
    mode: str | None
    difficulty: str | None
    started_at: datetime
    ended_at: datetime | None
    questions_asked: int | None
    hints_used: int | None
    tests_ordered: int | None
    final_diagnosis: str | None
    is_correct: bool | None
    confidence_score: float | None
    completion_status: str | None
    treatment_score: float | None
    treatment_feedback: str | None
    basic_score: float | None
    basic_areas_covered: int | None
    basic_total_areas: int | None

    model_config = {"from_attributes": True}


class SessionDetailResponse(SessionResponse):
    conversation_turns: list[ConversationTurnResponse] = []


class SessionListResponse(BaseModel):
    sessions: list[SessionResponse]
    total: int
    page: int
    page_size: int


class SessionSyncItem(BaseModel):
    session: SessionCreate
    completion: SessionComplete | None = None
    conversation_turns: list[ConversationTurnCreate] = []


class SessionSyncPayload(BaseModel):
    sessions: list[SessionSyncItem]


class SessionSyncResponse(BaseModel):
    synced: int
    skipped: int
    errors: list[str] = []
