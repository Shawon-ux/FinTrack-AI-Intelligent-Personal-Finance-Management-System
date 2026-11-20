"""Model C - anomaly detection. Robust per-category statistics + IsolationForest on amount/hour features.
Results are 'unusual', never 'fraud' (BR-11)."""
import numpy as np
from sklearn.ensemble import IsolationForest

VERSION = "anom-iforest-1.0"


def check(new, history):
    """new: dict(amount, category, hour, merchant). history: list of same dicts (expenses only)."""
    reasons, score = [], 0.0
    cat_hist = np.array([h["amount"] for h in history if h["category"] == new["category"]], dtype=float)
    if len(cat_hist) >= 5:
        med = np.median(cat_hist); mad = np.median(np.abs(cat_hist - med)) or max(med * 0.25, 1)
        z = 0.6745 * (new["amount"] - med) / mad
        if z > 3.5:
            reasons.append(f"{new['amount']:.0f} is far above your usual {new['category']} spend (typical ~{med:.0f}).")
            score = max(score, min(1.0, z / 10))
    if len(history) >= 20:
        X = np.array([[h["amount"], h["hour"]] for h in history], dtype=float)
        iso = IsolationForest(n_estimators=100, contamination=0.03, random_state=0).fit(X)
        s = -iso.score_samples([[new["amount"], new["hour"]]])[0]
        if iso.predict([[new["amount"], new["hour"]]])[0] == -1:
            reasons.append("Amount/time combination is unlike your normal pattern.")
            score = max(score, float(s))
    if new.get("merchant") and history and not any(h.get("merchant") == new["merchant"] for h in history) \
            and len(cat_hist) and new["amount"] > 2 * np.mean(cat_hist):
        reasons.append(f"First purchase from '{new['merchant']}' and larger than average.")
        score = max(score, 0.5)
    return dict(unusual=bool(reasons), score=round(score, 2), reasons=reasons, model_version=VERSION)
