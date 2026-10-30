# scripts/run_multivendor_local.py
import subprocess
import time
import os
import sys
import urllib.request

def wait_for_server(url, timeout=15):
    start = time.time()
    while time.time() - start < timeout:
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=2) as resp:
                if resp.status == 200:
                    return True
        except:
            time.sleep(0.5)
    return False

def main():
    print("Starting local Express staging server on http://127.0.0.1:8089 ...")
    server = subprocess.Popen(["node", "scripts/test_local_server.js"])
    
    if not wait_for_server("http://127.0.0.1:8089/health", timeout=15):
        print("Server failed to respond to /health in 15 seconds")
        server.kill()
        return 1

    print("Server ready! Running verify_multivendor_suite.py...")
    try:
        env = dict(os.environ)
        env["TEST_BASE_URL"] = "http://127.0.0.1:8089"
        env["PYTHONIOENCODING"] = "utf-8"

        res = subprocess.run([sys.executable, "scripts/verify_multivendor_suite.py"], env=env)
        print("verify_multivendor_suite exit code:", res.returncode)
        return res.returncode
    finally:
        server.kill()

if __name__ == "__main__":
    sys.exit(main())
