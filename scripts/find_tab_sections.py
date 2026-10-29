# scripts/find_tab_sections.py
with open("public_web/admin.html", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if '<section id="tab-' in line:
            print(f"Line {i+1}: {line.strip()}")
