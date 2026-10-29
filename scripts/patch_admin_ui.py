# scripts/patch_admin_ui.py
import os
import shutil
import re

print("Starting Admin UI and Controller Enhancement...")

# 1. Update public_web/admin.html
admin_path = os.path.join("public_web", "admin.html")
with open(admin_path, "r", encoding="utf-8") as f:
    admin_html = f.read()

# Fix table headers and toolbar buttons
toolbar_search = '''                        <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                            <div class="inventory-search">
                                <input type="text" id="catalog-search" placeholder="Search inventory SKU or name..." oninput="loadCatalog()" style="padding: 0.6rem 1.25rem; font-size: 0.88rem; border-radius: 20px; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--admin-border); color: #fff; width: 250px;">
                            </div>
                            <button type="button" class="btn btn-primary" onclick="scrollToProductForm()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1.25rem; border-radius: 8px; box-shadow: 0 4px 14px rgba(184, 137, 43, 0.35);">
                                \u2795 Register New Item
                            </button>
                        </div>'''

new_toolbar = '''                        <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                            <div class="inventory-search">
                                <input type="text" id="catalog-search" placeholder="Search SKU, product, brand..." oninput="loadCatalog()" style="padding: 0.6rem 1.25rem; font-size: 0.88rem; border-radius: 20px; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--admin-border); color: #fff; width: 220px;">
                            </div>
                            <button type="button" class="btn btn-secondary" onclick="downloadCatalogCsv()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.15); cursor: pointer;">
                                \U0001f4e5 Export CSV
                            </button>
                            <button type="button" class="btn btn-secondary" onclick="openCsvImportModal()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.15); cursor: pointer;">
                                \U0001f4e4 Bulk Import CSV
                            </button>
                            <button type="button" class="btn btn-primary" onclick="scrollToProductForm()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1.25rem; border-radius: 8px; box-shadow: 0 4px 14px rgba(184, 137, 43, 0.35); cursor: pointer;">
                                \u2795 Register New Item
                            </button>
                        </div>'''

if "downloadCatalogCsv()" not in admin_html:
    # Look for the inventory-search container to replace
    pattern = re.compile(r'<div style="display: flex; gap: 0\.75rem; align-items: center; flex-wrap: wrap;">\s*<div class="inventory-search">.*?</div>\s*<button type="button" class="btn btn-primary" onclick="scrollToProductForm()".*?</button>\s*</div>', re.DOTALL)
    admin_html = pattern.sub(new_toolbar, admin_html, count=1)

# Fix corrupted symbols in the table headers
admin_html = re.sub(r'MRP \(.*?\)', 'MRP (\u20B9)', admin_html)
admin_html = re.sub(r'Selling Price \(.*?\)', 'Selling Price (\u20B9)', admin_html)
admin_html = re.sub(r'Purchase Price \(.*?\)', 'Purchase Price (\u20B9)', admin_html)
admin_html = admin_html.replace('dYY\ufffd Live on Store', '\U0001f7e2 Live on Store')
admin_html = admin_html.replace('dY"\' Drafts', '\U0001f512 Drafts')
admin_html = admin_html.replace('\ufffds\ufffd,? Low Stock', '\u26a0\ufe0f Low Stock')

