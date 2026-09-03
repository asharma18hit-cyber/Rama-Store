# app/__init__.py
# Expose app so both 'gunicorn app:app' and 'gunicorn wsgi:app' resolve cleanly
try:
    from wsgi import app
except Exception:
    pass
