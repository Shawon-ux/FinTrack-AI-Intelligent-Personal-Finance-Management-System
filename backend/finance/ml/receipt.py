"""Receipt text parsing (post-OCR). Image OCR runs on-device (ML Kit) in the real app; on the server we accept OCR text,
and use pytesseract if installed. Extraction always requires user confirmation (BR-08)."""
import re, hashlib
from datetime import datetime

NUM = r"(\d[\d,]*(?:\.\d{1,2})?)"
DATE_FORMATS = ["%d %B %Y", "%d %b %Y", "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d"]


def ocr_image(data: bytes):
    try:
        import io, pytesseract
        from PIL import Image
        return pytesseract.image_to_string(Image.open(io.BytesIO(data)))
    except Exception:
        return None


def parse(text: str):
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    merchant = lines[0].title() if lines else ""
    items, total, vat, discount, date = [], None, 0.0, 0.0, None
    for l in lines[1:]:
        low = l.lower()
        m = re.search(NUM + r"\s*(?:৳|tk|taka)?\s*$", l, re.I)
        val = float(m.group(1).replace(",", "")) if m else None
        if val is None:
            for fmt in DATE_FORMATS:
                try:
                    date = datetime.strptime(l.title() if "%B" in fmt or "%b" in fmt else l, fmt).date().isoformat(); break
                except ValueError:
                    pass
            continue
        label = re.sub(NUM + r"\s*(?:৳|tk|taka)?\s*$", "", l, flags=re.I).strip(" :.-৳")
        if re.search(r"\b(grand\s*)?total\b|amount due", low): total = val
        elif "vat" in low or "tax" in low: vat = val
        elif "discount" in low: discount = val
        elif "subtotal" in low: continue
        elif label: items.append({"name": label, "amount": val})
    if total is None and items:
        total = sum(i["amount"] for i in items) + vat - discount
    h = hashlib.sha256(re.sub(r"\s+", "", text.lower()).encode()).hexdigest()
    return dict(merchant=merchant, items=items, vat=vat, discount=discount, total=total, date=date, receipt_hash=h)
