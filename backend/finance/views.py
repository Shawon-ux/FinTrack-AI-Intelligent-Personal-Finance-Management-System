import csv, io
from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import transaction as dbtx
from django.db.models import Count, Q, Sum
from django.http import HttpResponse
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes, throttle_classes
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle, UserRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from . import services
from .ml import categorizer, receipt as rcpt
from .models import *
from .serializers import *

User = get_user_model()


def audit(request, action, detail=""):
    AuditLog.objects.create(user=request.user if request.user.is_authenticated else None, action=action, detail=detail[:200],
                            ip=request.META.get("REMOTE_ADDR"))


class AuthThrottle(UserRateThrottle):
    scope = "auth"; rate = "30/min"


DEFAULT_CATS = [("Food", "🍔"), ("Transport", "🚕"), ("Bills", "💡"), ("Shopping", "🛍"), ("Entertainment", "🎬"),
                ("Health", "💊"), ("Education", "📚"), ("Personal Care", "💇"), ("Other", "•")]


def tokens(user):
    r = RefreshToken.for_user(user)
    return {"access": str(r.access_token), "refresh": str(r), "user": UserSer(user).data}


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
@throttle_classes([AuthThrottle])
def register(request):
    s = RegisterSer(data=request.data); s.is_valid(raise_exception=True)
    d = s.validated_data
    u = User.objects.create_user(username=d["email"], email=d["email"], password=d["password"], first_name=d.get("name", ""))
    Profile.objects.create(user=u)
    Account.objects.create(user=u, name="Cash", kind="cash")
    audit(request, "register", u.email)
    request.user = u; audit(request, "login", "after register")
    return Response(tokens(u), status=201)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
@throttle_classes([AuthThrottle])
def login(request):
    from django.contrib.auth import authenticate
    email = (request.data.get("email") or "").lower()
    u = authenticate(username=email, password=request.data.get("password") or "")
    if not u or not u.is_active:
        AuditLog.objects.create(action="login_failed", detail=email[:100], ip=request.META.get("REMOTE_ADDR"))
        return Response({"detail": "Invalid email or password."}, status=401)
    request.user = u; audit(request, "login")
    return Response(tokens(u))


@api_view(["POST"])
def logout(request):
    try:
        RefreshToken(request.data.get("refresh")).blacklist()
    except Exception:
        pass
    audit(request, "logout"); return Response(status=204)


@api_view(["GET", "PATCH"])
def me(request):
    if request.method == "PATCH":
        p = request.user.profile
        s = ProfileSer(p, data=request.data.get("profile", {}), partial=True); s.is_valid(raise_exception=True); s.save()
        if "name" in request.data:
            request.user.first_name = request.data["name"]; request.user.save()
    return Response(UserSer(request.user).data)


@api_view(["DELETE"])
def delete_account(request):
    audit(request, "account_deleted", request.user.email)
    request.user.delete(); return Response(status=204)


@api_view(["GET"])
def export_csv(request):
    resp = HttpResponse(content_type="text/csv"); resp["Content-Disposition"] = "attachment; filename=fintrack_export.csv"
    w = csv.writer(resp); w.writerow(["date", "type", "amount", "currency", "category", "merchant", "payment_method", "description"])
    for t in services.txs(request.user).order_by("-transaction_date"):
        w.writerow([t.transaction_date.isoformat(), t.transaction_type, t.amount, t.currency, t.category, t.merchant_name,
                    t.payment_method, t.description])
    return resp


class OwnedViewSet(viewsets.ModelViewSet):
    """Every query is scoped to request.user (BR-12)."""
    def get_queryset(self):
        return self.model.objects.filter(user=self.request.user)

    def perform_create(self, s):
        s.save(user=self.request.user)


class AccountViewSet(OwnedViewSet):
    model = Account; serializer_class = AccountSer; pagination_class = None


class BudgetViewSet(OwnedViewSet):
    model = Budget; serializer_class = BudgetSer; pagination_class = None

    @action(detail=False)
    def summary(self, request):
        return Response(services.budget_summary(request.user))


