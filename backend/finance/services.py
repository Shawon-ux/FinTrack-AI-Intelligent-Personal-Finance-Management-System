import re
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from .ml import anomaly as anom, forecast as fc
from .models import (Account, AnomalyAlert, Budget, ModelVersion, Notification, Prediction, SavingsGoal, Transaction)


def f(x):
    return float(x or 0)


def txs(user):
    return Transaction.objects.filter(user=user, is_deleted=False)


def month_bounds(d=None):
    d = d or timezone.localdate()
    start = d.replace(day=1)
    nxt = (start + timedelta(days=32)).replace(day=1)
    return start, nxt - timedelta(days=1)


def _sum(qs, ttype):
    return f(qs.filter(transaction_type=ttype).aggregate(s=Sum("amount"))["s"])


def account_balance(acc):
    qs = Transaction.objects.filter(is_deleted=False)
    a = qs.filter(account=acc)
    bal = f(acc.opening_balance) + _sum(a, "income") - _sum(a, "expense") - _sum(a, "transfer")
    bal += _sum(qs.filter(to_account=acc), "transfer")
    return bal


def overview(user, d=None):
    s, e = month_bounds(d)
    allq = txs(user)
    mq = allq.filter(transaction_date__date__gte=s, transaction_date__date__lte=e)
    inc, exp = _sum(mq, "income"), _sum(mq, "expense")  # BR-03/BR-04: transfers excluded
    opening = f(Account.objects.filter(user=user).aggregate(s=Sum("opening_balance"))["s"])
    balance = opening + _sum(allq, "income") - _sum(allq, "expense")
    cats = defaultdict(float)
    for t in mq.filter(transaction_type="expense"):
        cats[t.category or "Other"] += f(t.amount)
    return dict(month=s.strftime("%B %Y"), income=inc, expense=exp, balance=balance,
                savings_rate=round((inc - exp) / inc * 100, 1) if inc else 0,
                categories=[{"name": k, "amount": v} for k, v in sorted(cats.items(), key=lambda x: -x[1])])


def monthly_series(user, n=6):
    out, d = [], timezone.localdate().replace(day=1)
    months = []
    for _ in range(n):
        months.append(d); d = (d - timedelta(days=1)).replace(day=1)
    for m in reversed(months):
        s, e = month_bounds(m)
        q = txs(user).filter(transaction_date__date__gte=s, transaction_date__date__lte=e)
        out.append({"month": m.strftime("%b"), "income": _sum(q, "income"), "expense": _sum(q, "expense")})
    return out


def daily_expenses(user, days=7):
    today = timezone.localdate()
    out = []
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        q = txs(user).filter(transaction_type="expense", transaction_date__date=d)
        out.append({"date": d.isoformat(), "label": d.strftime("%a"), "amount": _sum(q, "expense")})
    return out


def budget_summary(user):
    today = timezone.localdate()
    res = []
    for b in Budget.objects.filter(user=user).order_by("-start_date"):
        q = txs(user).filter(transaction_type="expense", transaction_date__date__gte=b.start_date,
                             transaction_date__date__lte=b.end_date)
        spent = _sum(q, "expense")
        cats = []
        for cat, lim in (b.category_limits or {}).items():
            cs = f(q.filter(category=cat).aggregate(s=Sum("amount"))["s"])
            cats.append({"category": cat, "limit": float(lim), "spent": cs, "pct": round(cs / float(lim) * 100, 1) if float(lim) else 0})
        total = f(b.total_limit)
        pct = round(spent / total * 100, 1) if total else 0
        active = b.start_date <= today <= b.end_date
        days_left = max((b.end_date - today).days, 0) if active else 0
        elapsed = max((today - b.start_date).days + 1, 1) if active else 1
        proj = spent / elapsed * ((b.end_date - b.start_date).days + 1) if active else spent
        res.append(dict(id=str(b.id), name=b.name, total_limit=total, spent=spent, remaining=total - spent, pct=pct,
                        start_date=b.start_date, end_date=b.end_date, categories=cats, active=active,
                        days_left=days_left, projected=round(proj), overrun_risk=("high" if proj > total * 1.05 else "medium" if proj > total * .9 else "low") if active else None,
                        thresholds=b.alert_thresholds))
    return res


def notify(user, kind, title, body):
    if not Notification.objects.filter(user=user, kind=kind, title=title, created_at__date=timezone.localdate()).exists():
        Notification.objects.create(user=user, kind=kind, title=title, body=body)


def history_rows(user, exclude=None):
    q = txs(user).filter(transaction_type="expense")
    if exclude:
        q = q.exclude(pk=exclude)
    return [dict(amount=f(t.amount), category=t.category, hour=timezone.localtime(t.transaction_date).hour,
                 merchant=t.merchant_name) for t in q.order_by("-transaction_date")[:500]]


