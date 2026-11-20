"""Administrator API. Aggregate / account-level data only - never private transaction content (BR-12, privacy rule)."""
import secrets
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import connection
from django.db.models import Count, Max, Q, Sum
from django.utils import timezone
from rest_framework import permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import (Account, AnomalyAlert, AuditLog, Broadcast, Budget, Feedback, ModelVersion, Notification, Prediction,
                     Profile, RecurringTransaction, SavingsGoal, SyncOperation, Transaction)

User = get_user_model()


class IsAdmin(permissions.BasePermission):
    def has_permission(self, r, v):
        return bool(r.user and r.user.is_authenticated and r.user.is_staff)


def _audit(request, action, detail=""):
    AuditLog.objects.create(user=request.user, action=action, detail=str(detail)[:200], ip=request.META.get("REMOTE_ADDR"))


def _role(u):
    return "admin" if u.is_staff else "premium" if getattr(getattr(u, "profile", None), "is_premium", False) else "user"


def _user_row(u):
    return {"id": u.id, "email": u.email, "name": u.first_name, "role": _role(u), "active": u.is_active, "joined": u.date_joined,
            "last_login": u.last_login, "tx_count": getattr(u, "tx_count", None), "last_tx": getattr(u, "last_tx", None)}


@api_view(["GET"])
@permission_classes([IsAdmin])
def stats(request):
    now = timezone.now()
    users = User.objects.filter(is_staff=False)
    day = lambda i: (now - timedelta(days=i)).date()
    dates = [day(i) for i in range(13, -1, -1)]
    signups = {d["date_joined__date"]: d["n"] for d in users.filter(date_joined__date__gte=dates[0]).values("date_joined__date").annotate(n=Count("id"))}
    txs = {d["created_at__date"]: d["n"] for d in Transaction.objects.filter(created_at__date__gte=dates[0]).values("created_at__date").annotate(n=Count("id"))}
    sync = SyncOperation.objects.aggregate(runs=Count("id"), failed=Sum("failed"), received=Sum("received"))
    received, failed = sync["received"] or 0, sync["failed"] or 0
    notes = Notification.objects.aggregate(total=Count("id"), read=Count("id", filter=Q(is_read=True)))
    try:
        connection.ensure_connection(); db_ok = True
    except Exception:
        db_ok = False
    prev7 = users.filter(date_joined__gte=now - timedelta(days=14), date_joined__lt=now - timedelta(days=7)).count()
    new7 = users.filter(date_joined__gte=now - timedelta(days=7)).count()
    return Response({
        "users": users.count(), "active_users": users.filter(is_active=True).count(), "disabled": users.filter(is_active=False).count(),
        "premium": Profile.objects.filter(is_premium=True, user__is_staff=False).count(), "admins": User.objects.filter(is_staff=True).count(),
        "new_7d": new7, "new_prev_7d": prev7,
        "dau": users.filter(last_login__gte=now - timedelta(days=1)).count(), "wau": users.filter(last_login__gte=now - timedelta(days=7)).count(),
        "mau": users.filter(last_login__gte=now - timedelta(days=30)).count(),
        "transactions": Transaction.objects.count(), "tx_24h": Transaction.objects.filter(created_at__gte=now - timedelta(days=1)).count(),
        "anomaly_alerts": AnomalyAlert.objects.count(), "open_alerts": AnomalyAlert.objects.filter(status="open").count(),
        "sync": {**sync, "fail_rate": round(failed / received * 100, 1) if received else 0},
        "notifications": {**notes, "read_rate": round(notes["read"] / notes["total"] * 100) if notes["total"] else 0, "broadcasts": Broadcast.objects.count()},
        "predictions": Prediction.objects.count(),
        "open_feedback": Feedback.objects.filter(status="open").count(),
        "models": list(ModelVersion.objects.values("name", "version", "metrics", "is_active", "trained_on")),
        "signups": [{"date": d.isoformat(), "count": signups.get(d, 0)} for d in dates],
        "tx_series": [{"date": d.isoformat(), "count": txs.get(d, 0)} for d in dates],
        "top_categories": list(Transaction.objects.exclude(category="").values("category").annotate(n=Count("id")).order_by("-n")[:6]),
        "activity": list(AuditLog.objects.order_by("-created_at").values("action", "detail", "created_at", "user__email")[:8]),
        "health": {"database": db_ok, "ml_models": ModelVersion.objects.filter(is_active=True).count(), "server_time": now},
    })


@api_view(["GET", "POST"])
@permission_classes([IsAdmin])
def users(request):
    if request.method == "POST":  # create a new account (optionally premium / admin)
        email, pw = (request.data.get("email") or "").strip().lower(), request.data.get("password") or ""
        role = request.data.get("role", "user")
        if "@" not in email:
            return Response({"detail": "Enter a valid email."}, status=400)
        if len(pw) < 8:
            return Response({"detail": "Password must be at least 8 characters."}, status=400)
        if User.objects.filter(username__iexact=email).exists():
            return Response({"detail": "Email already registered."}, status=400)
        u = User.objects.create_user(username=email, email=email, password=pw, first_name=request.data.get("name", ""), is_staff=role == "admin")
        Profile.objects.create(user=u, is_premium=role == "premium")
        Account.objects.create(user=u, name="Cash", kind="cash")
        _audit(request, "admin_create_user", f"{email} ({role})")
        return Response(_user_row(u), status=201)
    q, status, plan = request.query_params.get("q", ""), request.query_params.get("status", ""), request.query_params.get("plan", "")
    qs = User.objects.all().select_related("profile").annotate(tx_count=Count("transactions", distinct=True), last_tx=Max("transactions__created_at"))
    if q:
        qs = qs.filter(Q(email__icontains=q) | Q(first_name__icontains=q))
    if status == "active": qs = qs.filter(is_active=True)
    if status == "disabled": qs = qs.filter(is_active=False)
    if plan == "premium": qs = qs.filter(profile__is_premium=True)
    if plan == "free": qs = qs.filter(profile__is_premium=False, is_staff=False)
    if plan == "admin": qs = qs.filter(is_staff=True)
    total = qs.count()
    return Response({"total": total, "results": [_user_row(u) for u in qs.order_by("-date_joined")[:200]]})