class RecurringViewSet(OwnedViewSet):
    model = RecurringTransaction; serializer_class = RecurringSer; pagination_class = None

    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        r = self.get_object()
        Transaction.objects.create(user=request.user, transaction_type=r.transaction_type, amount=r.amount, category=r.category,
                                   description=r.title, transaction_date=timezone.now(), is_recurring=True)
        step = {"weekly": 7, "monthly": 30, "yearly": 365}.get(r.frequency, 30)
        r.next_due += timedelta(days=step); r.last_confirmed = timezone.localdate(); r.save()
        return Response(RecurringSer(r).data)


class GoalViewSet(OwnedViewSet):
    model = SavingsGoal; serializer_class = GoalSer; pagination_class = None

    @action(detail=True, methods=["post"])
    def contribute(self, request, pk=None):
        g = self.get_object(); amt = Decimal(str(request.data.get("amount", 0)))
        if amt <= 0:
            return Response({"detail": "Amount must be positive."}, status=400)
        GoalContribution.objects.create(goal=g, amount=amt); g.saved_amount += amt; g.save()
        if g.saved_amount >= g.target_amount:
            services.notify(request.user, "goal", "Goal reached 🎉", f"You completed '{g.name}'!")
        return Response(GoalSer(g).data)


class TransactionViewSet(OwnedViewSet):
    model = Transaction; serializer_class = TransactionSer

    def get_queryset(self):
        q = Transaction.objects.filter(user=self.request.user, is_deleted=False)
        p = self.request.query_params
        if p.get("type"): q = q.filter(transaction_type=p["type"])
        if p.get("category"): q = q.filter(category=p["category"])
        if p.get("account"): q = q.filter(account_id=p["account"])
        if p.get("from"): q = q.filter(transaction_date__date__gte=p["from"])
        if p.get("to"): q = q.filter(transaction_date__date__lte=p["to"])
        if p.get("q"):
            q = q.filter(Q(description__icontains=p["q"]) | Q(merchant_name__icontains=p["q"]) | Q(category__icontains=p["q"]) | Q(tags__icontains=p["q"]))
        order = p.get("ordering", "-transaction_date")
        if order.lstrip("-") in ("transaction_date", "amount", "created_at"):
            q = q.order_by(order)
        return q

    @dbtx.atomic
    def create(self, request, *a, **kw):
        # idempotent: re-posting the same client UUID updates instead of duplicating (BR-09)
        tid = request.data.get("id")
        inst = Transaction.objects.filter(pk=tid, user=request.user).first() if tid else None
        s = self.get_serializer(inst, data=request.data); s.is_valid(raise_exception=True)
        tx = s.save(user=request.user, is_deleted=False)
        self._post(tx, request, correction=True)
        return Response(self.get_serializer(tx).data, status=200 if inst else 201)

    def perform_update(self, s):
        tx = s.save(); self._post(tx, self.request, correction=True)

    def _post(self, tx, request, correction=False):
        if correction and tx.ai_category and tx.category and tx.ai_category != tx.category:
            if not CategoryFeedback.objects.filter(user=request.user, text=tx.description[:200], corrected=tx.category).exists():
                CategoryFeedback.objects.create(user=request.user, text=(tx.description or tx.merchant_name)[:200],
                                                merchant=tx.merchant_name, predicted=tx.ai_category, corrected=tx.category)
        services.after_save(tx)

    def perform_destroy(self, tx):
        tx.is_deleted = True; tx.save(); audit(self.request, "tx_deleted", str(tx.pk))

    @action(detail=False, methods=["post"], url_path="bulk-sync")
    def bulk_sync(self, request):
        items = request.data.get("transactions", [])
        res = {"synced": [], "failed": []}; created = updated = 0
        for it in items:
            try:
                with dbtx.atomic():
                    tid = it.get("id")
                    inst = Transaction.objects.filter(pk=tid, user=request.user).first()
                    if inst and it.get("_deleted"):
                        inst.is_deleted = True; inst.save(); res["synced"].append(tid); updated += 1; continue
                    if inst and it.get("updated_at") and inst.updated_at.isoformat() > it["updated_at"] and not it.get("force"):
                        res["synced"].append(tid); continue  # server copy newer: last-writer-wins by server time
                    s = TransactionSer(inst, data={k: v for k, v in it.items() if not k.startswith("_") and k not in ("updated_at", "created_at", "sync_status")})
                    s.is_valid(raise_exception=True)
                    tx = s.save(user=request.user, is_deleted=False, sync_status="synced")
                    services.after_save(tx)
                    res["synced"].append(str(tx.pk)); created += 0 if inst else 1; updated += 1 if inst else 0
            except Exception as e:
                res["failed"].append({"id": it.get("id"), "error": str(e)[:150]})
        SyncOperation.objects.create(user=request.user, received=len(items), created=created, updated=updated, failed=len(res["failed"]))
        return Response(res)


