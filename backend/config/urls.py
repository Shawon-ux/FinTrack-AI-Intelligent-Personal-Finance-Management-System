from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("finance.urls")),
    path("healthz/", lambda r: __import__("django.http").http.JsonResponse({"status": "ok"})),
]
