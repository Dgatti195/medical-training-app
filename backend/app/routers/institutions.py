import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db, require_role
from app.models.institution import Class, ClassEnrollment, Institution
from app.models.session import Session
from app.models.usage import UsageTracking
from app.models.user import User, UserRole
from app.schemas.institution import (
    ClassCreate,
    ClassResponse,
    EnrollRequest,
    InstitutionAnalytics,
    InstitutionCreate,
    InstitutionResponse,
    StudentSummary,
)
from app.schemas.session import SessionResponse

router = APIRouter(prefix="/institutions", tags=["institutions"])


def _check_institution_access(user: User, institution_id: uuid.UUID) -> None:
    """Verify the user belongs to this institution (teacher/admin)."""
    if user.role == UserRole.admin:
        return
    if user.institution_id != institution_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a member of this institution")
    if user.role not in (UserRole.teacher, UserRole.admin):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")


@router.post("", response_model=InstitutionResponse, status_code=status.HTTP_201_CREATED)
async def create_institution(
    body: InstitutionCreate,
    current_user: Annotated[User, Depends(require_role(UserRole.admin))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    institution = Institution(**body.model_dump())
    db.add(institution)
    await db.commit()
    await db.refresh(institution)
    return InstitutionResponse.model_validate(institution)


@router.get("/{institution_id}", response_model=InstitutionResponse)
async def get_institution(
    institution_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    _check_institution_access(current_user, institution_id)

    result = await db.execute(select(Institution).where(Institution.id == institution_id))
    institution = result.scalar_one_or_none()
    if institution is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Institution not found")

    return InstitutionResponse.model_validate(institution)


@router.get("/{institution_id}/students", response_model=list[StudentSummary])
async def list_students(
    institution_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    _check_institution_access(current_user, institution_id)

    result = await db.execute(
        select(User).where(
            User.institution_id == institution_id,
            User.role == UserRole.student,
            User.is_active.is_(True),
        )
    )
    students = result.scalars().all()

    summaries = []
    for student in students:
        session_count_result = await db.execute(
            select(func.count()).select_from(Session).where(Session.user_id == student.id)
        )
        total_sessions = session_count_result.scalar_one()

        correct_result = await db.execute(
            select(func.count())
            .select_from(Session)
            .where(Session.user_id == student.id, Session.is_correct.is_(True))
        )
        correct_diagnoses = correct_result.scalar_one()

        last_session_result = await db.execute(
            select(func.max(Session.started_at)).where(Session.user_id == student.id)
        )
        last_session_at = last_session_result.scalar_one()

        summaries.append(
            StudentSummary(
                id=student.id,
                email=student.email,
                name=student.name,
                total_sessions=total_sessions,
                correct_diagnoses=correct_diagnoses,
                last_session_at=last_session_at,
            )
        )

    return summaries


@router.get("/{institution_id}/students/{student_id}/sessions", response_model=list[SessionResponse])
async def get_student_sessions(
    institution_id: uuid.UUID,
    student_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    _check_institution_access(current_user, institution_id)

    # Verify student belongs to institution
    student_result = await db.execute(
        select(User).where(User.id == student_id, User.institution_id == institution_id)
    )
    student = student_result.scalar_one_or_none()
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found in institution")

    result = await db.execute(
        select(Session)
        .where(Session.user_id == student_id)
        .order_by(Session.started_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    sessions = result.scalars().all()

    return [SessionResponse.model_validate(s) for s in sessions]


@router.get("/{institution_id}/analytics", response_model=InstitutionAnalytics)
async def get_analytics(
    institution_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    _check_institution_access(current_user, institution_id)

    # Total students
    student_count = await db.execute(
        select(func.count()).select_from(User).where(
            User.institution_id == institution_id,
            User.role == UserRole.student,
            User.is_active.is_(True),
        )
    )
    total_students = student_count.scalar_one()

    # Session stats
    total_sessions_result = await db.execute(
        select(func.count()).select_from(Session).where(Session.user_id.in_(
            select(User.id).where(User.institution_id == institution_id)
        ))
    )
    total_sessions = total_sessions_result.scalar_one()

    total_correct_result = await db.execute(
        select(func.count()).select_from(Session).where(
            Session.user_id.in_(select(User.id).where(User.institution_id == institution_id)),
            Session.is_correct.is_(True),
        )
    )
    total_correct = total_correct_result.scalar_one()

    accuracy_rate = (total_correct / total_sessions * 100) if total_sessions > 0 else 0.0

    # Monthly usage
    from datetime import date

    first_of_month = date.today().replace(day=1)
    monthly_usage_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageTracking.total_tokens), 0),
            func.coalesce(func.sum(UsageTracking.requests_count), 0),
        ).where(
            UsageTracking.institution_id == institution_id,
            UsageTracking.date >= first_of_month,
        )
    )
    monthly_row = monthly_usage_result.one()

    return InstitutionAnalytics(
        total_students=total_students,
        total_sessions=total_sessions,
        total_correct=total_correct,
        accuracy_rate=round(accuracy_rate, 1),
        total_tokens_this_month=monthly_row[0],
        total_requests_this_month=monthly_row[1],
    )


@router.post("/{institution_id}/classes", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
async def create_class(
    institution_id: uuid.UUID,
    body: ClassCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    _check_institution_access(current_user, institution_id)

    new_class = Class(
        institution_id=institution_id,
        teacher_id=current_user.id,
        name=body.name,
    )
    db.add(new_class)
    await db.commit()
    await db.refresh(new_class)
    return ClassResponse.model_validate(new_class)


@router.post(
    "/{institution_id}/classes/{class_id}/enroll",
    status_code=status.HTTP_201_CREATED,
)
async def enroll_student(
    institution_id: uuid.UUID,
    class_id: uuid.UUID,
    body: EnrollRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    _check_institution_access(current_user, institution_id)

    # Verify class exists in institution
    class_result = await db.execute(
        select(Class).where(Class.id == class_id, Class.institution_id == institution_id)
    )
    cls = class_result.scalar_one_or_none()
    if cls is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found")

    # Verify student exists and belongs to institution
    student_result = await db.execute(
        select(User).where(
            User.id == body.student_id,
            User.institution_id == institution_id,
            User.role == UserRole.student,
        )
    )
    student = student_result.scalar_one_or_none()
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found in institution")

    # Check not already enrolled
    existing = await db.execute(
        select(ClassEnrollment).where(
            ClassEnrollment.class_id == class_id,
            ClassEnrollment.student_id == body.student_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Student already enrolled")

    enrollment = ClassEnrollment(class_id=class_id, student_id=body.student_id)
    db.add(enrollment)
    await db.commit()

    return {"enrolled": True, "class_id": str(class_id), "student_id": str(body.student_id)}