@api_view(["GET"])
def sync_status(request):
    return Response({"server_time": timezone.now(), "transactions": services.txs(request.user).count()})


# ------------------ analytics ------------------
@api_view(["GET"])
def analytics_overview(request):
    return Response(dict(services.overview(request.user), daily=services.daily_expenses(request.user, 7),
                         monthly=services.monthly_series(request.user, 6), health=services.health_score(request.user),
                         insights=services.suggestions(request.user)[:3]))


@api_view(["GET"])
def analytics_trends(request):
    return Response(dict(monthly=services.monthly_series(request.user, 6), daily=services.daily_expenses(request.user, 30)))


# ------------------ AI ------------------
class AIThrottle(UserRateThrottle):
    scope = "ai"; rate = "120/hour"


@api_view(["POST"])
@throttle_classes([AIThrottle])
def ai_categorize(request):
    corr = CategoryFeedback.objects.filter(user=request.user)
    return Response(categorizer.predict(request.data.get("text", ""), corr))


@api_view(["POST"])
@throttle_classes([AIThrottle])
def ai_receipt(request):
    text = request.data.get("text")
    if not text and request.FILES.get("image"):
        text = rcpt.ocr_image(request.FILES["image"].read())
        if text is None:
            return Response({"detail": "Server OCR unavailable. Paste/enter the receipt text, or use on-device OCR."}, status=501)
    if not text:
        return Response({"detail": "Provide receipt text or image."}, status=400)
    r = rcpt.parse(text)
    r["duplicate"] = services.txs(request.user).filter(receipt_hash=r["receipt_hash"]).exists()
    r["requires_confirmation"] = True
    if r["merchant"]:
        r["suggested"] = categorizer.predict(r["merchant"] + " " + " ".join(i["name"] for i in r["items"]), CategoryFeedback.objects.filter(user=request.user))
    return Response(r)


@api_view(["GET"])
@throttle_classes([AIThrottle])
def ai_forecast(request):
    return Response(services.forecast_for(request.user))


@api_view(["GET"])
def ai_whatif(request):
    """What-if: reduce a category by X%, or save an extra amount."""
    p = services.forecast_for(request.user, persist=False)
    cat, pct = request.query_params.get("category"), float(request.query_params.get("percent", 10))
    cur = next((t["current"] for t in p["trends"] if t["category"] == cat), 0)
    saved = cur * pct / 100
    return Response({"category": cat, "percent": pct, "monthly_saving": round(saved), "yearly_saving": round(saved * 12),
                     "new_projection": round(p["next_30_days"] - saved)})


@api_view(["POST"])
@throttle_classes([AIThrottle])
def ai_chat(request):
    ans, data = services.assistant_answer(request.user, request.data.get("message", ""))
    return Response({"answer": ans, "data": data, "source": "backend analytics"})


@api_view(["GET"])
def ai_insights(request):
    return Response({"insights": services.suggestions(request.user), "health": services.health_score(request.user)})