# Upgrade #product-form-card with Brand, GST, Low Stock Alert, Images Upload Dropzone, Description
old_form_grid_needle = '<div class="product-form-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">'
new_form_grid = '''<div class="product-form-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                                    <div class="auth-input-group">
                                        <label for="prod-sku">Unique SKU / Barcode ID *</label>
                                        <input type="text" id="prod-sku" required placeholder="e.g. RAMA-ATT-001">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-brand">Brand / Manufacturer</label>
                                        <input type="text" id="prod-brand" placeholder="e.g. Aashirvaad, Amul, MDH">
                                    </div>
                                    <div class="auth-input-group" style="grid-column: span 2;">
                                        <label for="prod-name">Product Name *</label>
                                        <input type="text" id="prod-name" required placeholder="e.g. Superior Shudh Chakki Atta (5 kg)">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-category">Category Tree Node *</label>
                                        <select id="prod-category" required>
                                            <option value="">Select category...</option>
                                        </select>
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-status">Publish Status *</label>
                                        <select id="prod-status" required>
                                            <option value="published" selected>\U0001f7e2 Published (Live on Storefront)</option>
                                            <option value="draft">\U0001f512 Draft (Hidden)</option>
                                        </select>
                                    </div>
                                    
                                    <!-- Direct Photo Upload Dropzone -->
                                    <div class="auth-input-group" style="grid-column: span 2;">
                                        <label>Product Image (Direct Upload from Computer or Instant CDN)</label>
                                        <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                                            <label for="prod-file-input" class="btn btn-secondary" style="cursor: pointer; display: inline-flex; align-items: center; gap: 6px; padding: 0.55rem 1rem; font-size: 0.88rem; background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px;">
                                                \U0001f4f7 Choose Images from Computer
                                                <input type="file" id="prod-file-input" accept="image/png,image/jpeg,image/webp,image/gif" multiple style="display: none;" onchange="handleProductImageFiles(this.files, 'prod')">
                                            </label>
                                            <span style="color: #94a3b8; font-size: 0.82rem;">(Auto-compressed & stored on Firebase CDN)</span>
                                        </div>
                                        <div id="prod-upload-progress" style="display: none; color: #f59e0b; font-size: 0.82rem; margin-top: 6px;"></div>
                                        <div id="prod-image-previews" style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 8px;"></div>
                                        <input type="text" id="prod-image-url" placeholder="https://images.unsplash.com/... (or auto-filled on upload)" style="margin-top: 6px;" oninput="syncDirectImageUrl('prod')">
                                    </div>

                                    <div class="auth-input-group">
                                        <label for="prod-purchase-price">Cost / Purchase Price (\u20B9) *</label>
                                        <input type="number" step="0.01" id="prod-purchase-price" required placeholder="180.00">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-original-price">MRP / Market Price (\u20B9)</label>
                                        <input type="number" step="0.01" id="prod-original-price" placeholder="240.00">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-selling-price" style="color: #fbbf24; font-weight: 700;">Selling Price (\u20B9) *</label>
                                        <input type="number" step="0.01" id="prod-selling-price" required placeholder="220.00" style="border-color: rgba(251, 191, 36, 0.4);">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-unit">Unit / Weight</label>
                                        <input type="text" id="prod-unit" placeholder="e.g. 5 kg, 500 g, 1 L">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-stock">Initial Stock Quantity *</label>
                                        <input type="number" id="prod-stock" required placeholder="50">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-low-threshold">Low Stock Alert Level</label>
                                        <input type="number" id="prod-low-threshold" value="10" placeholder="10">
                                    </div>
                                    <div class="auth-input-group">
                                        <label for="prod-gst">GST Rate (%)</label>
                                        <select id="prod-gst">
                                            <option value="0">0% (GST Exempt)</option>
                                            <option value="5" selected>5% (Grocery Essentials)</option>
                                            <option value="12">12% (Standard Packaged)</option>
                                            <option value="18">18% (Consumer Goods)</option>
                                        </select>
                                    </div>
                                    <div class="auth-input-group" style="grid-column: span 2;">
                                        <label for="prod-description">Product Description / Highlights</label>
                                        <textarea id="prod-description" rows="3" placeholder="Enter key features, nutritional info, ingredients..." style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--admin-border); border-radius: 6px; color: #fff; padding: 0.6rem;"></textarea>
                                    </div>
                                </div>'''

# Replace the old form grid inside product-form
old_form_pattern = re.compile(r'<div class="product-form-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">.*?</div>\s*<div style="display: flex; gap: 0\.5rem; margin-top: 1\.5rem;">', re.DOTALL)
if "prod-brand" not in admin_html:
    admin_html = old_form_pattern.sub(new_form_grid + '\n                                <div style="display: flex; gap: 0.5rem; margin-top: 1.5rem;">', admin_html, count=1)

