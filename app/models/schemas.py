from pydantic import BaseModel
from typing import List, Optional

class InterviewQuestionRequest(BaseModel):
    target_role: str
    experience_level: str = "Entry Level"
    resume_summary: Optional[str] = ""

class InterviewFeedbackRequest(BaseModel):
    question: str
    user_answer: str
    target_role: str