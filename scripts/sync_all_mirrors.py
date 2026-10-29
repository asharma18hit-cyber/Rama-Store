# scripts/sync_all_mirrors.py
import shutil
import os

copies = [
    ("public_web/admin.html", "public_web/admin/index.html"),
    ("public_web/admin.html", "templates/admin.html"),
    ("public_web/admin_login.html", "public_web/admin/login/index.html"),
    ("public_web/admin_login.html", "templates/admin_login.html"),
    ("public_web/vendor.html", "public_web/vendor/index.html"),
    ("public_web/vendor.html", "templates/vendor.html"),
    ("public_web/vendor_login.html", "public_web/vendor/login/index.html"),
    ("public_web/vendor_login.html", "templates/vendor_login.html"),
    ("public_web/vendor_register.html", "public_web/vendor/register/index.html"),
    ("public_web/vendor_register.html", "templates/vendor_register.html"),
    ("public_web/static/js/app.js", "static/js/app.js"),
    ("public_web/static/js/vendor.js", "static/js/vendor.js"),
    ("public_web/static/css/style.css", "static/css/style.css")
]

for src, dst in copies:
    if os.path.exists(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        print(f"Copied {src} -> {dst} ({os.path.getsize(dst)} bytes)")
    else:
        print(f"Warning: {src} does not exist!")

print("All mirror files synchronized perfectly!")
