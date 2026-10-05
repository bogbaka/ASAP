from fastapi import FastAPI

app = FastAPI(
    title="ASAP API",
    version="0.1.0",
)


@app.get("/")
def root():
    return {"message": "ASAP API is running"}


@app.get("/health")
def health():
    return {"status": "ok"}