def after_save(tx):
    """Anomaly check + budget threshold alerts for a newly saved expense."""
    if tx.transaction_type != "expense":
        return
    user = tx.user
    res = anom.check(dict(amount=f(tx.amount), category=tx.category, hour=timezone.localtime(tx.transaction_date).hour,
                          merchant=tx.merchant_name), history_rows(user, exclude=tx.pk))
    if res["unusual"] and not AnomalyAlert.objects.filter(transaction=tx).exists():
        AnomalyAlert.objects.create(user=user, transaction=tx, anomaly_score=res["score"], detection_type="statistical+iforest",
                                    explanation=" ".join(res["reasons"]))
        notify(user, "anomaly", "Unusual transaction", f"৳{f(tx.amount):.0f} in {tx.category or 'Other'} looks unusual. Please review.")
    for b in budget_summary(user):
        if not b["active"]:
            continue
        for th in sorted(b["thresholds"], reverse=True):
            if b["pct"] >= th:
                label = "exceeded" if th >= 100 else f"{th}% consumed"
                notify(user, "budget", f"Budget {label}", f"{b['name']}: ৳{b['spent']:.0f} of ৳{b['total_limit']:.0f} used.")
                break


def forecast_for(user, persist=True):
    rows = [(timezone.localtime(t.transaction_date).date(), t.amount) for t in txs(user).filter(transaction_type="expense")]
    series, start = fc.daily_series(rows, days=120)
    r = fc.forecast(series, start, 30)
    d7, d30 = sum(r["daily"][:7]), sum(r["daily"])
    sd = r.get("resid_std", 0) or 0
    interval = {"low": max(0, d30 - 1.64 * sd * 30 ** .5), "high": d30 + 1.64 * sd * 30 ** .5}
    # category trend (last 30d vs previous 30d)
    today = timezone.localdate()
    def cat_sum(a, b):
        c = defaultdict(float)
        for t in txs(user).filter(transaction_type="expense", transaction_date__date__gt=today - timedelta(days=b),
                                  transaction_date__date__lte=today - timedelta(days=a)):
            c[t.category or "Other"] += f(t.amount)
        return c
    cur, prev = cat_sum(0, 30), cat_sum(30, 60)
    trends = sorted([{"category": k, "current": v, "previous": prev.get(k, 0),
                      "change_pct": round((v - prev.get(k, 0)) / prev[k] * 100) if prev.get(k) else None} for k, v in cur.items()],
                    key=lambda x: -x["current"])
    s, e = month_bounds()
    spent_so_far = _sum(txs(user).filter(transaction_type="expense", transaction_date__date__gte=s), "expense")
    days_left = (e - today).days
    month_total = spent_so_far + sum(r["daily"][:max(days_left, 0)])
    income = f(user.profile.monthly_income) or overview(user)["income"]
    risks = []
    for b in budget_summary(user):
        if b["active"]:
            risks.append({"budget": b["name"], "limit": b["total_limit"], "projected": b["projected"],
                          "risk": b["overrun_risk"]})
    out = dict(next_7_days=round(d7), next_30_days=round(d30), interval_30=interval, month_projection=round(month_total),
               estimated_savings=round(income - month_total) if income else None, daily=[round(x) for x in r["daily"]],
               model=r["model"], mae=r["mae"], baseline_mae=r["baseline_mae"], model_version=r["version"],
               trends=trends[:6], budget_risks=risks, currency="BDT", forecast_period="next 30 days",
               disclaimer="Estimate based on your recorded history - not a guarantee.")
    if persist:
        Prediction.objects.create(user=user, prediction_type="spending", predicted_amount=Decimal(str(round(d30, 2))),
                                  prediction_period="30d", confidence_interval=interval, model_version=r["version"])
    return out


def health_score(user):
    o = overview(user)
    sr = max(0, min(o["savings_rate"], 30)) / 30 * 40           # savings rate (40)
    bs = [b for b in budget_summary(user) if b["active"]]
    adh = (30 if not bs else max(0, 30 - max(0, max(b["pct"] for b in bs) - 80) * 1.5))  # budget adherence (30)
    ser = daily_expenses(user, 30)
    vals = [x["amount"] for x in ser]
    mean = sum(vals) / len(vals) if vals else 0
    cv = (sum((v - mean) ** 2 for v in vals) / len(vals)) ** .5 / mean if mean else 1
    cons = max(0, 20 - cv * 8)                                  # spending consistency (20)
    from .models import RecurringTransaction
    rec = f(RecurringTransaction.objects.filter(user=user, active=True, transaction_type="expense").aggregate(s=Sum("amount"))["s"])
    ob = 10 if not o["income"] else max(0, 10 - max(0, rec / o["income"] - .3) * 30)  # obligations (10)
    score = round(sr + adh + cons + ob)
    return dict(score=score, label="Excellent" if score >= 80 else "Good" if score >= 60 else "Fair" if score >= 40 else "Needs attention",
                parts=dict(savings_rate=round(sr), budget_adherence=round(adh), consistency=round(cons), obligations=round(ob)))


