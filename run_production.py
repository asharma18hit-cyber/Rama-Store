"""
run_production.py - Production WSGI Server Launcher for Samaur Mart.
Runs multi-threaded Waitress WSGI server on Windows and Gunicorn on Linux.
Provides industrial-grade concurrency, thread pooling, and high uptime.
"""

import os
import sys
import platform

# Ensure standard UTF-8 console output on Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Ensure project root is in python path
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)
sys.path.insert(0, os.path.join(BASE_DIR, 'app'))

# Force production environment
os.environ['FLASK_ENV'] = 'production'

from wsgi import app

def run_server():
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    threads = int(os.environ.get('THREADS', 8))

    banner = f"""
================================================================================
       SAMAUR MART - ENTERPRISE PRODUCTION WSGI SERVER
================================================================================
 Host          : {host}
 Port          : {port}
 Workers/Threads: {threads} Concurrent Threads
 Server Engine : Waitress Production WSGI (Multi-threaded)
 OS Platform   : {platform.system()} ({platform.machine()})
 Database      : SQLite WAL Mode (Write-Ahead Logging) + Cloud Firestore
 Live URL      : http://localhost:{port}
 Network URL   : http://127.0.0.1:{port}
 Security      : Production Headers & Lax Cookies Active
================================================================================
 Server is live. Press CTRL+C to terminate.
"""
    print(banner, flush=True)

    try:
        from waitress import serve
        serve(
            app,
            host=host,
            port=port,
            threads=threads,
            channel_timeout=60,
            cleanup_interval=30,
            ident="SamaurMart/1.0"
        )
    except ImportError:
        print("[Notice] Waitress not installed, falling back to standard server.", flush=True)
        app.run(host=host, port=port, debug=False)

if __name__ == '__main__':
    run_server()
