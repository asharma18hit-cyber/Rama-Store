# scripts/find_sidebar_links.py
with open("public_web/admin.html", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if "tab-inventory" in line or "tab-dashboard" in line:
            print(f"Line {i+1}: {line.strip()[:100]}")
