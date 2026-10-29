# scripts/patch_app_js.py
import re

print("Patching public_web/static/js/app.js...")

with open("public_web/static/js/app.js", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Clean up corrupted strings in renderCatalogTable
# Replace corrupted symbols
code = code.replace("dYY\ufffd Live on Store", "\U0001f7e2 Live on Store")
code = code.replace("dY\"\' Draft (Hidden)", "\U0001f512 Draft (Hidden)")
code = code.replace('dY"\ufffd ${prod.unit}', '\U0001f4e6 ${prod.unit}')
code = code.replace("dY'_ Save", "\U0001f4be Save")
code = code.replace("\ufffdo?\ufffd,? More", "\u270f\ufe0f Edit")
code = code.replace("dY-`\ufffd,?", "\U0001f5d1\ufe0f Delete")
code = code.replace("dY`?\ufffd,?", "\u2197 Store")

# Also check for other mojibake strings
code = code.replace("dY'?", "\U0001f4be")
code = code.replace("dY-`", "\U0001f5d1\ufe0f")
code = code.replace("dY>''", "'\U0001f4c1'")

# 2. Update openEditModal to populate brand, gst, low-threshold, description, and images
old_open_edit_anchor = "const modal = document.getElementById('edit-product-modal');"
new_open_edit_fields = """    const brandEl = document.getElementById('edit-prod-brand');
    if (brandEl) brandEl.value = product.brand || '';
    
    const gstEl = document.getElementById('edit-prod-gst');
    if (gstEl) gstEl.value = String(product.gst_percent !== undefined ? product.gst_percent : '5');
    
    const lowThreshEl = document.getElementById('edit-prod-low-threshold');
    if (lowThreshEl) lowThreshEl.value = product.low_stock_threshold || 10;
    
    const descEl = document.getElementById('edit-prod-description');
    if (descEl) descEl.value = product.description || '';

    if (typeof renderImagePreviews === 'function') {
        renderImagePreviews('edit');
    }

    const modal = document.getElementById('edit-product-modal');"""

if "edit-prod-brand" not in code:
    code = code.replace(old_open_edit_anchor, new_open_edit_fields, 1)

# 3. Update handleEditFormSubmit to include brand, gst_percent, low_stock_threshold, description in payload
old_edit_payload = """    const payload = {
        product_id: id,
        sku,
        name,
        category_id,
        status,
        purchase_price,"""

new_edit_payload = """    const brand = (document.getElementById('edit-prod-brand')?.value || '').trim();
    const gst_percent = parseFloat(document.getElementById('edit-prod-gst')?.value || 0);
    const low_stock_threshold = parseInt(document.getElementById('edit-prod-low-threshold')?.value || 10, 10);
    const description = (document.getElementById('edit-prod-description')?.value || '').trim();

    const payload = {
        product_id: id,
        sku,
        name,
        brand,
        category_id,
        status,
        purchase_price,
        gst_percent,
        low_stock_threshold,
        description,"""

if "const brand = (document.getElementById('edit-prod-brand')" not in code:
    code = code.replace(old_edit_payload, new_edit_payload, 1)

# 4. Update handleProductFormSubmit to include brand, gst_percent, low_stock_threshold, description
old_prod_payload = "const payload = { sku, name, category_id, status, purchase_price, selling_price, original_price, mrp: original_price, stock, image_url, unit };"
new_prod_payload = """    const brand = (document.getElementById('prod-brand')?.value || '').trim();
    const gst_percent = parseFloat(document.getElementById('prod-gst')?.value || 0);
    const low_stock_threshold = parseInt(document.getElementById('prod-low-threshold')?.value || 10, 10);
    const description = (document.getElementById('prod-description')?.value || '').trim();

    const payload = { sku, name, brand, category_id, status, purchase_price, selling_price, original_price, mrp: original_price, stock, low_stock_threshold, gst_percent, description, image_url, unit };"""

if "prod-brand" not in code or "const brand = (document.getElementById('prod-brand')" not in code:
    code = code.replace(old_prod_payload, new_prod_payload, 1)

with open("public_web/static/js/app.js", "w", encoding="utf-8") as f:
    f.write(code)

print("public_web/static/js/app.js patched successfully!")
