# scripts/run_full_local_audit.py
import subprocess
import time
import os
import sys

def main():
    print("Starting local Express staging server on http://127.0.0.1:8089 ...")
    server = subprocess.Popen(["node", "scripts/test_local_server.js"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)

    try:
        env = dict(os.environ)
        env["TEST_BASE_URL"] = "http://127.0.0.1:8089"
        env["PYTHONIOENCODING"] = "utf-8"

        print("Executing verify_deep_production_suite.py against local server...")
        res = subprocess.run([sys.executable, "scripts/verify_deep_production_suite.py"], env=env)
        print("verify_deep_production_suite exit code:", res.returncode)
        return res.returncode
    finally:
        server.kill()

if __name__ == "__main__":
    sys.exit(main())