def suggestions(user):
    tips, o = [], overview(user)
    for t in forecast_for(user, persist=False)["trends"]:
        if t["change_pct"] and t["change_pct"] >= 25 and t["current"] > 500:
            tips.append(f"{t['category']} spending is up {t['change_pct']}% vs the previous 30 days - consider reviewing it.")
    for b in budget_summary(user):
        if b["active"] and b["pct"] >= 75:
            tips.append(f"'{b['name']}' is {b['pct']:.0f}% used with {b['days_left']} days left.")
    if o["income"] and o["savings_rate"] < 10:
        tips.append("Your savings rate is below 10% this month. Look at discretionary categories first.")
    from .models import RecurringTransaction
    for r in RecurringTransaction.objects.filter(user=user, active=True, next_due__lte=timezone.localdate() + timedelta(days=3)):
        tips.append(f"Upcoming: {r.title} (৳{f(r.amount):.0f}) due {r.next_due:%d %b}.")
    return tips or ["You're on track. Keep recording transactions for sharper insights."]


# ---------- AI assistant: intent routing over real analytics (never invents figures) ----------
def assistant_answer(user, q):
    ql = q.lower()
    o = overview(user)
    today = timezone.localdate()
    cats = {c["name"].lower(): c["amount"] for c in o["categories"]}
    for name, amt in cats.items():
        if name in ql and re.search(r"spend|spent|much|cost", ql):
            share = amt / o["expense"] * 100 if o["expense"] else 0
            return f"You spent ৳{amt:,.0f} on {name} in {o['month']}, {share:.0f}% of your recorded expenses.", {"category": name, "amount": amt}
    if re.search(r"compare|last month|previous", ql):
        m = monthly_series(user, 2)
        if len(m) == 2 and m[0]["expense"]:
            ch = (m[1]["expense"] - m[0]["expense"]) / m[0]["expense"] * 100
            return (f"This month's expenses are ৳{m[1]['expense']:,.0f} vs ৳{m[0]['expense']:,.0f} last month "
                    f"({'up' if ch >= 0 else 'down'} {abs(ch):.0f}%). Note: this month is still in progress."), {"series": m}
        return "I need a full previous month of data to compare.", {}
    if re.search(r"next month|forecast|predict|will i spend", ql):
        p = forecast_for(user, persist=False)
        return (f"Based on your history I estimate about ৳{p['next_30_days']:,.0f} over the next 30 days "
                f"(range ৳{p['interval_30']['low']:,.0f}-৳{p['interval_30']['high']:,.0f}). This is an estimate, not a guarantee."), {}
    m = re.search(r"save\s*(?:৳|tk)?\s*([\d,]+)", ql)
    if m:
        target = float(m.group(1).replace(",", ""))
        disc = [c for c in o["categories"] if c["name"] in ("Shopping", "Entertainment", "Food", "Personal Care")]
        parts = [f"cut ~15% from {c['name']} (≈৳{c['amount'] * .15:,.0f})" for c in disc[:3]]
        gain = sum(c["amount"] * .15 for c in disc[:3])
        return (f"To save ৳{target:,.0f}, you could " + ", ".join(parts) + f". That frees about ৳{gain:,.0f}. "
                "This is general budgeting guidance, not professional financial advice."), {}
    if re.search(r"budget", ql):
        bs = [b for b in budget_summary(user) if b["active"]]
        if bs:
            b = bs[0]
            return f"'{b['name']}': ৳{b['spent']:,.0f} spent of ৳{b['total_limit']:,.0f} ({b['pct']:.0f}%), ৳{b['remaining']:,.0f} remaining, {b['days_left']} days left.", {}
        return "You have no active budget yet. Create one in the Budgets tab.", {}
    if re.search(r"balance|have", ql):
        return f"Your calculated balance across recorded accounts is ৳{o['balance']:,.0f}.", {}
    if re.search(r"income|earn", ql):
        return f"Your recorded income in {o['month']} is ৳{o['income']:,.0f}.", {}
    if re.search(r"health|score", ql):
        h = health_score(user)
        return f"Your financial health score is {h['score']}/100 ({h['label']}).", h
    if re.search(r"spend|expense|total", ql):
        return f"You've spent ৳{o['expense']:,.0f} in {o['month']} against ৳{o['income']:,.0f} income (savings rate {o['savings_rate']}%).", {}
    if re.search(r"invest|stock|loan|tax", ql):
        return "I can't give investment, tax or loan advice - please consult a qualified professional. I can help with budgeting and spending analysis.", {}
    return "I can answer questions about your spending, categories, budgets, forecast, balance and savings. Try: 'How much did I spend on food this month?'", {}
