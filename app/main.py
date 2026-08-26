from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.services.parser_service import extract_content_or_images
from app.services.ai_service import (
    analyze_career_gap_multimodal,
    generate_interview_questions,
    evaluate_interview_answer,
    tailor_resume_bullets,
    get_market_intelligence,
)

app = FastAPI(title="AI CareerPilot API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class MarketRequest(BaseModel):
    target_role: str
    experience_level: str
    location: str

class QuestionRequest(BaseModel):
    target_role: str
    experience_level: str

class AnswerRequest(BaseModel):
    question: str
    user_answer: str
    target_role: str

class TailorRequest(BaseModel):
    resume_text: str
    job_description: str
    target_role: str

@app.get("/")
def root():
    return {"status": "AI CareerPilot API running"}

@app.post("/api/v1/analyze")
async def analyze_endpoint(target_role: str = Form(...), file: UploadFile = File(...)):
    print(f"\n[BACKEND] Analyzing resume for: {target_role} ({file.filename})")
    file_bytes = await file.read()
    parsed_payload = extract_content_or_images(file_bytes, file.filename)
    result = analyze_career_gap_multimodal(parsed_payload, target_role)
    return {"status": "success", "data": result}

@app.post("/api/v1/market-radar")
async def market_endpoint(payload: MarketRequest):
    print(f"\n[BACKEND] Market Radar requested: {payload.target_role} | {payload.location}")
    return await get_market_intelligence(payload.target_role, payload.experience_level, payload.location)

@app.post("/api/v1/interview/questions")
def questions_endpoint(payload: QuestionRequest):
    print(f"\n[BACKEND] Generating questions for: {payload.target_role}")
    return generate_interview_questions(payload.target_role, payload.experience_level)

@app.post("/api/v1/interview/evaluate")
def evaluate_endpoint(payload: AnswerRequest):
    print(f"\n[BACKEND] Evaluating answer for: {payload.target_role}")
    return evaluate_interview_answer(payload.question, payload.user_answer, payload.target_role)

@app.post("/api/v1/ats/tailor")
def tailor_endpoint(payload: TailorRequest):
    print(f"\n[BACKEND] Optimizing resume for ATS: {payload.target_role}")
    return tailor_resume_bullets(payload.resume_text, payload.job_description, payload.target_role)