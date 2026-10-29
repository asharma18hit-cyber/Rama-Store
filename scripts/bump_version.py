# scripts/bump_version.py
import re

VERSION = "20261029_v6_multivendor"

files = [
    "public_web/admin.html",
    "public_web/admin/index.html",
    "templates/admin.html",
    "public_web/store.html",
    "public_web/store/index.html",
    "public_web/vendor.html",
    "public_web/vendor_login.html",
    "public_web/vendor_register.html"
]

for fp in files:
    try:
        with open(fp, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Bump app.js
        content = re.sub(r'/static/js/app\.js(\?v=[a-zA-Z0-9_-]+)?', f'/static/js/app.js?v={VERSION}', content)
        # Bump vendor.js
        content = re.sub(r'/static/js/vendor\.js(\?v=[a-zA-Z0-9_-]+)?', f'/static/js/vendor.js?v={VERSION}', content)
        # Bump style.css
        content = re.sub(r'/static/css/style\.css(\?v=[a-zA-Z0-9_-]+)?', f'/static/css/style.css?v={VERSION}', content)

        with open(fp, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Bumped version query to {VERSION} in {fp}")
    except Exception as e:
        print(f"Skipped {fp}: {e}")
