# wsgi.py - Production WSGI Entrypoint for Gunicorn
import os
import sys

# Unambiguously load Flask app from app.py
import importlib.util
_app_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app.py")
_spec = importlib.util.spec_from_file_location("app_main", _app_path)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

app = _mod.app
application = app

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
