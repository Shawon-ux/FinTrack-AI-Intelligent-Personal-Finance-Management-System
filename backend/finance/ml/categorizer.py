"""Model A - transaction categorisation: TF-IDF + Logistic Regression trained on a synthetic seed set.
Per-user personalisation: user corrections override the global prediction (never trains a global model on private data)."""
import re
from functools import lru_cache
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.model_selection import cross_val_score

VERSION = "cat-tfidf-lr-1.0"

SEED = {
    ("Food", "Fast Food"): "kfc burger pizza hut dominos fries chicken fried sandwich shawarma nuggets fast food mcdonalds takeaway",
    ("Food", "Restaurant"): "restaurant dinner lunch breakfast biryani kacchi cafe coffee tea dining buffet iftar",
    ("Food", "Groceries"): "grocery rice oil vegetables fruits meat fish egg milk shwapno agora meena bazar supermarket bazar",
    ("Transport", "Ride"): "uber pathao rickshaw cng taxi ride fare bus ticket metro",
    ("Transport", "Fuel"): "fuel petrol octane diesel cng gas station parking toll",
    ("Bills", "Utilities"): "electricity bill gas bill water bill wasa dpdc desco utility",
    ("Bills", "Internet"): "internet wifi broadband grameenphone robi banglalink airtel recharge data pack mobile bill",
    ("Bills", "Rent"): "house rent monthly rent landlord apartment rent",
    ("Shopping", "Clothing"): "shirt pant clothes shoes aarong yellow shopping mall dress jacket fashion",
    ("Shopping", "Electronics"): "laptop phone charger headphone earbuds daraz electronics gadget keyboard",
    ("Entertainment", "Streaming"): "netflix spotify youtube premium subscription prime hotstar chorki",
    ("Entertainment", "Movies"): "cinema movie ticket star cineplex game concert",
    ("Health", "Pharmacy"): "pharmacy medicine doctor hospital lazz pharma clinic tablet checkup lab test",
    ("Education", "Courses"): "tuition course book exam fee school university udemy coaching stationery",
    ("Personal Care", "Salon"): "salon haircut barber spa beauty cosmetics shampoo skincare",
    ("Income", "Salary"): "salary paycheck monthly pay wages",
    ("Income", "Freelance"): "freelance client payment project payment upwork fiverr bonus gift received",
}
EXTRA = {
    ("Food", "Fast Food"): ["paid kfc dinner", "ordered pizza hut", "burger king meal", "foodpanda order"],
    ("Transport", "Ride"): ["uber to office", "pathao ride home", "rickshaw fare"],
    ("Bills", "Internet"): ["recharged grameenphone", "wifi bill paid"],
}


def _dataset():
    X, y = [], []
    for (cat, sub), words in SEED.items():
        toks = words.split()
        for i in range(len(toks)):
            X.append(" ".join(toks[i:i + 2])); y.append(f"{cat}|{sub}")
            X.append(f"paid {toks[i]} bill taka"); y.append(f"{cat}|{sub}")
        X.append(words); y.append(f"{cat}|{sub}")
    for (cat, sub), ex in EXTRA.items():
        for e in ex:
            X.append(e); y.append(f"{cat}|{sub}")
    return X, y


@lru_cache(maxsize=1)
def model():
    X, y = _dataset()
    pipe = make_pipeline(TfidfVectorizer(ngram_range=(1, 2), sublinear_tf=True), LogisticRegression(max_iter=1000, C=30))
    pipe.fit(X, y)
    return pipe


@lru_cache(maxsize=1)
def metrics():
    X, y = _dataset()
    pipe = make_pipeline(TfidfVectorizer(ngram_range=(1, 2), sublinear_tf=True), LogisticRegression(max_iter=1000, C=30))
    f1 = cross_val_score(pipe, X, y, cv=3, scoring="f1_macro").mean()
    return {"macro_f1_cv_synthetic": round(float(f1), 3), "note": "synthetic seed data - not real-world performance"}


AMOUNT_RE = re.compile(r"(?:৳|tk\.?|taka|bdt)?\s*(\d[\d,]*(?:\.\d+)?)\s*(?:৳|tk\.?|taka|bdt)?", re.I)
MERCH_RE = re.compile(r"\b(?:at|from|to|in)\s+([A-Za-z][\w&' -]{1,30}?)(?=\s+(?:for|on|via|using|today|yesterday)\b|[.,]|$)", re.I)


def parse(text: str):
    amount = None
    for m in AMOUNT_RE.finditer(text):
        try:
            amount = float(m.group(1).replace(",", "")); break
        except ValueError:
            pass
    merchant = ""
    m = MERCH_RE.search(text)
    if m:
        merchant = m.group(1).strip().title()
    t = text.lower()
    ttype = "income" if re.search(r"\b(received|salary|earned|got paid|income|bonus)\b", t) else "expense"
    return amount, merchant, ttype


def predict(text: str, user_corrections=None):
    amount, merchant, ttype = parse(text)
    clean = re.sub(r"[\d৳,.]", " ", text.lower())
    # personalised override: exact merchant/keyword previously corrected by this user
    for c in (user_corrections or []):
        key = (c.merchant or "").lower()
        if key and key in clean:
            cat, _, sub = c.corrected.partition("|")
            return dict(category=cat, subcategory=sub, confidence=0.99, merchant=merchant or c.merchant,
                        amount=amount, type=ttype, source="personalised", model_version=VERSION)
    pipe = model()
    probs = pipe.predict_proba([clean])[0]
    i = probs.argmax()
    cat, _, sub = pipe.classes_[i].partition("|")
    if cat == "Income":
        ttype = "income"
    return dict(category=cat, subcategory=sub, confidence=round(float(probs[i]), 2), merchant=merchant, amount=amount,
                type=ttype, source="global", model_version=VERSION)
