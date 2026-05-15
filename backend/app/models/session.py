import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    local_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Disease info
    disease_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    disease_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    disease_category: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Session config
    mode: Mapped[str | None] = mapped_column(String(50), nullable=True)
    difficulty: Mapped[str | None] = mapped_column(String(50), nullable=True)

    # Timestamps
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Clinical mode results
    questions_asked: Mapped[int | None] = mapped_column(Integer, nullable=True)
    hints_used: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tests_ordered: Mapped[int | None] = mapped_column(Integer, nullable=True)
    final_diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    completion_status: Mapped[str | None] = mapped_column(String(50), nullable=True)

    # Treatment fields
    treatment_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    treatment_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Basic mode score fields
    basic_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    basic_areas_covered: Mapped[int | None] = mapped_column(Integer, nullable=True)
    basic_total_areas: Mapped[int | None] = mapped_column(Integer, nullable=True)

    user = relationship("User", back_populates="sessions")
    conversation_turns = relationship(
        "ConversationTurn", back_populates="session", cascade="all, delete-orphan",
        order_by="ConversationTurn.turn_index"
    )

    __table_args__ = (
        UniqueConstraint("user_id", "local_id", name="uq_session_user_local_id"),
    )


class ConversationTurn(Base):
    __tablename__ = "conversation_turns"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    turn_index: Mapped[int] = mapped_column(Integer, nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    response: Mapped[str] = mapped_column(Text, nullable=False)
    is_test: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_input: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_output: Mapped[int | None] = mapped_column(Integer, nullable=True)
    model_used: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    session = relationship("Session", back_populates="conversation_turns")
