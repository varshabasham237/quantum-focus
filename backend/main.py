"""
AntiDistractionSystem — FastAPI Backend Entry Point
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from database import connect_db, close_db
from routes.auth import router as auth_router
from routes.profile import router as profile_router
from routes.planner import router as planner_router
from routes.calendar import router as calendar_router
from routes.reports import router as reports_router
from routes.strictness import router as strictness_router
from routes.app_blocking import router as app_blocking_router
from routes.analytics import router as analytics_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle — connect/disconnect MongoDB."""
    await connect_db()
    yield
    await close_db()


app = FastAPI(
    title=settings.APP_NAME,
    description="Quantum-inspired, privacy-friendly anti-distraction system for students",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS — allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routes
app.include_router(auth_router, prefix="/api")
app.include_router(profile_router, prefix="/api")
app.include_router(planner_router, prefix="/api")
app.include_router(calendar_router, prefix="/api")
app.include_router(reports_router, prefix="/api")
app.include_router(strictness_router, prefix="/api")
app.include_router(app_blocking_router, prefix="/api")
app.include_router(analytics_router, prefix="/api")


@app.get("/")
async def root():
    return {
        "app": settings.APP_NAME,
        "version": "2.0.0",
        "status": "running",
        "docs": "/docs",
    }


from pymongo.errors import ServerSelectionTimeoutError
from fastapi.responses import JSONResponse

@app.exception_handler(ServerSelectionTimeoutError)
async def mongo_timeout_handler(request, exc):
    return JSONResponse(
        status_code=503,
        content={"detail": "Database connection failed. Please ensure your IP address is whitelisted in MongoDB Atlas Network Access!"}
    )

@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    print(f"[{settings.APP_NAME}] Backend starting on http://localhost:8000")
    print(f"  API Docs: http://localhost:8000/docs")
    print(f"  Database: MongoDB Atlas")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
