import uuid
from decimal import Decimal
from django.conf import settings
from django.db import models
from django.db.models import Q

U = settings.AUTH_USER_MODEL


class Profile(models.Model):
    user = models.OneToOneField(U, on_delete=models.CASCADE, related_name="profile")
    currency = models.CharField(max_length=3, default="BDT")
    timezone = models.CharField(max_length=40, default="Asia/Dhaka")
    monthly_income = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    savings_target = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    employment_type = models.CharField(max_length=40, blank=True)
    is_premium = models.BooleanField(default=False)
    onboarded = models.BooleanField(default=False)
    avatar = models.TextField(blank=True)  # small resized JPEG as a data URL (set by the client); private to the user
    ai_learning_consent = models.BooleanField(default=False)  # consent for anonymised training use


class Account(models.Model):
    KINDS = [("cash", "Cash"), ("bank", "Bank"), ("wallet", "Mobile wallet"), ("card", "Card")]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="accounts")
    name = models.CharField(max_length=60)
    kind = models.CharField(max_length=10, choices=KINDS, default="cash")
    opening_balance = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    currency = models.CharField(max_length=3, default="BDT")
    created_at = models.DateTimeField(auto_now_add=True)


class Category(models.Model):
    """user=None -> system category visible to everyone."""
    user = models.ForeignKey(U, null=True, blank=True, on_delete=models.CASCADE)
    name = models.CharField(max_length=40)
    kind = models.CharField(max_length=7, default="expense")  # expense | income
    icon = models.CharField(max_length=8, default="•")

    class Meta:
        verbose_name_plural = "categories"


class Transaction(models.Model):
    TYPES = [("income", "Income"), ("expense", "Expense"), ("transfer", "Transfer")]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)  # client generated for offline sync
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="transactions")
    account = models.ForeignKey(Account, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    to_account = models.ForeignKey(Account, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    category = models.CharField(max_length=40, blank=True)
    subcategory = models.CharField(max_length=40, blank=True)
    transaction_type = models.CharField(max_length=8, choices=TYPES)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    currency = models.CharField(max_length=3, default="BDT")
    description = models.TextField(blank=True)
    merchant_name = models.CharField(max_length=80, blank=True)
    payment_method = models.CharField(max_length=20, default="cash")
    transaction_date = models.DateTimeField()
    tags = models.CharField(max_length=120, blank=True)
    is_recurring = models.BooleanField(default=False)
    ai_category = models.CharField(max_length=40, blank=True)  # what the model predicted (for feedback)
    ai_confidence = models.FloatField(null=True, blank=True)
    receipt_hash = models.CharField(max_length=64, blank=True, db_index=True)
    sync_status = models.CharField(max_length=10, default="synced")
    is_deleted = models.BooleanField(default=False)  # soft delete (audited)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [models.Index(fields=["user", "-transaction_date"]), models.Index(fields=["user", "category"])]
        constraints = [models.CheckConstraint(condition=Q(amount__gt=0), name="tx_amount_positive")]


def default_thresholds():
    return [50, 75, 90, 100]


class Budget(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="budgets")
    name = models.CharField(max_length=60)
    total_limit = models.DecimalField(max_digits=18, decimal_places=2)
    start_date = models.DateField()
    end_date = models.DateField()
    category_limits = models.JSONField(default=dict, blank=True)  # {"Food": 6000}
    alert_thresholds = models.JSONField(default=default_thresholds)
    created_at = models.DateTimeField(auto_now_add=True)


class SavingsGoal(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="goals")
    name = models.CharField(max_length=60)
    target_amount = models.DecimalField(max_digits=18, decimal_places=2)
    saved_amount = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    target_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class GoalContribution(models.Model):
    goal = models.ForeignKey(SavingsGoal, on_delete=models.CASCADE, related_name="contributions")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)


class RecurringTransaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="recurring")
    title = models.CharField(max_length=60)
    transaction_type = models.CharField(max_length=8, default="expense")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    category = models.CharField(max_length=40, blank=True)
    frequency = models.CharField(max_length=10, default="monthly")  # weekly | monthly | yearly
    next_due = models.DateField()
    active = models.BooleanField(default=True)
    last_confirmed = models.DateField(null=True, blank=True)


class Notification(models.Model):
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="notifications")
    kind = models.CharField(max_length=20)
    title = models.CharField(max_length=80)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)


class Prediction(models.Model):
    user = models.ForeignKey(U, on_delete=models.CASCADE)
    prediction_type = models.CharField(max_length=30)
    predicted_amount = models.DecimalField(max_digits=18, decimal_places=2)
    currency = models.CharField(max_length=3, default="BDT")
    prediction_period = models.CharField(max_length=30)
    confidence_interval = models.JSONField(default=dict)
    model_version = models.CharField(max_length=40)
    generated_at = models.DateTimeField(auto_now_add=True)


class AnomalyAlert(models.Model):
    user = models.ForeignKey(U, on_delete=models.CASCADE, related_name="anomalies")
    transaction = models.ForeignKey(Transaction, on_delete=models.CASCADE, related_name="anomalies")
    anomaly_score = models.FloatField()
    detection_type = models.CharField(max_length=30)
    explanation = models.TextField()
    status = models.CharField(max_length=12, default="open")  # open | confirmed_ok | confirmed_issue
    created_at = models.DateTimeField(auto_now_add=True)


class CategoryFeedback(models.Model):
    """User corrections -> personalised learning (per user) + consented training data."""
    user = models.ForeignKey(U, on_delete=models.CASCADE)
    text = models.CharField(max_length=200)
    merchant = models.CharField(max_length=80, blank=True)
    predicted = models.CharField(max_length=40, blank=True)
    corrected = models.CharField(max_length=40)
    created_at = models.DateTimeField(auto_now_add=True)


class ModelVersion(models.Model):
    name = models.CharField(max_length=40)
    version = models.CharField(max_length=20)
    metrics = models.JSONField(default=dict)
    is_active = models.BooleanField(default=True)
    trained_on = models.CharField(max_length=40, default="synthetic")
    created_at = models.DateTimeField(auto_now_add=True)


class AuditLog(models.Model):
    user = models.ForeignKey(U, null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=60)
    detail = models.CharField(max_length=200, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class SyncOperation(models.Model):
    user = models.ForeignKey(U, on_delete=models.CASCADE)
    received = models.IntegerField(default=0)
    created = models.IntegerField(default=0)
    updated = models.IntegerField(default=0)
    failed = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)


class Feedback(models.Model):
    user = models.ForeignKey(U, on_delete=models.CASCADE)
    message = models.TextField()
    status = models.CharField(max_length=10, default="open")
    created_at = models.DateTimeField(auto_now_add=True)