@api_view(["GET", "POST", "DELETE"])
@permission_classes([IsAdmin])
def user_detail(request, pk):
    try:
        u = User.objects.select_related("profile").get(pk=pk)
    except User.DoesNotExist:
        return Response({"detail": "Not found."}, status=404)
    me = request.user.pk == u.pk
    if request.method == "DELETE":
        if me: return Response({"detail": "You cannot delete your own account here."}, status=400)
        _audit(request, "admin_delete_user", u.email); u.delete(); return Response(status=204)
    if request.method == "POST":
        d, extra = request.data, {}
        if "active" in d:
            if me and not d["active"]: return Response({"detail": "You cannot disable yourself."}, status=400)
            u.is_active = bool(d["active"])
        if "premium" in d: Profile.objects.update_or_create(user=u, defaults={"is_premium": bool(d["premium"])})
        if "admin" in d:
            if me and not d["admin"]: return Response({"detail": "You cannot remove your own admin role."}, status=400)
            u.is_staff = bool(d["admin"])
        if d.get("reset_password"):
            tmp = secrets.token_urlsafe(9); u.set_password(tmp); extra["temp_password"] = tmp
        u.save(); _audit(request, "admin_user_update", f"{u.email} {[k for k in d]}")
        return Response({"ok": True, **extra})
    p = getattr(u, "profile", None)
    return Response({
        **_user_row(u), "currency": p.currency if p else "BDT", "onboarded": p.onboarded if p else False,
        "ai_consent": p.ai_learning_consent if p else False,
        "counts": {"transactions": u.transactions.count(), "accounts": u.accounts.count(), "budgets": u.budgets.count(),
                   "goals": u.goals.count(), "recurring": u.recurring.count(), "alerts_open": u.anomalies.filter(status="open").count(),
                   "notifications": u.notifications.count(), "sync_runs": SyncOperation.objects.filter(user=u).count(),
                   "sync_failed": SyncOperation.objects.filter(user=u).aggregate(s=Sum("failed"))["s"] or 0},
        "first_tx": u.transactions.order_by("created_at").values_list("created_at", flat=True).first(),
        "activity": list(AuditLog.objects.filter(user=u).order_by("-created_at").values("action", "detail", "ip", "created_at")[:25]),
    })


@api_view(["GET", "POST"])
@permission_classes([IsAdmin])
def broadcast(request):
    if request.method == "GET":
        return Response(list(Broadcast.objects.order_by("-created_at").values("id", "title", "body", "audience", "recipients", "created_at")[:40]))
    title, body, aud = (request.data.get("title") or "").strip(), (request.data.get("body") or "").strip(), request.data.get("audience", "all")
    if not title or not body:
        return Response({"detail": "Title and message are required."}, status=400)
    qs = User.objects.filter(is_active=True, is_staff=False)
    if aud == "premium": qs = qs.filter(profile__is_premium=True)
    elif aud == "free": qs = qs.filter(profile__is_premium=False)
    elif aud == "user": qs = qs.filter(pk=request.data.get("user_id"))
    elif aud != "all": return Response({"detail": "Unknown audience."}, status=400)
    ids = list(qs.values_list("pk", flat=True))
    Notification.objects.bulk_create([Notification(user_id=i, kind="announcement", title=title[:80], body=body) for i in ids])
    Broadcast.objects.create(title=title[:80], body=body, audience=aud, recipients=len(ids), created_by=request.user)
    _audit(request, "admin_broadcast", f"{aud}: {title[:60]} -> {len(ids)}")
    return Response({"recipients": len(ids)}, status=201)


@api_view(["GET"])
@permission_classes([IsAdmin])
def logs(request):
    q = request.query_params.get("q", "")
    qs = AuditLog.objects.order_by("-created_at")
    if q: qs = qs.filter(Q(action__icontains=q) | Q(detail__icontains=q) | Q(user__email__icontains=q))
    return Response(list(qs.values("action", "detail", "ip", "created_at", "user__email")[:120]))


@api_view(["GET"])
@permission_classes([IsAdmin])
def feedback_list(request):
    qs = Feedback.objects.order_by("-created_at")
    if request.query_params.get("status"): qs = qs.filter(status=request.query_params["status"])
    return Response(list(qs.values("id", "message", "status", "reply", "replied_at", "created_at", "user__email")[:100]))


@api_view(["POST"])
@permission_classes([IsAdmin])
def feedback_update(request, pk):
    try:
        f = Feedback.objects.select_related("user").get(pk=pk)
    except Feedback.DoesNotExist:
        return Response({"detail": "Not found."}, status=404)
    if request.data.get("status") in ("open", "in_progress", "resolved"): f.status = request.data["status"]
    reply = (request.data.get("reply") or "").strip()
    if reply:
        f.reply, f.replied_at = reply, timezone.now()
        Notification.objects.create(user=f.user, kind="support", title="Reply from FinTrack support", body=reply)
    f.save(); _audit(request, "admin_feedback", f"#{f.pk} {f.status}")
    return Response({"ok": True})
