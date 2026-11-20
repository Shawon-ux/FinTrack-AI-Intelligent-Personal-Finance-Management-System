from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import views as v

r = DefaultRouter()
r.register("transactions", v.TransactionViewSet, "transactions")
r.register("accounts", v.AccountViewSet, "accounts")
r.register("budgets", v.BudgetViewSet, "budgets")
r.register("goals", v.GoalViewSet, "goals")
r.register("recurring", v.RecurringViewSet, "recurring")
r.register("notifications", v.NotificationViewSet, "notifications")

urlpatterns = [
    path("auth/register/", v.register), path("auth/login/", v.login), path("auth/logout/", v.logout),
    path("auth/token/refresh/", TokenRefreshView.as_view()),
    path("users/me/", v.me), path("users/me/delete/", v.delete_account), path("users/me/export/", v.export_csv),
    path("categories/", v.categories), path("sync/status/", v.sync_status), path("feedback/", v.send_feedback),
    path("analytics/overview/", v.analytics_overview), path("analytics/trends/", v.analytics_trends),
    path("ai/categorize/", v.ai_categorize), path("ai/receipt/scan/", v.ai_receipt),
    path("ai/predictions/spending/", v.ai_forecast), path("ai/whatif/", v.ai_whatif),
    path("ai/assistant/chat/", v.ai_chat), path("ai/insights/", v.ai_insights), path("ai/feedback/", v.ai_feedback),
    path("ai/anomalies/", v.anomalies),
    path("admin/stats/", v.admin_stats), path("admin/users/", v.admin_users), path("admin/users/<int:pk>/", v.admin_user_update),
    path("admin/logs/", v.admin_logs), path("admin/feedback/", v.admin_feedback),
    path("", include(r.urls)),
]
