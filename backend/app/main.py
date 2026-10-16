from fastapi import FastAPI

from app.api.routes.auth import router as auth_router

app = FastAPI(
    title="ASAP API",
    version="0.1.0",
)

app.include_router(auth_router)


@app.get("/")
def root():
    return {"message": "ASAP API is running"}


@app.get("/health")
def health():
    return {"status": "ok"}