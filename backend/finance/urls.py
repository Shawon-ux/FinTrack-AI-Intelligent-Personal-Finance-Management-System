from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import admin_api, views as v

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
    path("admin/stats/", admin_api.stats), path("admin/users/", admin_api.users), path("admin/users/<int:pk>/", admin_api.user_detail),
    path("admin/broadcast/", admin_api.broadcast), path("admin/logs/", admin_api.logs),
    path("admin/feedback/", admin_api.feedback_list), path("admin/feedback/<int:pk>/", admin_api.feedback_update),
    path("", include(r.urls)),
]
