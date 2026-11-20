from rest_framework.views import exception_handler

def handler(exc, ctx):
    """Consistent error envelope: {"error": {"code", "message", "details"}}"""
    resp = exception_handler(exc, ctx)
    if resp is None:
        return None
    detail = resp.data
    msg = detail.get("detail") if isinstance(detail, dict) and "detail" in detail else "Request failed"
    resp.data = {"error": {"code": resp.status_code, "message": str(msg), "details": detail}}
    return resp
