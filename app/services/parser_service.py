import fitz  # PyMuPDF
import io
from PIL import Image

def extract_content_or_images(file_bytes: bytes, filename: str) -> dict:
    fname = filename.lower()
    
    # 1. Image formats
    if any(fname.endswith(ext) for ext in [".png", ".jpg", ".jpeg", ".webp"]):
        try:
            img = Image.open(io.BytesIO(file_bytes))
            return {"type": "image", "data": img}
        except Exception as e:
            print(f"[Parser] Image open error: {e}")

    # 2. PDF formats
    try:
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        extracted_text = ""
        for page in doc:
            extracted_text += page.get_text("text") + "\n"

        if len(extracted_text.strip()) > 30:
            print(f"[Parser] Successfully extracted {len(extracted_text)} characters from {filename}")
            return {"type": "text", "data": extracted_text.strip()}
        
        # Scanned PDF: Render first page as PIL Image
        if len(doc) > 0:
            page = doc[0]
            pix = page.get_pixmap(dpi=150)
            img = Image.open(io.BytesIO(pix.tobytes("png")))
            print(f"[Parser] Rendered scanned PDF page as image")
            return {"type": "image", "data": img}
    except Exception as e:
        print(f"[Parser] PDF extraction error: {e}")

    # 3. Fallback raw decode
    text_content = file_bytes.decode("utf-8", errors="ignore")
    return {"type": "text", "data": text_content if len(text_content.strip()) > 0 else "Empty or unreadable document"}