from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import *
from . import services

User = get_user_model()


class ProfileSer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        exclude = ["user"]
        read_only_fields = ["is_premium"]


class UserSer(serializers.ModelSerializer):
    profile = ProfileSer()
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "email", "first_name", "profile", "role"]

    def get_role(self, u):
        return "admin" if u.is_staff else "premium" if u.profile.is_premium else "user"


class RegisterSer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    name = serializers.CharField(required=False, allow_blank=True)

    def validate_email(self, v):
        if User.objects.filter(username__iexact=v).exists():
            raise serializers.ValidationError("Email already registered.")
        return v.lower()

    def validate_password(self, v):
        validate_password(v); return v


class AccountSer(serializers.ModelSerializer):
    balance = serializers.SerializerMethodField()

    class Meta:
        model = Account
        fields = ["id", "name", "kind", "opening_balance", "currency", "balance"]

    def get_balance(self, a):
        return services.account_balance(a)


class TransactionSer(serializers.ModelSerializer):
    id = serializers.UUIDField(required=False)
    has_alert = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        exclude = ["user", "is_deleted"]
        read_only_fields = ["created_at", "updated_at", "sync_status"]

    def get_has_alert(self, t):
        return t.anomalies.filter(status="open").exists() if hasattr(t, "anomalies") else False

    def validate(self, d):
        if d.get("transaction_type") == "transfer":
            if not d.get("account") or not d.get("to_account") or d["account"] == d["to_account"]:
                raise serializers.ValidationError("Transfers need two different accounts.")
        return d

    def validate_amount(self, v):
        if v <= 0:
            raise serializers.ValidationError("Amount must be positive.")
        return v


class BudgetSer(serializers.ModelSerializer):
    class Meta:
        model = Budget
        exclude = ["user"]

    def validate(self, d):
        if d.get("end_date") and d.get("start_date") and d["end_date"] < d["start_date"]:
            raise serializers.ValidationError("end_date before start_date.")
        return d


class GoalSer(serializers.ModelSerializer):
    monthly_required = serializers.SerializerMethodField()
    pct = serializers.SerializerMethodField()

    class Meta:
        model = SavingsGoal
        exclude = ["user"]

    def get_pct(self, g):
        return round(float(g.saved_amount) / float(g.target_amount) * 100, 1) if g.target_amount else 0

    def get_monthly_required(self, g):
        from django.utils import timezone
        if not g.target_date:
            return None
        months = max((g.target_date.year - timezone.localdate().year) * 12 + g.target_date.month - timezone.localdate().month, 1)
        return round(max(float(g.target_amount - g.saved_amount), 0) / months)


class RecurringSer(serializers.ModelSerializer):
    class Meta:
        model = RecurringTransaction
        exclude = ["user"]


class NotificationSer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        exclude = ["user"]


class AnomalySer(serializers.ModelSerializer):
    transaction_detail = TransactionSer(source="transaction", read_only=True)

    class Meta:
        model = AnomalyAlert
        exclude = ["user"]
