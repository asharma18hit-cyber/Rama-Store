# scripts/patch_storefront_vendor_badge.py

with open("public_web/static/js/app.js", "r", encoding="utf-8") as f:
    text = f.read()

target = """                <div class="product-card-body">
                    <span class="product-card-category">${prod.category || 'General'}</span>
                    <h3 class="product-card-title">${prod.name}</h3>"""

replacement = """                <div class="product-card-body">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                        <span class="product-card-category">${prod.category || 'General'}</span>
                        <span style="font-size: 0.72rem; color: #b8892b; font-weight: 600; max-width: 120px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="Sold by ${prod.vendor_name || 'Rama Store'}">🏷️ ${prod.vendor_name || 'Rama Store'}</span>
                    </div>
                    <h3 class="product-card-title">${prod.name}</h3>"""

assert target in text, "Target not found in app.js"
text = text.replace(target, replacement, 1)

with open("public_web/static/js/app.js", "w", encoding="utf-8") as f:
    f.write(text)

print("Successfully injected vendor badge into storefront product cards!")