# Upgrade #edit-product-modal with full fields
new_edit_modal_body = '''                    <input type="hidden" id="edit-prod-id">
                    <div class="product-form-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                        <div>
                            <label for="edit-prod-sku">Unique SKU / Barcode ID *</label>
                            <input type="text" id="edit-prod-sku" required>
                        </div>
                        <div>
                            <label for="edit-prod-brand">Brand / Manufacturer</label>
                            <input type="text" id="edit-prod-brand" placeholder="e.g. Aashirvaad, Amul">
                        </div>
                        <div style="grid-column: span 2;">
                            <label for="edit-prod-name">Product Name *</label>
                            <input type="text" id="edit-prod-name" required>
                        </div>
                        <div>
                            <label for="edit-prod-category-id">Category Tree Node</label>
                            <select id="edit-prod-category-id">
                                <option value="">Select category...</option>
                            </select>
                        </div>
                        <div>
                            <label for="edit-prod-status">Visibility Status *</label>
                            <select id="edit-prod-status" required>
                                <option value="published">\U0001f7e2 Published (Live on Storefront)</option>
                                <option value="draft">\U0001f512 Draft (Hidden)</option>
                            </select>
                        </div>
                        
                        <!-- Edit Image Dropzone -->
                        <div style="grid-column: span 2;">
                            <label>Product Image (Direct Upload or Cloud CDN)</label>
                            <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                                <label for="edit-file-input" class="btn btn-secondary" style="cursor: pointer; display: inline-flex; align-items: center; gap: 6px; padding: 0.55rem 1rem; font-size: 0.88rem; background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px;">
                                    \U0001f4f7 Upload New Photo from Computer
                                    <input type="file" id="edit-file-input" accept="image/png,image/jpeg,image/webp,image/gif" multiple style="display: none;" onchange="handleProductImageFiles(this.files, 'edit')">
                                </label>
                                <span style="color: #94a3b8; font-size: 0.82rem;">Or direct URL:</span>
                            </div>
                            <div id="edit-upload-progress" style="display: none; color: #f59e0b; font-size: 0.82rem; margin-top: 6px;"></div>
                            <div id="edit-image-previews" style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 8px;"></div>
                            <input type="text" id="edit-prod-image-url" placeholder="https://images.unsplash.com/... (auto-filled on upload)" style="margin-top: 6px;" oninput="syncDirectImageUrl('edit')">
                        </div>

                        <div>
                            <label for="edit-prod-purchase-price">Purchase Price (\u20B9) *</label>
                            <input type="number" step="0.01" id="edit-prod-purchase-price" required>
                        </div>
                        <div>
                            <label for="edit-prod-original-price">MRP / Market Price (\u20B9)</label>
                            <input type="number" step="0.01" id="edit-prod-original-price" placeholder="e.g. 240.00">
                        </div>
                        <div>
                            <label for="edit-prod-selling-price" style="color: #fbbf24; font-weight: 700;">Selling Price (\u20B9) *</label>
                            <input type="number" step="0.01" id="edit-prod-selling-price" required style="border-color: rgba(251, 191, 36, 0.4);">
                        </div>
                        <div>
                            <label for="edit-prod-stock">Stock Quantity *</label>
                            <input type="number" id="edit-prod-stock" required>
                        </div>
                        <div>
                            <label for="edit-prod-low-threshold">Low Stock Alert Level</label>
                            <input type="number" id="edit-prod-low-threshold" value="10">
                        </div>
                        <div>
                            <label for="edit-prod-unit">Unit / Weight (e.g. 5 kg, 500 g)</label>
                            <input type="text" id="edit-prod-unit" placeholder="e.g. 5 kg">
                        </div>
                        <div>
                            <label for="edit-prod-gst">GST Rate (%)</label>
                            <select id="edit-prod-gst">
                                <option value="0">0% (Exempt)</option>
                                <option value="5">5% (Grocery)</option>
                                <option value="12">12%</option>
                                <option value="18">18%</option>
                            </select>
                        </div>
                        <div id="edit-discount-preview" style="grid-column: span 2; font-size: 0.85rem; font-weight: 700; color: #10b981; padding: 6px 12px; background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 6px;"></div>
                        <div style="grid-column: span 2;">
                            <label for="edit-prod-description">Product Description</label>
                            <textarea id="edit-prod-description" rows="3" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--admin-border); border-radius: 6px; color: #fff; padding: 0.6rem;"></textarea>
                        </div>
                    </div>'''

