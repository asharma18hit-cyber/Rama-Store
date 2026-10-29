# scripts/fix_toolbar.py
with open("public_web/admin.html", "r", encoding="utf-8") as f:
    text = f.read()

import re

# Replace the single Register button with Export CSV + Bulk Import CSV + Register New Item
pattern = re.compile(r'<button type="button" class="btn btn-primary" onclick="scrollToProductForm\(\)".*?Register New Item\s*</button>', re.DOTALL)

replacement = """<button type="button" class="btn btn-secondary" onclick="downloadCatalogCsv()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.15); cursor: pointer;" title="Download active catalog as CSV">
                                \U0001f4e5 Export CSV
                            </button>
                            <button type="button" class="btn btn-secondary" onclick="openCsvImportModal()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.15); cursor: pointer;" title="Bulk import products from CSV">
                                \U0001f4e4 Bulk Import CSV
                            </button>
                            <button type="button" class="btn btn-primary" onclick="scrollToProductForm()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1.25rem; border-radius: 8px; box-shadow: 0 4px 14px rgba(184, 137, 43, 0.35);">
                                \u2795 Register New Item
                            </button>"""

text = pattern.sub(replacement, text, count=1)

with open("public_web/admin.html", "w", encoding="utf-8") as f:
    f.write(text)

print("Toolbar updated successfully!")
