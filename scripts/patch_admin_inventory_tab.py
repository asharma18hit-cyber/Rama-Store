# scripts/patch_admin_inventory_tab.py
import re

print("Overhauling public_web/admin.html with production Inventory Suite...")

with open("public_web/admin.html", "r", encoding="utf-8") as f:
    html = f.read()

# 1. Replace the entire #tab-inventory section with the new modern table & controls
old_tab_inventory_pattern = re.compile(
    r'<!-- 3\. CATALOG EDITOR TAB -->\s*<section id="tab-inventory" class="tab-content">.*?</section>\s*(?=<!-- 4\. ORDERS TAB -->|<!-- 4\. ORDERS & FULFILLMENT TAB -->|<section id="tab-orders")',
    re.DOTALL
)

new_tab_inventory = """<!-- 3. CATALOG EDITOR TAB -->
        <section id="tab-inventory" class="tab-content">
            <div class="inventory-layout" style="display: flex; flex-direction: column; gap: 1.5rem; width: 100%;">
                
                <!-- Main Active Catalog Management Card -->
                <div class="card inventory-table-card" style="width: 100%; box-sizing: border-box; background: #0d1527; border: 1px solid rgba(184, 137, 43, 0.28); border-radius: 12px;">
                    <div class="card-header" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; border-bottom: 1px solid rgba(184, 137, 43, 0.2); background: #111c35; padding: 1.25rem 1.5rem; border-radius: 12px 12px 0 0;">
                        <div>
                            <h2 style="font-size: 1.35rem; font-weight: 800; margin: 0; color: #ffffff; letter-spacing: -0.01em;">Active Catalog Inventory</h2>
                            <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: #94a3b8;">Manage product listings, multi-image galleries, variants, live pricing, and storefront publication</p>
                        </div>
                        <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                            <button type="button" class="btn btn-secondary" onclick="downloadCatalogCsv()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.18); cursor: pointer;" title="Export current catalog to CSV">
                                📥 Export CSV
                            </button>
                            <button type="button" class="btn btn-secondary" onclick="openCsvImportModal()" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 700; padding: 0.6rem 1rem; border-radius: 8px; background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.18); cursor: pointer;" title="Bulk import inventory items from CSV">
                                📤 Bulk Import CSV
                            </button>
                            <button type="button" class="btn btn-primary" onclick="openProductEditor('new')" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 800; padding: 0.65rem 1.35rem; border-radius: 8px; background: #d97706; color: #ffffff; border: none; cursor: pointer; box-shadow: 0 4px 14px rgba(217, 119, 6, 0.4);">
                                ➕ Register New Item
                            </button>
                        </div>
                    </div>
                    
                    <div class="card-body" style="padding: 1.5rem; background: #0d1527;">
                        <!-- Comprehensive Status Filter Tabs with Database Counts -->
                        <div class="status-tabs-container">
                            <button type="button" class="status-tab-btn active" data-status="all" onclick="setCatalogFilter('all')">
                                All Items <span class="tab-count" id="catalog-count-all">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="published" onclick="setCatalogFilter('published')">
                                🟢 Live on Store <span class="tab-count" id="catalog-count-published">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="draft" onclick="setCatalogFilter('draft')">
                                🔒 Drafts <span class="tab-count" id="catalog-count-draft">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="scheduled" onclick="setCatalogFilter('scheduled')">
                                ⏰ Scheduled <span class="tab-count" id="catalog-count-scheduled">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="low_stock" onclick="setCatalogFilter('low_stock')">
                                ⚠️ Low Stock <span class="tab-count" id="catalog-count-low">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="out_of_stock" onclick="setCatalogFilter('out_of_stock')">
                                🔴 Out of Stock <span class="tab-count" id="catalog-count-out">0</span>
                            </button>
                            <button type="button" class="status-tab-btn" data-status="archived" onclick="setCatalogFilter('archived')">
                                📦 Archived <span class="tab-count" id="catalog-count-archived">0</span>
                            </button>
                        </div>

                        <!-- Secondary Toolbar: Search, Category Filter, Sort, and Items Per Page -->
                        <div class="catalog-toolbar-grid">
                            <div style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                                <div class="catalog-search-box">
                                    <input type="text" id="catalog-search" placeholder="Search product name, SKU, brand, barcode..." oninput="debounceCatalogSearch()">
                                    <button type="button" onclick="clearCatalogSearch()" style="position: absolute; right: 8px; background: transparent; border: none; color: #94a3b8; cursor: pointer; font-size: 1rem;">&times;</button>
                                </div>
                                <select id="catalog-category-filter" class="catalog-select-filter" onchange="handleCategoryFilterChange(this.value)">
                                    <option value="all">All Categories</option>
                                </select>
                                <select id="catalog-sort-by" class="catalog-select-filter" onchange="handleSortChange(this.value)">
                                    <option value="newest">Sort: Newest First</option>
                                    <option value="name_asc">Name: A to Z</option>
                                    <option value="name_desc">Name: Z to A</option>
                                    <option value="price_asc">Price: Low to High</option>
                                    <option value="price_desc">Price: High to Low</option>
                                    <option value="stock_asc">Stock: Low to High</option>
                                    <option value="stock_desc">Stock: High to Low</option>
                                </select>
                            </div>
                            <div style="display: flex; gap: 0.75rem; align-items: center;">
                                <span style="font-size: 0.85rem; color: #94a3b8;">Show:</span>
                                <select id="catalog-page-size" class="catalog-select-filter" style="padding: 0.45rem 0.75rem;" onchange="handlePageSizeChange(this.value)">
                                    <option value="10">10 / page</option>
                                    <option value="25">25 / page</option>
                                    <option value="50">50 / page</option>
                                    <option value="100">100 / page</option>
                                </select>
                            </div>
                        </div>

                        <!-- Floating Bulk Action Toolbar -->
                        <div class="bulk-actions-bar" id="bulk-actions-bar">
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <span style="font-weight: 700; color: #fbbf24; font-size: 0.95rem;">
                                    <span id="bulk-selected-count">0</span> items selected
                                </span>
                                <button type="button" class="btn btn-secondary btn-sm" onclick="clearAllSelections()" style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: #cbd5e1; padding: 3px 8px; border-radius: 4px; font-size: 0.78rem;">
                                    Clear
                                </button>
                            </div>
                            <div style="display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap;">
                                <button type="button" class="btn btn-sm" onclick="executeBulkAction('publish')" style="background: #064e3b; color: #34d399; border: 1px solid #059669; font-weight: 700; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    🟢 Publish
                                </button>
                                <button type="button" class="btn btn-sm" onclick="executeBulkAction('unpublish')" style="background: #78350f; color: #fcd34d; border: 1px solid #d97706; font-weight: 700; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    🔒 Move to Draft
                                </button>
                                <button type="button" class="btn btn-sm" onclick="openBulkCategoryModal()" style="background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.2); font-weight: 600; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    📂 Set Category
                                </button>
                                <button type="button" class="btn btn-sm" onclick="openBulkPriceModal()" style="background: #1e293b; color: #fbbf24; border: 1px solid rgba(251,191,36,0.3); font-weight: 600; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    💰 Adjust Price
                                </button>
                                <button type="button" class="btn btn-sm" onclick="executeBulkAction('archive')" style="background: #1e293b; color: #cbd5e1; border: 1px solid rgba(255,255,255,0.2); font-weight: 600; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    📦 Archive
                                </button>
                                <button type="button" class="btn btn-sm" onclick="executeBulkAction('delete')" style="background: #7f1d1d; color: #fca5a5; border: 1px solid #b91c1c; font-weight: 700; border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer;">
                                    🗑️ Delete
                                </button>
                            </div>
                        </div>

                        <!-- Spacious E-Commerce Product Table -->
                        <div class="table-responsive" style="width: 100%; overflow-x: auto; border-radius: 10px; border: 1px solid rgba(255, 255, 255, 0.08); background: #0b1220;">
                            <table class="admin-catalog-table">
                                <thead>
                                    <tr>
                                        <th style="width: 40px; text-align: center;">
                                            <input type="checkbox" id="select-all-products" onchange="toggleSelectAll(this.checked)" style="cursor: pointer; width: 16px; height: 16px; accent-color: #d97706;">
                                        </th>
                                        <th style="width: 60px; text-align: center;">Media</th>
                                        <th style="text-align: left; min-width: 280px;">Product Name & Identifiers</th>
                                        <th style="text-align: left; min-width: 130px;">Category</th>
                                        <th style="text-align: right; min-width: 130px;">Pricing (₹)</th>
                                        <th style="text-align: center; min-width: 140px;">Stock & Availability</th>
                                        <th style="text-align: center; min-width: 120px;">Channel Status</th>
                                        <th style="text-align: right; min-width: 150px; padding-right: 1.5rem;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="catalog-items-body">
                                    <!-- Rendered dynamically via JavaScript -->
                                </tbody>
                            </table>
                        </div>

                        <!-- Pagination Footer -->
                        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; margin-top: 1.5rem; padding: 0.5rem 0.25rem;">
                            <div style="font-size: 0.88rem; color: #94a3b8;">
                                Showing <span id="pagination-start" style="color: #fff; font-weight: 700;">0</span> to <span id="pagination-end" style="color: #fff; font-weight: 700;">0</span> of <span id="pagination-total" style="color: #fbbf24; font-weight: 800;">0</span> products
                            </div>
                            <div class="pagination-bar" id="catalog-pagination" style="display: flex; gap: 0.4rem; align-items: center;">
                                <!-- Dynamic pagination buttons -->
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </section>
"""