old_edit_modal_pattern = re.compile(r'<input type="hidden" id="edit-prod-id">.*?</div>\s*<button type="submit" class="btn btn-primary" style="margin-top: 1\.5rem; width: 100%;">Save Changes</button>', re.DOTALL)
if "edit-prod-brand" not in admin_html:
    admin_html = old_edit_modal_pattern.sub(new_edit_modal_body + '\n                    <button type="submit" class="btn btn-primary" style="margin-top: 1.5rem; width: 100%;">Save Changes</button>', admin_html, count=1)

# Add CSV Bulk Import Modal before </body> if not present
csv_modal_html = '''
    <!-- MODAL: CSV BULK IMPORT -->
    <div class="modal-overlay" id="csv-import-modal">
        <div class="modal-container" style="max-width: 620px; width: 95%;">
            <div class="modal-header" style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--admin-border); padding-bottom: 1rem;">
                <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: #fff;">Bulk Import Catalog (CSV)</h3>
                <button type="button" onclick="closeCsvImportModal()" style="background: transparent; border: none; font-size: 1.5rem; color: #94a3b8; cursor: pointer;">&times;</button>
            </div>
            <div class="modal-body" style="padding: 1.5rem 0;">
                <p style="color: #94a3b8; font-size: 0.9rem; margin-top: 0;">Upload or paste a CSV file containing your inventory items. Format: <code>name,sku,category,selling_price,mrp,purchase_price,stock,unit,image_url,status</code></p>
                <div style="margin-bottom: 1.25rem;">
                    <button type="button" class="btn btn-secondary btn-sm" onclick="downloadCsvTemplate()" style="display: inline-flex; align-items: center; gap: 6px; background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2); padding: 0.45rem 0.85rem; border-radius: 6px; cursor: pointer;">
                        \U0001f4e5 Download Sample CSV Template
                    </button>
                </div>
                <div class="upload-dropzone" id="csv-dropzone" style="border: 2px dashed rgba(245, 158, 11, 0.4); border-radius: 10px; padding: 1.75rem; text-align: center; background: rgba(15, 23, 42, 0.5); cursor: pointer;" onclick="document.getElementById('csv-file-input').click()">
                    <div style="font-size: 2.2rem; margin-bottom: 0.5rem;">\U0001f4c4</div>
                    <div style="font-weight: 700; color: #f8fafc; font-size: 0.95rem;">Click to browse CSV or drop file here</div>
                    <div style="color: #64748b; font-size: 0.8rem; margin-top: 4px;">Supports standard UTF-8 .csv files</div>
                    <input type="file" id="csv-file-input" accept=".csv,text/csv" style="display: none;" onchange="handleCsvFileSelected(this.files)">
                </div>
                <div id="csv-file-info" style="margin-top: 1rem; display: none; padding: 0.75rem 1rem; background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; border-radius: 6px; color: #10b981; font-size: 0.88rem; font-weight: 600;"></div>
                <div style="margin-top: 1rem;">
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px; font-weight: 600;">Or Paste CSV Raw Content:</label>
                    <textarea id="csv-raw-textarea" rows="6" placeholder="name,sku,category,selling_price,mrp,purchase_price,stock,unit,image_url,status&#10;Premium Basmati Rice,RICE-001,Staples,145.00,165.00,120.00,50,1 kg,,published" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--admin-border); border-radius: 6px; color: #f8fafc; font-family: monospace; font-size: 0.82rem; padding: 0.75rem;"></textarea>
                </div>
            </div>
            <div class="modal-footer" style="display: flex; justify-content: flex-end; gap: 0.75rem; border-top: 1px solid var(--admin-border); padding-top: 1rem;">
                <button type="button" class="btn btn-secondary" onclick="closeCsvImportModal()" style="background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2); padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer;">Cancel</button>
                <button type="button" class="btn btn-primary" id="btn-submit-csv-import" onclick="handleCsvImportSubmit()" style="cursor: pointer;">\U0001f680 Import Catalog to Database</button>
            </div>
        </div>
    </div>
'''

if "csv-import-modal" not in admin_html:
    admin_html = admin_html.replace("</body>", csv_modal_html + "\n</body>")

with open(admin_path, "w", encoding="utf-8") as f:
    f.write(admin_html)

print("Updated public_web/admin.html successfully!")
