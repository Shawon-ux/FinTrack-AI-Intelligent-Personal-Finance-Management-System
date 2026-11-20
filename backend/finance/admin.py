from django.contrib import admin
from . import models

for m in [models.Profile, models.Account, models.Budget, models.SavingsGoal, models.RecurringTransaction, models.Notification,
          models.Prediction, models.AnomalyAlert, models.ModelVersion, models.AuditLog, models.SyncOperation, models.Feedback]:
    admin.site.register(m)
# Transactions deliberately registered read-only-ish: admins should not browse private financial records by default.
@admin.register(models.Transaction)
class TxAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "transaction_type", "currency", "transaction_date")
    exclude = ("description", "merchant_name")
    def has_change_permission(self, request, obj=None): return False
    def has_add_permission(self, request): return False
