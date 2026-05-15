from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import ai, auth, health, institutions, sessions, usage, users

app = FastAPI(
    title="Med.IA 4.0 Backend",
    version="1.0.0",
    description="Backend API for Med.IA 4.0 medical training app",
)

# CORS
origins = settings.ALLOWED_ORIGINS.split(",") if settings.ALLOWED_ORIGINS != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(ai.router)
app.include_router(sessions.router)
app.include_router(users.router)
app.include_router(institutions.router)
app.include_router(usage.router)
