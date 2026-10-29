# scripts/find_admin_nav.py
with open("public_web/admin.html", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if "data-tab=" in line:
            print(f"Line {i+1}: {line.strip()}")