@api_view(["POST"])
def ai_feedback(request):
    a = AnomalyAlert.objects.filter(user=request.user, pk=request.data.get("alert_id")).first()
    if a:
        a.status = request.data.get("status", "confirmed_ok"); a.save()
    return Response({"ok": True})


@api_view(["GET"])
def anomalies(request):
    return Response(AnomalySer(AnomalyAlert.objects.filter(user=request.user).order_by("-created_at")[:30], many=True).data)


class NotificationViewSet(OwnedViewSet):
    model = Notification; serializer_class = NotificationSer; pagination_class = None
    http_method_names = ["get", "patch", "delete"]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by("-created_at")[:50] if self.action == "list" \
            else Notification.objects.filter(user=self.request.user)

    @action(detail=False, methods=["post"])
    def read_all(self, request):
        Notification.objects.filter(user=request.user).update(is_read=True); return Response({"ok": True})


@api_view(["GET"])
def categories(request):
    return Response([{"name": n, "icon": i} for n, i in DEFAULT_CATS] + [{"name": "Income", "icon": "💰", "kind": "income"}])


@api_view(["POST"])
def send_feedback(request):
    Feedback.objects.create(user=request.user, message=str(request.data.get("message", ""))[:1000]); return Response({"ok": True})


# ------------------ admin (aggregate only: no personal transaction details) ------------------
class IsAdmin(permissions.BasePermission):
    def has_permission(self, r, v):
        return bool(r.user and r.user.is_authenticated and r.user.is_staff)


@api_view(["GET"])
@permission_classes([IsAdmin])
def admin_stats(request):
    now = timezone.now()
    users = User.objects.filter(is_staff=False)
    return Response({
        "users": users.count(), "active_users": users.filter(is_active=True).count(),
        "premium": Profile.objects.filter(is_premium=True).count(),
        "new_7d": users.filter(date_joined__gte=now - timedelta(days=7)).count(),
        "transactions": Transaction.objects.count(), "tx_24h": Transaction.objects.filter(created_at__gte=now - timedelta(days=1)).count(),
        "anomaly_alerts": AnomalyAlert.objects.count(), "open_alerts": AnomalyAlert.objects.filter(status="open").count(),
        "sync": SyncOperation.objects.aggregate(runs=Count("id"), failed=Sum("failed"), received=Sum("received")),
        "notifications": Notification.objects.count(), "predictions": Prediction.objects.count(),
        "models": list(ModelVersion.objects.values("name", "version", "metrics", "is_active", "trained_on")),
        "open_feedback": Feedback.objects.filter(status="open").count(),
        "signups": [{"date": (now - timedelta(days=i)).date().isoformat(),
                     "count": users.filter(date_joined__date=(now - timedelta(days=i)).date()).count()} for i in range(13, -1, -1)],
    })


@api_view(["GET"])
@permission_classes([IsAdmin])
def admin_users(request):
    rows = [{"id": u.id, "email": u.email, "name": u.first_name, "active": u.is_active, "premium": u.profile.is_premium if hasattr(u, "profile") else False,
             "joined": u.date_joined, "tx_count": u.transactions.count()} for u in User.objects.filter(is_staff=False).order_by("-date_joined")[:100]]
    return Response(rows)


@api_view(["POST"])
@permission_classes([IsAdmin])
def admin_user_update(request, pk):
    u = User.objects.get(pk=pk, is_staff=False)
    if "active" in request.data: u.is_active = bool(request.data["active"]); u.save()
    if "premium" in request.data: Profile.objects.filter(user=u).update(is_premium=bool(request.data["premium"]))
    audit(request, "admin_user_update", f"{u.email} {dict(request.data)}")
    return Response({"ok": True})


@api_view(["GET"])
@permission_classes([IsAdmin])
def admin_logs(request):
    return Response(list(AuditLog.objects.order_by("-created_at").values("action", "detail", "ip", "created_at", "user__email")[:60]))


@api_view(["GET"])
@permission_classes([IsAdmin])
def admin_feedback(request):
    return Response(list(Feedback.objects.order_by("-created_at").values("id", "message", "status", "created_at", "user__email")[:50]))
