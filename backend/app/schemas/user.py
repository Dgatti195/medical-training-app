import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class UserProfileResponse(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    role: str
    institution_id: uuid.UUID | None
    language_pref: str
    is_active: bool
    lgpd_consent_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    language_pref: str | None = Field(default=None, max_length=10)


class UserDataExport(BaseModel):
    user: UserProfileResponse
    sessions: list[dict]
    usage: list[dict]