match = old_tab_inventory_pattern.search(html)
if match:
    html = html[:match.start()] + new_tab_inventory + html[match.end():]
    print("Replaced #tab-inventory successfully!")
else:
    print("Failed to find #tab-inventory with regex!")

# 2. Add the Complete Product Editor Modal & Auxiliary Modals before </body>
editor_modals_html = """
    <!-- ========================================================================== -->
    <!-- COMPLETE PRODUCT EDITOR SUITE MODAL (CREATION & FULL EDITING)               -->
    <!-- ========================================================================== -->
    <div class="modal-overlay" id="product-editor-modal" style="z-index: 100000;">
        <div class="editor-modal-container">
            <!-- Modal Header Bar -->
            <div class="editor-header-bar">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="font-size: 1.5rem;">🛍️</div>
                    <div>
                        <h3 id="editor-title" style="margin: 0; font-size: 1.25rem; font-weight: 800; color: #ffffff;">Register New Product</h3>
                        <p id="editor-subtitle" style="margin: 2px 0 0 0; font-size: 0.8rem; color: #94a3b8;">Configure product details, gallery images, variants, tax rates, and live storefront publication</p>
                    </div>
                    <div id="editor-status-badge" style="margin-left: 8px;"></div>
                </div>
                <div style="display: flex; gap: 0.75rem; align-items: center;">
                    <button type="button" class="btn btn-secondary btn-sm" id="btn-editor-preview" onclick="previewCurrentProduct()" style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.2); color: #cbd5e1; border-radius: 6px; padding: 0.45rem 0.85rem; cursor: pointer; display: none;">
                        👁️ Storefront Preview
                    </button>
                    <button type="button" onclick="closeProductEditor()" style="background: transparent; border: none; font-size: 1.6rem; color: #94a3b8; cursor: pointer; padding: 0 0.5rem;" title="Close without saving">&times;</button>
                </div>
            </div>

            <!-- Two-Column Editor Layout -->
            <div class="editor-body-layout">
                <!-- Left Navigation Sidebar -->
                <nav class="editor-sidebar-nav">
                    <button type="button" class="editor-nav-tab active" data-pane="pane-basic" onclick="switchEditorTab('pane-basic')">
                        <span>ℹ️</span> Basic Information
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-media" onclick="switchEditorTab('pane-media')">
                        <span>🖼️</span> Images & Gallery <span id="editor-tab-img-count" style="font-size: 0.75rem; color: #fbbf24;"></span>
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-pricing" onclick="switchEditorTab('pane-pricing')">
                        <span>💰</span> Pricing & Tax
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-inventory" onclick="switchEditorTab('pane-inventory')">
                        <span>📦</span> Inventory & Variants
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-delivery" onclick="switchEditorTab('pane-delivery')">
                        <span>🚚</span> Delivery & Shipping
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-seo" onclick="switchEditorTab('pane-seo')">
                        <span>🌐</span> SEO & Storefront
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-publication" onclick="switchEditorTab('pane-publication')">
                        <span>⏱️</span> Publication Status
                    </button>
                    <button type="button" class="editor-nav-tab" data-pane="pane-audit" onclick="switchEditorTab('pane-audit')">
                        <span>📜</span> Audit History
                    </button>
                </nav>

                <!-- Right Scrollable Content Viewport -->
                <div class="editor-content-pane">
                    <form id="product-master-form" onsubmit="handleMasterProductSubmit(event)">
                        <input type="hidden" id="edit-master-id">

                        <!-- PANE 1: BASIC INFORMATION -->
                        <div class="editor-tab-pane active" id="pane-basic">
                            <div class="editor-section-card">
                                <h4><span>📝</span> Core Product Identification</h4>
                                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                                    <div style="grid-column: span 2;">
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Product Name *</label>
                                        <input type="text" id="m-name" required placeholder="e.g. Aashirvaad Superior MP Shudh Chakki Atta (5 kg)" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff; font-size: 0.92rem;" oninput="handleProductNameChange(this.value)">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">URL Slug (Handle) *</label>
                                        <input type="text" id="m-slug" required placeholder="aashirvaad-superior-mp-shudh-chakki-atta-5kg" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fbbf24; font-family: 'IBM Plex Mono', monospace; font-size: 0.85rem;">
                                        <small style="color: #64748b; font-size: 0.75rem;">URL: /store?product=<span id="m-slug-preview">...</span></small>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Unique SKU Code *</label>
                                        <div style="display: flex; gap: 6px;">
                                            <input type="text" id="m-sku" required placeholder="e.g. RAMA-ATT-001" style="flex: 1; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff; font-family: 'IBM Plex Mono', monospace;">
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="generateAutoSku()" style="background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; cursor: pointer; white-space: nowrap;">Auto SKU</button>
                                        </div>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Barcode / EAN / UPC</label>
                                        <input type="text" id="m-barcode" placeholder="e.g. 8901030383042" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff; font-family: 'IBM Plex Mono', monospace;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Brand / Manufacturer</label>
                                        <input type="text" id="m-brand" placeholder="e.g. Aashirvaad, Amul, MDH, Everest, Classmate" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Category Tree Node *</label>
                                        <select id="m-category-id" required style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                            <option value="">-- Choose Category --</option>
                                        </select>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Subcategory / Collection</label>
                                        <input type="text" id="m-subcategory" placeholder="e.g. Whole Wheat Flours" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>
                            </div>

                            <div class="editor-section-card">
                                <h4><span>📄</span> Descriptions & Marketing Copy</h4>
                                <div style="display: flex; flex-direction: column; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Short Summary (Storefront Cards)</label>
                                        <input type="text" id="m-short-desc" maxlength="220" placeholder="Crisp 1-line product summary displayed in search and catalog previews..." style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Full Product Description</label>
                                        <textarea id="m-full-desc" rows="5" placeholder="Detailed product specifications, nutritional values, origin, directions for use..." style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.75rem; color: #fff; line-height: 1.5;"></textarea>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Key Features (1 feature per line)</label>
                                        <textarea id="m-features" rows="3" placeholder="100% Pure MP Shudh Whole Wheat&#10;Zero Maida Added&#10;Rich in Dietary Fibre&#10;Soft Rotis Guaranteed for Hours" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.75rem; color: #fff;"></textarea>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Search Tags (comma-separated)</label>
                                        <input type="text" id="m-tags" placeholder="atta, wheat, flour, aashirvaad, grocery essential, roti" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 2: IMAGES & MEDIA GALLERY -->
                        <div class="editor-tab-pane" id="pane-media" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>🖼️</span> Multi-Image Product Gallery</h4>
                                <p style="color: #94a3b8; font-size: 0.85rem; margin-top: -6px;">Upload high-resolution product photos. Drag and drop to reorder gallery, star an image to set as Primary Cover.</p>
                                
                                <div class="upload-dropzone" id="m-image-dropzone" style="border: 2px dashed rgba(245, 158, 11, 0.4); border-radius: 10px; padding: 2rem; text-align: center; background: rgba(15, 23, 42, 0.5); cursor: pointer;" onclick="document.getElementById('m-file-upload').click()">
                                    <div style="font-size: 2.4rem; margin-bottom: 0.5rem;">📸</div>
                                    <div style="font-weight: 700; color: #f8fafc; font-size: 1rem;">Click to upload images or drag & drop files here</div>
                                    <div style="color: #64748b; font-size: 0.82rem; margin-top: 4px;">PNG, JPG, WebP, GIF up to 8MB. Images are auto-compressed and uploaded directly to Firebase Storage CDN.</div>
                                    <input type="file" id="m-file-upload" accept="image/*" multiple style="display: none;" onchange="handleEditorGalleryFiles(this.files)">
                                </div>
                                <div id="m-upload-progress-bar" style="display: none; margin-top: 1rem; color: #f59e0b; font-weight: 600; font-size: 0.88rem;"></div>

                                <div style="margin-top: 1.5rem;">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <span style="font-size: 0.9rem; font-weight: 700; color: #cbd5e1;">Uploaded Gallery (<span id="m-gallery-count">0</span> photos)</span>
                                        <div style="display: flex; gap: 0.5rem;">
                                            <input type="text" id="m-direct-url-input" placeholder="Or paste image URL..." style="padding: 0.4rem 0.75rem; font-size: 0.82rem; border-radius: 6px; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.15); color: #fff; width: 220px;">
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="addDirectUrlToGallery()" style="background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; cursor: pointer;">Add URL</button>
                                        </div>
                                    </div>
                                    <div class="editor-gallery-grid" id="m-gallery-grid">
                                        <!-- Rendered dynamically -->
                                    </div>
                                </div>
                            </div>

                            <div class="editor-section-card">
                                <h4><span>🎥</span> Product Video (Optional)</h4>
                                <div>
                                    <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Video Embed URL (YouTube, Vimeo, MP4)</label>
                                    <input type="text" id="m-video-url" placeholder="https://www.youtube.com/watch?v=..." style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                </div>
                            </div>
                        </div>

                        <!-- PANE 3: PRICING & TAX -->
                        <div class="editor-tab-pane" id="pane-pricing" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>💰</span> Retail Pricing & Margins</h4>
                                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">MRP / Market Price (₹) *</label>
                                        <input type="number" step="0.01" id="m-mrp" required placeholder="260.00" oninput="calculatePricingMargins()" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff; font-size: 1rem;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 800; color: #fbbf24; margin-bottom: 6px;">Selling Price (₹) *</label>
                                        <input type="number" step="0.01" id="m-selling-price" required placeholder="235.00" oninput="calculatePricingMargins()" style="width: 100%; box-sizing: border-box; background: rgba(251, 191, 36, 0.08); border: 2px solid #f59e0b; border-radius: 6px; padding: 0.65rem 0.85rem; color: #fbbf24; font-size: 1.05rem; font-weight: 800;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #94a3b8; margin-bottom: 6px;">Purchase / Cost Price (₹)</label>
                                        <input type="number" step="0.01" id="m-cost-price" placeholder="195.00" oninput="calculatePricingMargins()" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>

                                <!-- Live Financial Calculation Bar -->
                                <div id="m-pricing-calc-bar" style="margin-top: 1.25rem; padding: 0.85rem 1.25rem; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
                                    <div style="font-weight: 700; color: #34d399; font-size: 0.9rem;">
                                        Customer Discount: <span id="m-calc-discount" style="font-family: 'IBM Plex Mono', monospace;">₹25.00 (10% OFF)</span>
                                    </div>
                                    <div style="font-weight: 700; color: #fbbf24; font-size: 0.9rem;">
                                        Estimated Profit: <span id="m-calc-profit" style="font-family: 'IBM Plex Mono', monospace;">₹40.00 / unit</span> (<span id="m-calc-margin">17.0% margin</span>)
                                    </div>
                                </div>
                            </div>

                            <div class="editor-section-card">
                                <h4><span>🏷️</span> Tax & GST Configuration</h4>
                                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">GST Rate (%) *</label>
                                        <select id="m-gst-percent" style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                            <option value="0">0% (GST Exempt / Unbranded Essentials)</option>
                                            <option value="5" selected>5% (Grocery, Atta, Rice, Spices)</option>
                                            <option value="12">12% (Processed Foods & Stationery)</option>
                                            <option value="18">18% (Consumer Goods, Personal Care)</option>
                                            <option value="28">28% (Luxury & Aerated Beverages)</option>
                                        </select>
                                    </div>
                                    <div style="display: flex; align-items: center; padding-top: 1.5rem;">
                                        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; color: #f8fafc; font-weight: 600; font-size: 0.9rem;">
                                            <input type="checkbox" id="m-tax-inclusive" checked style="width: 18px; height: 18px; accent-color: #d97706;">
                                            Selling Price includes applicable GST tax
                                        </label>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 4: INVENTORY & VARIANTS -->
                        <div class="editor-tab-pane" id="pane-inventory" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>📦</span> Inventory Tracking</h4>
                                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Available Stock Quantity *</label>
                                        <input type="number" id="m-stock" required placeholder="50" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #34d399; font-weight: 800; font-size: 1rem;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Low Stock Alert Level</label>
                                        <input type="number" id="m-low-threshold" value="10" placeholder="10" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Display Unit / Weight</label>
                                        <input type="text" id="m-unit" placeholder="e.g. 5 kg, 500 g, 1 L, 1 packet" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>
                            </div>

                            <div class="editor-section-card">
                                <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255, 255, 255, 0.08); padding-bottom: 0.75rem; margin-bottom: 1rem;">
                                    <h4 style="margin: 0; border: none; padding: 0;"><span>🔀</span> Product Variants (e.g. Size, Weight, Flavor)</h4>
                                    <button type="button" class="btn btn-secondary btn-sm" onclick="addNewVariantRow()" style="background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; padding: 0.4rem 0.8rem; cursor: pointer; font-weight: 700;">
                                        ➕ Add Variant
                                    </button>
                                </div>
                                <p style="color: #94a3b8; font-size: 0.82rem; margin-top: -6px;">If this product comes in multiple packaging sizes or colors, add variants below. Each variant can have its own SKU, selling price, and stock.</p>
                                
                                <div style="overflow-x: auto; margin-top: 1rem;">
                                    <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
                                        <thead>
                                            <tr style="background: rgba(15, 23, 42, 0.8); text-transform: uppercase; color: #94a3b8; font-size: 0.75rem;">
                                                <th style="padding: 8px; text-align: left;">Variant Name / Size</th>
                                                <th style="padding: 8px; text-align: left;">Variant SKU</th>
                                                <th style="padding: 8px; text-align: right;">Selling Price (₹)</th>
                                                <th style="padding: 8px; text-align: right;">MRP (₹)</th>
                                                <th style="padding: 8px; text-align: center;">Stock</th>
                                                <th style="padding: 8px; text-align: center; width: 40px;">Action</th>
                                            </tr>
                                        </thead>
                                        <tbody id="m-variants-tbody">
                                            <!-- Dynamically added variant rows -->
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 5: DELIVERY & SERVICEABILITY -->
                        <div class="editor-tab-pane" id="pane-delivery" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>🚚</span> Shipping & Serviceability</h4>
                                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Weight (kg)</label>
                                        <input type="number" step="0.01" id="m-weight-kg" placeholder="e.g. 5.0" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Package Dimensions (L x W x H cm)</label>
                                        <input type="text" id="m-dimensions" placeholder="e.g. 35 x 25 x 12 cm" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Estimated Prep / Dispatch Time</label>
                                        <select id="m-prep-time" style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                            <option value="1">Within 1-2 Hours (Express Delivery)</option>
                                            <option value="4">Same Day (within 4 hours)</option>
                                            <option value="24">Next Day Delivery</option>
                                        </select>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Special Handling Requirements</label>
                                        <select id="m-special-handling" style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                            <option value="Standard">Standard Retail Delivery</option>
                                            <option value="Fragile">Fragile / Glass Care</option>
                                            <option value="Perishable">Perishable / Bakery / Dairy</option>
                                            <option value="ColdStorage">Cold Storage / Chilled</option>
                                        </select>
                                    </div>
                                    <div style="grid-column: span 2;">
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Restricted Serviceable PIN Codes (Leave empty for all store zones)</label>
                                        <input type="text" id="m-serviceable-pins" placeholder="e.g. 272155, 272001, 272002 (or leave blank to deliver anywhere in serviceable area)" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 6: SEO & STOREFRONT -->
                        <div class="editor-tab-pane" id="pane-seo" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>🌐</span> Search Engine Optimization (SEO)</h4>
                                <div style="display: flex; flex-direction: column; gap: 1rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">SEO Meta Title</label>
                                        <input type="text" id="m-meta-title" placeholder="Aashirvaad Superior MP Shudh Chakki Atta (5 kg) - Buy Online | Samaur Mart" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">SEO Meta Description</label>
                                        <textarea id="m-meta-desc" rows="3" placeholder="Order 100% pure Aashirvaad MP Shudh Chakki Atta at best prices in Samaur Mart. Same day home delivery guaranteed..." style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;"></textarea>
                                    </div>
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 6px;">Search Keywords</label>
                                        <input type="text" id="m-keywords" placeholder="grocery, atta, aashirvaad, best price atta, daily essentials" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.18); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                    <div style="display: flex; gap: 2rem; margin-top: 0.5rem;">
                                        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; color: #fff; font-weight: 600;">
                                            <input type="checkbox" id="m-is-featured" style="width: 18px; height: 18px; accent-color: #d97706;">
                                            ⭐ Feature on Storefront Homepage
                                        </label>
                                        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; color: #fff; font-weight: 600;">
                                            <input type="checkbox" id="m-is-homepage" checked style="width: 18px; height: 18px; accent-color: #d97706;">
                                            Visible in Category Navigation
                                        </label>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 7: PUBLICATION & SCHEDULING -->
                        <div class="editor-tab-pane" id="pane-publication" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>⏱️</span> Publication Lifecycle</h4>
                                <div style="display: flex; flex-direction: column; gap: 1.25rem;">
                                    <div>
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #cbd5e1; margin-bottom: 8px;">Product Publication Status *</label>
                                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                                            <label style="padding: 1rem; border-radius: 8px; background: rgba(6, 78, 59, 0.3); border: 2px solid #059669; cursor: pointer; display: flex; align-items: flex-start; gap: 10px;">
                                                <input type="radio" name="m-status-radio" value="published" checked onchange="handlePublicationStatusRadio(this.value)" style="margin-top: 3px;">
                                                <div>
                                                    <div style="font-weight: 800; color: #34d399;">🟢 Publish Now (Live)</div>
                                                    <div style="font-size: 0.8rem; color: #94a3b8; margin-top: 3px;">Immediately searchable and purchasable by customers online</div>
                                                </div>
                                            </label>
                                            <label style="padding: 1rem; border-radius: 8px; background: rgba(120, 53, 15, 0.3); border: 1px solid rgba(217, 119, 6, 0.4); cursor: pointer; display: flex; align-items: flex-start; gap: 10px;">
                                                <input type="radio" name="m-status-radio" value="draft" onchange="handlePublicationStatusRadio(this.value)" style="margin-top: 3px;">
                                                <div>
                                                    <div style="font-weight: 800; color: #fcd34d;">🔒 Save as Draft</div>
                                                    <div style="font-size: 0.8rem; color: #94a3b8; margin-top: 3px;">Hidden from customers. Remains in catalog for review</div>
                                                </div>
                                            </label>
                                            <label style="padding: 1rem; border-radius: 8px; background: rgba(88, 28, 135, 0.3); border: 1px solid rgba(147, 51, 234, 0.4); cursor: pointer; display: flex; align-items: flex-start; gap: 10px;">
                                                <input type="radio" name="m-status-radio" value="scheduled" onchange="handlePublicationStatusRadio(this.value)" style="margin-top: 3px;">
                                                <div>
                                                    <div style="font-weight: 800; color: #d8b4fe;">⏰ Schedule Publication</div>
                                                    <div style="font-size: 0.8rem; color: #94a3b8; margin-top: 3px;">Automatically goes live at a future date and time</div>
                                                </div>
                                            </label>
                                            <label style="padding: 1rem; border-radius: 8px; background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(255, 255, 255, 0.15); cursor: pointer; display: flex; align-items: flex-start; gap: 10px;">
                                                <input type="radio" name="m-status-radio" value="archived" onchange="handlePublicationStatusRadio(this.value)" style="margin-top: 3px;">
                                                <div>
                                                    <div style="font-weight: 800; color: #94a3b8;">📦 Archive Product</div>
                                                    <div style="font-size: 0.8rem; color: #64748b; margin-top: 3px;">Removed from store while preserving past order records</div>
                                                </div>
                                            </label>
                                        </div>
                                    </div>

                                    <div id="m-scheduled-time-container" style="display: none; padding: 1rem; background: rgba(88, 28, 135, 0.2); border: 1px solid #9333ea; border-radius: 8px;">
                                        <label style="display: block; font-size: 0.85rem; font-weight: 700; color: #d8b4fe; margin-bottom: 6px;">Select Future Publication Date & Time:</label>
                                        <input type="datetime-local" id="m-scheduled-at" style="background: #1e293b; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; padding: 0.65rem 0.85rem; color: #fff;">
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- PANE 8: AUDIT HISTORY -->
                        <div class="editor-tab-pane" id="pane-audit" style="display: none;">
                            <div class="editor-section-card">
                                <h4><span>📜</span> Product Audit Log</h4>
                                <div id="m-audit-timeline" style="display: flex; flex-direction: column; gap: 0.75rem;">
                                    <div style="color: #94a3b8; font-size: 0.88rem;">No historical changes recorded for this item yet.</div>
                                </div>
                            </div>
                        </div>

                    </form>
                </div>
            </div>

            <!-- Sticky Modal Footer -->
            <div class="editor-footer-bar">
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span id="editor-dirty-indicator" style="display: none; color: #f59e0b; font-size: 0.85rem; font-weight: 700;">
                        ⚠️ Unsaved changes
                    </span>
                </div>
                <div style="display: flex; gap: 0.75rem; align-items: center;">
                    <button type="button" class="btn btn-secondary" onclick="closeProductEditor()" style="background: #1e293b; color: #f8fafc; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; padding: 0.6rem 1.25rem; cursor: pointer;">
                        Cancel
                    </button>
                    <button type="button" class="btn btn-secondary" id="btn-save-draft" onclick="submitProductWithStatus('draft')" style="background: #78350f; color: #fcd34d; border: 1px solid #d97706; border-radius: 6px; padding: 0.6rem 1.25rem; font-weight: 700; cursor: pointer;">
                        💾 Save Draft
                    </button>
                    <button type="button" class="btn btn-primary" id="btn-save-publish" onclick="submitProductWithStatus('published')" style="background: #d97706; color: #ffffff; border: none; border-radius: 6px; padding: 0.65rem 1.6rem; font-weight: 800; cursor: pointer; box-shadow: 0 4px 14px rgba(217, 119, 6, 0.4);">
                        🚀 Save & Publish Live
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- QUICK STOCK ADJUSTMENT MODAL -->
    <div class="modal-overlay" id="quick-stock-modal" style="z-index: 100001;">
        <div class="modal-container" style="max-width: 440px; background: #0f172a; border: 1px solid rgba(184,137,43,0.3); border-radius: 12px; padding: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 0.75rem;">
                <h3 style="margin: 0; color: #fff; font-size: 1.15rem; font-weight: 800;">Quick Stock Adjustment</h3>
                <button type="button" onclick="closeQuickStockModal()" style="background: transparent; border: none; color: #94a3b8; font-size: 1.5rem; cursor: pointer;">&times;</button>
            </div>
            <div style="padding: 1.25rem 0;">
                <div id="quick-stock-prod-name" style="font-weight: 700; color: #fbbf24; margin-bottom: 1rem; font-size: 0.95rem;"></div>
                <div style="margin-bottom: 1rem;">
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px;">New Total Stock Units *</label>
                    <input type="number" id="quick-stock-input" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 2px solid #10b981; border-radius: 6px; padding: 0.65rem 0.85rem; color: #34d399; font-weight: 800; font-size: 1.2rem; text-align: center;">
                </div>
                <div>
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px;">Adjustment Reason</label>
                    <input type="text" id="quick-stock-reason" placeholder="e.g. Restocked from supplier, Counter inventory count" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 6px; padding: 0.55rem 0.75rem; color: #fff;">
                </div>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 0.75rem; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 1rem;">
                <button type="button" class="btn btn-secondary" onclick="closeQuickStockModal()">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="submitQuickStock()">Confirm Restock</button>
            </div>
        </div>
    </div>

    <!-- BULK PRICE ADJUSTMENT MODAL -->
    <div class="modal-overlay" id="bulk-price-modal" style="z-index: 100001;">
        <div class="modal-container" style="max-width: 480px; background: #0f172a; border: 1px solid rgba(184,137,43,0.3); border-radius: 12px; padding: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 0.75rem;">
                <h3 style="margin: 0; color: #fff; font-size: 1.15rem; font-weight: 800;">Bulk Price Adjustment</h3>
                <button type="button" onclick="closeBulkPriceModal()" style="background: transparent; border: none; color: #94a3b8; font-size: 1.5rem; cursor: pointer;">&times;</button>
            </div>
            <div style="padding: 1.25rem 0;">
                <p style="color: #94a3b8; font-size: 0.88rem; margin-top: 0;">Adjust selling prices across all <strong id="bulk-price-count" style="color: #fbbf24;">0</strong> selected products simultaneously.</p>
                <div style="margin-bottom: 1rem;">
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px;">Adjustment Type</label>
                    <select id="bulk-price-type" style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; padding: 0.6rem; color: #fff;">
                        <option value="percent">Percentage Change (%) e.g. +5% or -10%</option>
                        <option value="delta">Flat Rupee Amount (₹) e.g. +10 or -20</option>
                    </select>
                </div>
                <div>
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px;">Adjustment Value *</label>
                    <input type="number" step="0.01" id="bulk-price-val" placeholder="e.g. 5 or -10" style="width: 100%; box-sizing: border-box; background: rgba(15, 23, 42, 0.8); border: 2px solid #f59e0b; border-radius: 6px; padding: 0.65rem 0.85rem; color: #fbbf24; font-weight: 800; font-size: 1.1rem;">
                </div>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 0.75rem; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 1rem;">
                <button type="button" class="btn btn-secondary" onclick="closeBulkPriceModal()">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="submitBulkPriceAdjustment()">Apply to Selected</button>
            </div>
        </div>
    </div>

    <!-- BULK CATEGORY ASSIGN MODAL -->
    <div class="modal-overlay" id="bulk-category-modal" style="z-index: 100001;">
        <div class="modal-container" style="max-width: 440px; background: #0f172a; border: 1px solid rgba(184,137,43,0.3); border-radius: 12px; padding: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 0.75rem;">
                <h3 style="margin: 0; color: #fff; font-size: 1.15rem; font-weight: 800;">Bulk Category Assignment</h3>
                <button type="button" onclick="closeBulkCategoryModal()" style="background: transparent; border: none; color: #94a3b8; font-size: 1.5rem; cursor: pointer;">&times;</button>
            </div>
            <div style="padding: 1.25rem 0;">
                <p style="color: #94a3b8; font-size: 0.88rem; margin-top: 0;">Reassign all <strong id="bulk-cat-count" style="color: #fbbf24;">0</strong> selected products to a new category node.</p>
                <div>
                    <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 6px;">Select New Category Tree Node *</label>
                    <select id="bulk-cat-select" style="width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid rgba(255,255,255,0.2); border-radius: 6px; padding: 0.65rem; color: #fff;">
                        <!-- Categories populated dynamically -->
                    </select>
                </div>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 0.75rem; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 1rem;">
                <button type="button" class="btn btn-secondary" onclick="closeBulkCategoryModal()">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="submitBulkCategoryChange()">Assign Category</button>
            </div>
        </div>
    </div>
"""

if "product-editor-modal" not in html:
    html = html.replace("</body>", editor_modals_html + "\n</body>")
    print("Inserted product-editor-modal before </body> successfully!")

with open("public_web/admin.html", "w", encoding="utf-8") as f:
    f.write(html)

print("public_web/admin.html successfully patched!")
