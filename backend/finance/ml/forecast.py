"""Model B - spending forecast. Baseline (historical mean) vs Ridge on calendar+lag features, chosen by time-based backtest."""
import numpy as np
from datetime import date, timedelta
from sklearn.linear_model import Ridge

VERSION = "fc-ridge-lag-1.0"


def daily_series(tx_rows, days=120, today=None):
    """tx_rows: iterable of (date, amount) for expenses. Returns list of daily totals ending today."""
    today = today or date.today()
    start = today - timedelta(days=days - 1)
    s = np.zeros(days)
    for d, a in tx_rows:
        i = (d - start).days
        if 0 <= i < days:
            s[i] += float(a)
    return s, start


def _features(series, start, idx):
    d = start + timedelta(days=idx)
    lag7 = series[idx - 7] if idx >= 7 else series[:idx].mean() if idx else 0
    m7 = series[max(0, idx - 7):idx].mean() if idx else 0
    m28 = series[max(0, idx - 28):idx].mean() if idx else 0
    dow = np.zeros(7); dow[d.weekday()] = 1
    return np.concatenate([[lag7, m7, m28, 1 if d.day <= 5 else 0], dow])


def forecast(series, start, horizon=30):
    n = len(series)
    if n < 35 or series.sum() == 0:
        base = series[-30:].mean() if n else 0
        return dict(daily=[float(base)] * horizon, model="baseline-mean", mae=None, baseline_mae=None, version=VERSION)
    X = np.array([_features(series, start, i) for i in range(28, n)])
    y = series[28:]
    split = int(len(y) * 0.8)  # time-based split, no shuffling
    mdl = Ridge(alpha=5.0).fit(X[:split], y[:split])
    mae = float(np.abs(mdl.predict(X[split:]) - y[split:]).mean())
    base_pred = np.array([series[28 + split + k - 28:28 + split + k].mean() for k in range(len(y) - split)])
    base_mae = float(np.abs(base_pred - y[split:]).mean())
    use_model = mae < base_mae
    mdl = Ridge(alpha=5.0).fit(X, y)
    ext = list(series); out = []
    for h in range(horizon):
        idx = len(ext)
        if use_model:
            f = _features(np.array(ext), start, idx)
            v = max(0.0, float(mdl.predict([f])[0]))
        else:
            v = float(np.mean(ext[-28:]))
        ext.append(v); out.append(v)
    resid = float(np.std(y[split:] - mdl.predict(X[split:]))) if use_model else float(np.std(series[-28:]))
    return dict(daily=out, model="ridge-lag" if use_model else "baseline-mean", mae=round(mae, 1),
                baseline_mae=round(base_mae, 1), resid_std=resid, version=VERSION)
