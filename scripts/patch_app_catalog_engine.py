# scripts/patch_app_catalog_engine.py
import re

print("Upgrading public_web/static/js/app.js with complete Product Suite engine...")

with open("public_web/static/js/app.js", "r", encoding="utf-8") as f:
    js_code = f.read()

# Replace loadCatalog, renderCatalogTable, handleProductSubmit, openEditModal, etc.
# We will replace from `// ADMIN CATALOG OPERATIONS` through `// POINT OF SALE (POS) CASH BILLING`
start_marker = '// ADMIN CATALOG OPERATIONS'
end_marker = '// POINT OF SALE (POS) CASH BILLING'

start_idx = js_code.find(start_marker)
end_idx = js_code.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Markers not found in app.js!")
    exit(1)

new_catalog_engine = """// ADMIN CATALOG OPERATIONS
// ==========================================

// Global state extension for Catalog Suite
if (!state.catalog) {
    state.catalog = {};
}
state.catalog.currentPage = 1;
state.catalog.perPage = 10;
state.catalog.searchQuery = '';
state.catalog.statusFilter = 'all';
state.catalog.categoryFilter = 'all';
state.catalog.sortBy = 'newest';
state.catalog.selectedIds = new Set();
state.catalog.products = [];
state.catalog.counts = { total: 0, published: 0, draft: 0, scheduled: 0, low_stock: 0, out_of_stock: 0, archived: 0 };
state.catalog.editorGallery = [];
state.catalog.isDirty = false;

// 1. Load Dashboard Metrics
async function loadDashboardMetrics() {
    try {
        const response = await fetch('/api/dashboard/metrics');
        const data = await response.json();
        if (response.ok) {
            const totEl = document.getElementById('metric-total-products');
            if (totEl) totEl.innerText = data.total_products || 0;
            const revEl = document.getElementById('metric-total-revenue');
            if (revEl) revEl.innerText = formatINR(data.total_revenue || 0);
            const ordEl = document.getElementById('metric-total-orders');
            if (ordEl) ordEl.innerText = data.total_orders || 0;
            const outEl = document.getElementById('metric-out-of-stock');
            if (outEl) outEl.innerText = data.out_of_stock || 0;
        }
    } catch (err) {
        console.error("loadDashboardMetrics error:", err);
    }
}
window.loadDashboardMetrics = loadDashboardMetrics;

// 2. Fetch Catalog Counts (Actual Database Records)
async function loadCatalogCounts() {
    try {
        const res = await fetch('/api/products/counts');
        if (res.ok) {
            const data = await res.json();
            const c = data.counts || {};
            state.catalog.counts = c;
            
            const setTxt = (id, val) => {
                const el = document.getElementById(id);
                if (el) el.innerText = val !== undefined ? val : 0;
            };
            setTxt('catalog-count-all', c.total);
            setTxt('catalog-count-published', c.published);
            setTxt('catalog-count-draft', c.draft);
            setTxt('catalog-count-scheduled', c.scheduled);
            setTxt('catalog-count-low', c.low_stock);
            setTxt('catalog-count-out', c.out_of_stock);
            setTxt('catalog-count-archived', c.archived);
        }
    } catch(e) {
        console.error("Failed to load catalog counts:", e);
    }
}
window.loadCatalogCounts = loadCatalogCounts;

// 3. Main Catalog Data Fetcher
async function loadCatalog() {
    const page = state.catalog.currentPage || 1;
    const perPage = state.catalog.perPage || 10;
    const search = state.catalog.searchQuery || '';
    const status = state.catalog.statusFilter || 'all';
    const cat = state.catalog.categoryFilter || 'all';
    const sort = state.catalog.sortBy || 'newest';

    const tbody = document.getElementById('catalog-items-body');
    if (tbody) {
        tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: #94a3b8; padding: 3rem;">
            <div class="spinner" style="display: inline-block; margin-bottom: 0.5rem;"></div>
            <div>Loading catalog from cloud database...</div>
        </td></tr>`;
    }

    try {
        // Fetch accurate status counts concurrently
        loadCatalogCounts();

        const url = `/api/products?page=${page}&per_page=${perPage}&status=${encodeURIComponent(status)}&category_id=${encodeURIComponent(cat)}&search=${encodeURIComponent(search)}&sort=${encodeURIComponent(sort)}`;
        let response = await fetch(url);
        response = await handleResponse(response);
        const data = await response.json();

        state.catalog.products = data.products || [];
        state.catalog.totalPages = data.total_pages || 1;
        state.catalog.totalCount = data.total_count || 0;

        renderCatalogTable();
        await loadAdminCategoryDetails();
        loadDashboardMetrics();
    } catch (err) {
        if (err.message !== "Unauthorized") {
            showToast("Error loading catalog: " + err.message, "error");
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: #ef4444; padding: 2.5rem;">
                    Failed to retrieve inventory: ${escapeHtml(err.message)}
                    <div style="margin-top: 8px;">
                        <button class="btn btn-secondary btn-sm" onclick="loadCatalog()">Retry</button>
                    </div>
                </td></tr>`;
            }
        }
    }
}
window.loadCatalog = loadCatalog;

// 4. Render Table
function renderCatalogTable() {
    const tbody = document.getElementById('catalog-items-body');
    if (!tbody) return;
    tbody.innerHTML = '';

    const prods = state.catalog.products || [];

    // Update pagination stats
    const total = state.catalog.totalCount || 0;
    const page = state.catalog.currentPage || 1;
    const perPage = state.catalog.perPage || 10;
    const startIdx = total === 0 ? 0 : (page - 1) * perPage + 1;
    const endIdx = Math.min(page * perPage, total);

    const sEl = document.getElementById('pagination-start');
    if (sEl) sEl.innerText = startIdx;
    const eEl = document.getElementById('pagination-end');
    if (eEl) eEl.innerText = endIdx;
    const tEl = document.getElementById('pagination-total');
    if (tEl) tEl.innerText = total;

    // Check empty state
    if (prods.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" style="text-align: center; padding: 4rem 1.5rem; color: #94a3b8;">
                    <div style="font-size: 3rem; margin-bottom: 0.75rem;">📦</div>
                    <div style="font-size: 1.15rem; font-weight: 800; color: #ffffff; margin-bottom: 0.4rem;">
                        No products match your current view
                    </div>
                    <p style="font-size: 0.88rem; max-width: 460px; margin: 0 auto 1.25rem auto; line-height: 1.5;">
                        Status: <strong>${state.catalog.statusFilter}</strong> | Category: <strong>${state.catalog.categoryFilter}</strong> ${state.catalog.searchQuery ? `| Query: "${escapeHtml(state.catalog.searchQuery)}"` : ''}
                    </p>
                    <div style="display: flex; gap: 0.5rem; justify-content: center;">
                        <button type="button" class="btn btn-secondary btn-sm" onclick="clearAllFilters()" style="background: #1e293b; color: #fff; border: 1px solid rgba(255,255,255,0.2);">Clear Filters</button>
                        <button type="button" class="btn btn-primary btn-sm" onclick="openProductEditor('new')">➕ Register New Product</button>
                    </div>
                </td>
            </tr>
        `;
        renderPaginationButtons();
        updateBulkBarUI();
        return;
    }

    prods.forEach(prod => {
        const tr = document.createElement('tr');
        const isChecked = state.catalog.selectedIds.has(String(prod.id));

        // Media thumbnail & count
        const images = Array.isArray(prod.images) && prod.images.length > 0 ? prod.images : [];
        const imgSrc = prod.image_url || (images[0] ? images[0].url : 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=120&q=80');
        const imgCount = images.length > 1 ? images.length : (prod.image_url ? 1 : 0);

        // Pricing calculations
        const sellPrice = parseFloat(prod.selling_price || prod.price || 0);
        const origPrice = parseFloat(prod.original_price || prod.mrp || sellPrice);
        const discountPct = origPrice > sellPrice ? Math.round(((origPrice - sellPrice) / origPrice) * 100) : 0;

        // Stock pill
        let stockHtml = '';
        const stockQty = parseInt(prod.stock || 0, 10);
        const lowThreshold = parseInt(prod.low_stock_threshold || 10, 10);
        if (stockQty <= 0) {
            stockHtml = `<span class="pill-stock out-of-stock">🔴 Out of Stock</span>`;
        } else if (stockQty <= lowThreshold) {
            stockHtml = `<span class="pill-stock low-stock">⚠️ ${stockQty} units (Low)</span>`;
        } else {
            stockHtml = `<span class="pill-stock in-stock">🟢 ${stockQty} in stock</span>`;
        }

        // Status badge
        let statusBadgeClass = 'published';
        let statusLabel = '🟢 Published';
        if (prod.status === 'draft') {
            statusBadgeClass = 'draft';
            statusLabel = '🔒 Draft';
        } else if (prod.status === 'scheduled') {
            statusBadgeClass = 'scheduled';
            statusLabel = '⏰ Scheduled';
        } else if (prod.status === 'archived') {
            statusBadgeClass = 'archived';
            statusLabel = '📦 Archived';
        }

        // Variants badge
        const variantCount = Array.isArray(prod.variants) ? prod.variants.length : 0;

        // Updated time
        let updatedTimeStr = 'Recently';
        if (prod.updated_at) {
            try {
                const d = new Date(prod.updated_at);
                updatedTimeStr = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
            } catch (_) {}
        }

        tr.innerHTML = `
            <td style="text-align: center;">
                <input type="checkbox" class="product-row-cb" value="${prod.id}" ${isChecked ? 'checked' : ''} onchange="toggleProductSelection('${prod.id}', this.checked)" style="cursor: pointer; width: 16px; height: 16px; accent-color: #d97706;">
            </td>
            <td style="text-align: center;">
                <div class="prod-thumb-wrapper" onclick="openProductEditor('${prod.id}')" style="cursor: pointer;" title="Click to edit product">
                    <img src="${imgSrc}" alt="${escapeHtml(prod.name)}" onerror="this.onerror=null;this.src='https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=120&q=80'">
                    ${imgCount > 1 ? `<span class="prod-img-badge">+${imgCount}</span>` : ''}
                </div>
            </td>
            <td>
                <div class="prod-name-title" onclick="openProductEditor('${prod.id}')" style="cursor: pointer;" title="${escapeHtml(prod.name)}">
                    ${escapeHtml(prod.name)}
                </div>
                <div class="prod-meta-chips">
                    <span class="chip-sku" title="SKU / Barcode">${escapeHtml(prod.sku)}</span>
                    ${prod.brand ? `<span class="chip-brand" title="Brand">🏷️ ${escapeHtml(prod.brand)}</span>` : ''}
                    ${prod.unit ? `<span class="chip-unit" title="Unit">📦 ${escapeHtml(prod.unit)}</span>` : ''}
                    ${variantCount > 0 ? `<span class="chip-variant" title="Product Variants">🔀 ${variantCount} Variants</span>` : ''}
                </div>
            </td>
            <td>
                <span style="font-size: 0.82rem; background: rgba(255,255,255,0.06); padding: 4px 10px; border-radius: 6px; color: #cbd5e1; white-space: nowrap; border: 1px solid rgba(255,255,255,0.1);">
                    ${escapeHtml(prod.category || 'General')}
                </span>
                ${prod.subcategory ? `<div style="font-size: 0.74rem; color: #94a3b8; margin-top: 3px;">${escapeHtml(prod.subcategory)}</div>` : ''}
            </td>
            <td style="text-align: right;">
                <div style="font-weight: 800; color: #fbbf24; font-size: 1.05rem; font-family: 'IBM Plex Mono', monospace;">
                    ₹${sellPrice.toFixed(2)}
                </div>
                ${origPrice > sellPrice ? `
                    <div style="display: flex; gap: 6px; justify-content: flex-end; align-items: center; margin-top: 2px;">
                        <span style="font-size: 0.78rem; color: #64748b; text-decoration: line-through; font-family: 'IBM Plex Mono', monospace;">₹${origPrice.toFixed(2)}</span>
                        <span style="font-size: 0.72rem; color: #10b981; font-weight: 800; background: rgba(16,185,129,0.12); padding: 1px 4px; border-radius: 4px;">${discountPct}% OFF</span>
                    </div>
                ` : ''}
            </td>
            <td style="text-align: center;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 4px;">
                    ${stockHtml}
                    <button type="button" onclick="openQuickStockModal('${prod.id}')" style="background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; color: #cbd5e1; font-size: 0.72rem; padding: 2px 6px; cursor: pointer;" title="Quick restock or adjust inventory">
                        Restock / Adjust
                    </button>
                </div>
            </td>
            <td style="text-align: center;">
                <button type="button" class="badge-status ${statusBadgeClass}" onclick="togglePublishStatus('${prod.id}', '${prod.status === 'published' ? 'draft' : 'published'}')" title="Click to toggle between Published and Draft">
                    ${statusLabel}
                </button>
            </td>
            <td style="text-align: right; padding-right: 1.5rem;">
                <div style="display: inline-flex; gap: 0.4rem; align-items: center;">
                    <button type="button" class="btn btn-secondary btn-sm" onclick="openProductEditor('${prod.id}')" style="display: inline-flex; align-items: center; gap: 4px; background: #1e293b; color: #ffffff; border: 1px solid rgba(184,137,43,0.3); font-weight: 700; padding: 0.45rem 0.85rem; border-radius: 6px; cursor: pointer;" title="Full Product Editor">
                        ✏️ Edit
                    </button>
                    <a href="/store?product=${encodeURIComponent(prod.slug || prod.name)}" target="_blank" style="padding: 0.45rem 0.6rem; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 6px; color: #94a3b8; text-decoration: none; display: inline-flex; align-items: center;" title="View on customer storefront">
                        👁️
                    </a>
                    <button type="button" onclick="duplicateProduct('${prod.id}')" style="padding: 0.45rem 0.6rem; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 6px; color: #94a3b8; cursor: pointer;" title="Duplicate product as draft">
                        📋
                    </button>
                    <button type="button" onclick="deleteProduct('${prod.id}')" style="padding: 0.45rem 0.6rem; background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.3); border-radius: 6px; color: #ef4444; cursor: pointer;" title="Delete or Archive Product">
                        🗑️
                    </button>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });

    renderPaginationButtons();
    updateBulkBarUI();
}
window.renderCatalogTable = renderCatalogTable;

// 5. Pagination Buttons
function renderPaginationButtons() {
    const container = document.getElementById('catalog-pagination');
    if (!container) return;
    container.innerHTML = '';

    const current = state.catalog.currentPage || 1;
    const total = state.catalog.totalPages || 1;

    if (total <= 1) return;

    // Previous Button
    const prevBtn = document.createElement('button');
    prevBtn.className = 'btn btn-secondary btn-sm';
    prevBtn.innerHTML = '&laquo; Prev';
    prevBtn.disabled = current <= 1;
    prevBtn.onclick = () => {
        if (state.catalog.currentPage > 1) {
            state.catalog.currentPage--;
            loadCatalog();
        }
    };
    container.appendChild(prevBtn);

    // Page Numbers
    for (let p = 1; p <= total; p++) {
        if (p === 1 || p === total || (p >= current - 1 && p <= current + 1)) {
            const pBtn = document.createElement('button');
            pBtn.className = `btn btn-sm ${p === current ? 'btn-primary' : 'btn-secondary'}`;
            pBtn.innerText = p;
            pBtn.style.minWidth = '32px';
            pBtn.onclick = () => {
                state.catalog.currentPage = p;
                loadCatalog();
            };
            container.appendChild(pBtn);
        } else if (p === current - 2 || p === current + 2) {
            const dots = document.createElement('span');
            dots.innerText = '...';
            dots.style.color = '#64748b';
            dots.style.padding = '0 4px';
            container.appendChild(dots);
        }
    }

    // Next Button
    const nextBtn = document.createElement('button');
    nextBtn.className = 'btn btn-secondary btn-sm';
    nextBtn.innerHTML = 'Next &raquo;';
    nextBtn.disabled = current >= total;
    nextBtn.onclick = () => {
        if (state.catalog.currentPage < total) {
            state.catalog.currentPage++;
            loadCatalog();
        }
    };
    container.appendChild(nextBtn);
}

// 6. Filter & Search Handlers
function setCatalogFilter(statusName) {
    state.catalog.statusFilter = statusName;
    state.catalog.currentPage = 1;
    document.querySelectorAll('.status-tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.status === statusName);
    });
    loadCatalog();
}
window.setCatalogFilter = setCatalogFilter;

let searchDebounceTimer = null;
function debounceCatalogSearch() {
    clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(() => {
        const input = document.getElementById('catalog-search');
        state.catalog.searchQuery = input ? input.value.trim() : '';
        state.catalog.currentPage = 1;
        loadCatalog();
    }, 300);
}
window.debounceCatalogSearch = debounceCatalogSearch;

function clearCatalogSearch() {
    const input = document.getElementById('catalog-search');
    if (input) input.value = '';
    state.catalog.searchQuery = '';
    state.catalog.currentPage = 1;
    loadCatalog();
}
window.clearCatalogSearch = clearCatalogSearch;

function handleCategoryFilterChange(catVal) {
    state.catalog.categoryFilter = catVal;
    state.catalog.currentPage = 1;
    loadCatalog();
}
window.handleCategoryFilterChange = handleCategoryFilterChange;

function handleSortChange(sortVal) {
    state.catalog.sortBy = sortVal;
    state.catalog.currentPage = 1;
    loadCatalog();
}
window.handleSortChange = handleSortChange;

function handlePageSizeChange(val) {
    state.catalog.perPage = parseInt(val, 10) || 10;
    state.catalog.currentPage = 1;
    loadCatalog();
}
window.handlePageSizeChange = handlePageSizeChange;

function clearAllFilters() {
    state.catalog.statusFilter = 'all';
    state.catalog.categoryFilter = 'all';
    state.catalog.searchQuery = '';
    state.catalog.sortBy = 'newest';
    state.catalog.currentPage = 1;

    const s = document.getElementById('catalog-search');
    if (s) s.value = '';
    const c = document.getElementById('catalog-category-filter');
    if (c) c.value = 'all';
    const sort = document.getElementById('catalog-sort-by');
    if (sort) sort.value = 'newest';

    document.querySelectorAll('.status-tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.status === 'all');
    });

    loadCatalog();
}
window.clearAllFilters = clearAllFilters;

// 7. Bulk Selection Engine
function toggleSelectAll(isChecked) {
    const checkboxes = document.querySelectorAll('.product-row-cb');
    checkboxes.forEach(cb => {
        cb.checked = isChecked;
        if (isChecked) {
            state.catalog.selectedIds.add(cb.value);
        } else {
            state.catalog.selectedIds.delete(cb.value);
        }
    });
    updateBulkBarUI();
}
window.toggleSelectAll = toggleSelectAll;

function toggleProductSelection(prodId, isChecked) {
    if (isChecked) {
        state.catalog.selectedIds.add(String(prodId));
    } else {
        state.catalog.selectedIds.delete(String(prodId));
    }
    updateBulkBarUI();
}
window.toggleProductSelection = toggleProductSelection;

function clearAllSelections() {
    state.catalog.selectedIds.clear();
    const selAll = document.getElementById('select-all-products');
    if (selAll) selAll.checked = false;
    document.querySelectorAll('.product-row-cb').forEach(cb => cb.checked = false);
    updateBulkBarUI();
}
window.clearAllSelections = clearAllSelections;

function updateBulkBarUI() {
    const bar = document.getElementById('bulk-actions-bar');
    const countEl = document.getElementById('bulk-selected-count');
    const count = state.catalog.selectedIds.size;
    if (countEl) countEl.innerText = count;

    if (bar) {
        if (count > 0) {
            bar.classList.add('active');
        } else {
            bar.classList.remove('active');
        }
    }
}

async function executeBulkAction(action, extraPayload = {}) {
    const ids = Array.from(state.catalog.selectedIds);
    if (ids.length === 0) return;

    if (action === 'delete') {
        if (!confirm(`Are you sure you want to permanently delete or archive ${ids.length} selected products?`)) return;
    }

    try {
        const res = await fetch('/api/products/bulk-action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: action,
                product_ids: ids,
                ...extraPayload
            })
        });
        const data = await res.json();
        if (res.ok) {
            showToast(data.message || `Bulk ${action} executed successfully!`);
            clearAllSelections();
            loadCatalog();
        } else {
            showToast(data.error || "Bulk action failed", "error");
        }
    } catch(err) {
        showToast("Error executing bulk action: " + err.message, "error");
    }
}
window.executeBulkAction = executeBulkAction;

// ==========================================================================
// 8. COMPLETE MULTI-SECTION PRODUCT EDITOR CONTROLLER
// ==========================================================================

function switchEditorTab(paneId) {
    document.querySelectorAll('.editor-nav-tab').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.pane === paneId);
    });
    document.querySelectorAll('.editor-tab-pane').forEach(pane => {
        pane.style.display = (pane.id === paneId) ? 'block' : 'none';
    });
}
window.switchEditorTab = switchEditorTab;

function openProductEditor(productId = 'new') {
    const modal = document.getElementById('product-editor-modal');
    if (!modal) return;

    // Reset editor tabs to first pane
    switchEditorTab('pane-basic');
    state.catalog.editorGallery = [];
    state.catalog.isDirty = false;

    // Populate category dropdown
    const catSelect = document.getElementById('m-category-id');
    if (catSelect && state.catalog.categories) {
        catSelect.innerHTML = '<option value="">-- Choose Category --</option>';
        state.catalog.categories.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.id;
            opt.innerText = `${c.icon || '📁'} ${c.name}`;
            catSelect.appendChild(opt);
        });
    }

    const titleEl = document.getElementById('editor-title');
    const badgeEl = document.getElementById('editor-status-badge');
    const previewBtn = document.getElementById('btn-editor-preview');

    if (productId === 'new') {
        if (titleEl) titleEl.innerText = 'Register New Product';
        if (badgeEl) badgeEl.innerHTML = `<span class="badge-status draft">New Item</span>`;
        if (previewBtn) previewBtn.style.display = 'none';

        // Clear all inputs
        document.getElementById('edit-master-id').value = '';
        document.getElementById('m-name').value = '';
        document.getElementById('m-slug').value = '';
        document.getElementById('m-sku').value = `RAMA-${Date.now().toString().slice(-6)}`;
        document.getElementById('m-barcode').value = '';
        document.getElementById('m-brand').value = '';
        document.getElementById('m-subcategory').value = '';
        document.getElementById('m-short-desc').value = '';
        document.getElementById('m-full-desc').value = '';
        document.getElementById('m-features').value = '';
        document.getElementById('m-tags').value = '';
        document.getElementById('m-mrp').value = '';
        document.getElementById('m-selling-price').value = '';
        document.getElementById('m-cost-price').value = '';
        document.getElementById('m-gst-percent').value = '5';
        document.getElementById('m-tax-inclusive').checked = true;
        document.getElementById('m-stock').value = '50';
        document.getElementById('m-low-threshold').value = '10';
        document.getElementById('m-unit').value = 'unit';
        document.getElementById('m-variants-tbody').innerHTML = '';
        document.getElementById('m-weight-kg').value = '';
        document.getElementById('m-dimensions').value = '';
        document.getElementById('m-prep-time').value = '1';
        document.getElementById('m-special-handling').value = 'Standard';
        document.getElementById('m-serviceable-pins').value = '';
        document.getElementById('m-meta-title').value = '';
        document.getElementById('m-meta-desc').value = '';
        document.getElementById('m-keywords').value = '';
        document.getElementById('m-is-featured').checked = false;
        document.getElementById('m-is-homepage').checked = true;
        document.getElementById('m-scheduled-time-container').style.display = 'none';
        document.getElementById('m-audit-timeline').innerHTML = `<div style="color: #94a3b8; font-size: 0.88rem;">New product - not yet saved to database.</div>`;

        // Default radio
        const pubRadio = document.querySelector('input[name="m-status-radio"][value="published"]');
        if (pubRadio) pubRadio.checked = true;

        renderEditorGallery();
        calculatePricingMargins();
        modal.classList.add('active');
    } else {
        // Load existing product
        if (titleEl) titleEl.innerText = `Loading Product #${productId}...`;
        modal.classList.add('active');

        fetch(`/api/products/${productId}`)
            .then(res => res.json())
            .then(data => {
                if (!data.success || !data.product) {
                    showToast("Failed to fetch product details", "error");
                    closeProductEditor();
                    return;
                }
                const p = data.product;
                if (titleEl) titleEl.innerText = `Editing: ${p.name}`;
                if (previewBtn) {
                    previewBtn.style.display = 'inline-flex';
                    previewBtn.onclick = () => window.open(`/store?product=${encodeURIComponent(p.slug || p.name)}`, '_blank');
                }

                let badgeHtml = '<span class="badge-status published">🟢 Published</span>';
                if (p.status === 'draft') badgeHtml = '<span class="badge-status draft">🔒 Draft</span>';
                else if (p.status === 'scheduled') badgeHtml = '<span class="badge-status scheduled">⏰ Scheduled</span>';
                else if (p.status === 'archived') badgeHtml = '<span class="badge-status archived">📦 Archived</span>';
                if (badgeEl) badgeEl.innerHTML = badgeHtml;

                document.getElementById('edit-master-id').value = p.id;
                document.getElementById('m-name').value = p.name || '';
                document.getElementById('m-slug').value = p.slug || '';
                document.getElementById('m-sku').value = p.sku || '';
                document.getElementById('m-barcode').value = p.barcode || '';
                document.getElementById('m-brand').value = p.brand || '';
                if (catSelect && p.category_id) catSelect.value = p.category_id;
                document.getElementById('m-subcategory').value = p.subcategory || '';
                document.getElementById('m-short-desc').value = p.short_description || '';
                document.getElementById('m-full-desc').value = p.description || '';
                document.getElementById('m-features').value = Array.isArray(p.features) ? p.features.join('\\n') : (p.features || '');
                document.getElementById('m-tags').value = Array.isArray(p.tags) ? p.tags.join(', ') : (p.tags || '');

                // Pricing
                document.getElementById('m-mrp').value = p.original_price || p.mrp || '';
                document.getElementById('m-selling-price').value = p.selling_price || p.price || '';
                document.getElementById('m-cost-price').value = p.purchase_price || p.cost_price || '';
                document.getElementById('m-gst-percent').value = String(p.gst_percent !== undefined ? p.gst_percent : '5');
                document.getElementById('m-tax-inclusive').checked = p.tax_inclusive !== undefined ? Boolean(p.tax_inclusive) : true;

                // Inventory
                document.getElementById('m-stock').value = p.stock !== undefined ? p.stock : 0;
                document.getElementById('m-low-threshold').value = p.low_stock_threshold || 10;
                document.getElementById('m-unit').value = p.unit || 'unit';

                // Delivery
                const del = p.delivery || {};
                document.getElementById('m-weight-kg').value = del.weight_kg || '';
                document.getElementById('m-dimensions').value = del.dimensions || '';
                document.getElementById('m-prep-time').value = String(del.prep_time_hours || '1');
                document.getElementById('m-special-handling').value = del.special_handling || 'Standard';
                document.getElementById('m-serviceable-pins').value = del.serviceable_pins || '';

                // SEO
                const seo = p.seo || {};
                document.getElementById('m-meta-title').value = seo.meta_title || '';
                document.getElementById('m-meta-desc').value = seo.meta_description || '';
                document.getElementById('m-keywords').value = seo.keywords || '';
                document.getElementById('m-is-featured').checked = Boolean(seo.is_featured);
                document.getElementById('m-is-homepage').checked = seo.is_homepage !== undefined ? Boolean(seo.is_homepage) : true;

                // Status
                const stRadio = document.querySelector(`input[name="m-status-radio"][value="${p.status || 'published'}"]`);
                if (stRadio) stRadio.checked = true;
                const schedContainer = document.getElementById('m-scheduled-time-container');
                if (schedContainer) {
                    schedContainer.style.display = (p.status === 'scheduled') ? 'block' : 'none';
                    if (p.scheduled_at) {
                        try {
                            const dIso = new Date(p.scheduled_at).toISOString().slice(0, 16);
                            document.getElementById('m-scheduled-at').value = dIso;
                        } catch (_) {}
                    }
                }

                // Gallery
                let images = Array.isArray(p.images) && p.images.length > 0 ? p.images : [];
                if (images.length === 0 && p.image_url) {
                    images = [{ url: p.image_url, is_primary: true }];
                }
                state.catalog.editorGallery = images;
                renderEditorGallery();

                // Variants
                renderVariantsTable(p.variants || []);

                // Audit History
                renderAuditTimeline(p.audit_log || []);

                calculatePricingMargins();
            })
            .catch(err => {
                showToast("Failed to load product: " + err.message, "error");
                closeProductEditor();
            });
    }
}
window.openProductEditor = openProductEditor;
window.openEditModal = openProductEditor;
window.editProduct = openProductEditor;

function closeProductEditor() {
    const modal = document.getElementById('product-editor-modal');
    if (modal) modal.classList.remove('active');
}
window.closeProductEditor = closeProductEditor;

function handleProductNameChange(nameVal) {
    const slugInput = document.getElementById('m-slug');
    const slugPrev = document.getElementById('m-slug-preview');
    if (slugInput) {
        const slug = nameVal.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
        slugInput.value = slug;
        if (slugPrev) slugPrev.innerText = slug;
    }
}
window.handleProductNameChange = handleProductNameChange;

function generateAutoSku() {
    const skuInput = document.getElementById('m-sku');
    if (skuInput) {
        const brand = (document.getElementById('m-brand')?.value || 'RAMA').replace(/[^a-zA-Z]/g, '').slice(0, 4).toUpperCase();
        const rand = Math.floor(1000 + Math.random() * 9000);
        skuInput.value = `${brand}-${rand}`;
        showToast(`Auto-generated SKU: ${skuInput.value}`);
    }
}
window.generateAutoSku = generateAutoSku;

function handlePublicationStatusRadio(statusVal) {
    const schedContainer = document.getElementById('m-scheduled-time-container');
    if (schedContainer) {
        schedContainer.style.display = (statusVal === 'scheduled') ? 'block' : 'none';
    }
}
window.handlePublicationStatusRadio = handlePublicationStatusRadio;

// Gallery Manager in Product Editor
function renderEditorGallery() {
    const grid = document.getElementById('m-gallery-grid');
    const countEl = document.getElementById('m-gallery-count');
    const tabCountEl = document.getElementById('editor-tab-img-count');
    if (!grid) return;

    const list = state.catalog.editorGallery || [];
    if (countEl) countEl.innerText = list.length;
    if (tabCountEl) tabCountEl.innerText = list.length > 0 ? `(${list.length})` : '';

    if (list.length === 0) {
        grid.innerHTML = `<div style="grid-column: 1 / -1; color: #64748b; font-size: 0.85rem; padding: 1rem 0;">No images uploaded yet. Upload high-res photos or add an image URL above.</div>`;
        return;
    }

    grid.innerHTML = '';
    list.forEach((img, idx) => {
        const card = document.createElement('div');
        card.className = `gallery-item-card ${img.is_primary ? 'is-primary' : ''}`;
        card.innerHTML = `
            <img src="${img.url}" alt="Product Photo" onerror="this.onerror=null;this.src='https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=120&q=80'">
            ${img.is_primary ? '<span class="gallery-primary-badge">★ PRIMARY</span>' : ''}
            <div class="gallery-card-actions">
                ${!img.is_primary ? `<button type="button" class="gallery-action-btn" onclick="setPrimaryGalleryImage(${idx})" title="Set as primary cover">⭐</button>` : ''}
                ${idx > 0 ? `<button type="button" class="gallery-action-btn" onclick="moveGalleryImage(${idx}, -1)" title="Move left">◀</button>` : ''}
                ${idx < list.length - 1 ? `<button type="button" class="gallery-action-btn" onclick="moveGalleryImage(${idx}, 1)" title="Move right">▶</button>` : ''}
                <button type="button" class="gallery-action-btn" onclick="removeGalleryImage(${idx})" title="Remove photo" style="color: #ef4444;">🗑️</button>
            </div>
        `;
        grid.appendChild(card);
    });
}

function setPrimaryGalleryImage(idx) {
    const list = state.catalog.editorGallery || [];
    list.forEach((img, i) => img.is_primary = (i === idx));
    renderEditorGallery();
}
window.setPrimaryGalleryImage = setPrimaryGalleryImage;

function moveGalleryImage(idx, dir) {
    const list = state.catalog.editorGallery || [];
    const targetIdx = idx + dir;
    if (targetIdx < 0 || targetIdx >= list.length) return;
    const item = list.splice(idx, 1)[0];
    list.splice(targetIdx, 0, item);
    renderEditorGallery();
}
window.moveGalleryImage = moveGalleryImage;

function removeGalleryImage(idx) {
    const list = state.catalog.editorGallery || [];
    list.splice(idx, 1);
    if (list.length > 0 && !list.some(img => img.is_primary)) {
        list[0].is_primary = true;
    }
    renderEditorGallery();
}
window.removeGalleryImage = removeGalleryImage;

function addDirectUrlToGallery() {
    const input = document.getElementById('m-direct-url-input');
    const url = input ? input.value.trim() : '';
    if (!url) return;
    const list = state.catalog.editorGallery || [];
    list.push({ url, is_primary: list.length === 0 });
    input.value = '';
    renderEditorGallery();
    showToast("Photo added to gallery");
}
window.addDirectUrlToGallery = addDirectUrlToGallery;

async function handleEditorGalleryFiles(files) {
    if (!files || files.length === 0) return;
    const progressEl = document.getElementById('m-upload-progress-bar');
    if (progressEl) {
        progressEl.style.display = 'block';
        progressEl.innerText = `⏳ Preparing and compressing ${files.length} photo(s)...`;
    }

    for (let i = 0; i < files.length; i++) {
        const file = files[i];
        if (!file.type.startsWith('image/')) continue;

        try {
            if (progressEl) progressEl.innerText = `⏳ Uploading ${file.name} to Firebase Storage (${i+1}/${files.length})...`;
            const base64Data = await readFileAndCompress(file, 1200, 0.85);

            const uploadRes = await fetch('/api/upload/image', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image_data: base64Data, filename: file.name })
            });
            const uploadData = await uploadRes.json();
            if (uploadRes.ok && uploadData.url) {
                const list = state.catalog.editorGallery || [];
                list.push({ url: uploadData.url, is_primary: list.length === 0 });
                renderEditorGallery();
            } else {
                showToast(`Failed to upload ${file.name}: ${uploadData.error || 'Server error'}`, 'error');
            }
        } catch(err) {
            showToast(`Upload error for ${file.name}: ${err.message}`, 'error');
        }
    }

    if (progressEl) {
        progressEl.innerText = '✅ Images stored on CDN successfully!';
        setTimeout(() => progressEl.style.display = 'none', 2500);
    }
}
window.handleEditorGalleryFiles = handleEditorGalleryFiles;

// Dynamic Variant Table
function renderVariantsTable(variants = []) {
    const tbody = document.getElementById('m-variants-tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    variants.forEach((v, idx) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td style="padding: 6px;"><input type="text" value="${escapeHtml(v.name || '')}" class="v-name" placeholder="e.g. 500 g" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fff;"></td>
            <td style="padding: 6px;"><input type="text" value="${escapeHtml(v.sku || '')}" class="v-sku" placeholder="SKU" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fff; font-family: monospace;"></td>
            <td style="padding: 6px;"><input type="number" step="0.01" value="${v.price || ''}" class="v-price" placeholder="₹" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fbbf24; text-align: right; font-weight: 700;"></td>
            <td style="padding: 6px;"><input type="number" step="0.01" value="${v.mrp || ''}" class="v-mrp" placeholder="₹" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #94a3b8; text-align: right;"></td>
            <td style="padding: 6px;"><input type="number" value="${v.stock !== undefined ? v.stock : ''}" class="v-stock" placeholder="Stock" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #34d399; text-align: center; font-weight: 700;"></td>
            <td style="padding: 6px; text-align: center;"><button type="button" onclick="this.closest('tr').remove()" style="background: transparent; border: none; color: #ef4444; font-size: 1rem; cursor: pointer;">&times;</button></td>
        `;
        tbody.appendChild(tr);
    });
}

function addNewVariantRow() {
    const tbody = document.getElementById('m-variants-tbody');
    if (!tbody) return;
    const parentSku = document.getElementById('m-sku')?.value || 'SKU';
    const rand = Math.floor(10 + Math.random() * 90);
    const tr = document.createElement('tr');
    tr.innerHTML = `
        <td style="padding: 6px;"><input type="text" class="v-name" placeholder="e.g. 1 kg / Large" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fff;"></td>
        <td style="padding: 6px;"><input type="text" class="v-sku" value="${parentSku}-V${rand}" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fff; font-family: monospace;"></td>
        <td style="padding: 6px;"><input type="number" step="0.01" class="v-price" placeholder="₹" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #fbbf24; text-align: right; font-weight: 700;"></td>
        <td style="padding: 6px;"><input type="number" step="0.01" class="v-mrp" placeholder="₹" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #94a3b8; text-align: right;"></td>
        <td style="padding: 6px;"><input type="number" class="v-stock" value="20" style="width: 100%; box-sizing: border-box; background: rgba(15,23,42,0.8); border: 1px solid rgba(255,255,255,0.15); border-radius: 4px; padding: 4px 6px; color: #34d399; text-align: center; font-weight: 700;"></td>
        <td style="padding: 6px; text-align: center;"><button type="button" onclick="this.closest('tr').remove()" style="background: transparent; border: none; color: #ef4444; font-size: 1rem; cursor: pointer;">&times;</button></td>
    `;
    tbody.appendChild(tr);
}
window.addNewVariantRow = addNewVariantRow;

// Live Financial Margin Calculator
function calculatePricingMargins() {
    const mrp = parseFloat(document.getElementById('m-mrp')?.value || 0);
    const sell = parseFloat(document.getElementById('m-selling-price')?.value || 0);
    const cost = parseFloat(document.getElementById('m-cost-price')?.value || 0);

    const discountEl = document.getElementById('m-calc-discount');
    const profitEl = document.getElementById('m-calc-profit');
    const marginEl = document.getElementById('m-calc-margin');

    if (discountEl) {
        if (mrp > sell && sell > 0) {
            const disc = mrp - sell;
            const pct = Math.round((disc / mrp) * 100);
            discountEl.innerText = `₹${disc.toFixed(2)} (${pct}% OFF)`;
        } else {
            discountEl.innerText = '₹0.00 (0% OFF)';
        }
    }

    if (profitEl && marginEl) {
        if (sell > 0 && cost > 0) {
            const profit = sell - cost;
            const margin = ((profit / sell) * 100).toFixed(1);
            profitEl.innerText = `₹${profit.toFixed(2)} / unit`;
            marginEl.innerText = `${margin}% margin`;
        } else {
            profitEl.innerText = '--';
            marginEl.innerText = '--';
        }
    }
}
window.calculatePricingMargins = calculatePricingMargins;

// Audit Timeline Renderer
function renderAuditTimeline(logs = []) {
    const container = document.getElementById('m-audit-timeline');
    if (!container) return;
    if (logs.length === 0) {
        container.innerHTML = `<div style="color: #94a3b8; font-size: 0.88rem;">No historical changes recorded for this item yet.</div>`;
        return;
    }
    container.innerHTML = logs.map(l => `
        <div style="background: rgba(15, 23, 42, 0.6); border-left: 3px solid #f59e0b; padding: 0.75rem 1rem; border-radius: 4px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                <span style="font-weight: 700; color: #fbbf24; font-size: 0.85rem; text-transform: uppercase;">${escapeHtml(l.action)}</span>
                <span style="color: #64748b; font-size: 0.75rem; font-family: monospace;">${escapeHtml(l.timestamp || '')}</span>
            </div>
            <div style="color: #f8fafc; font-size: 0.85rem;">${escapeHtml(l.summary || '')}</div>
            <div style="color: #94a3b8; font-size: 0.75rem; margin-top: 2px;">By: <strong>${escapeHtml(l.changed_by || 'Admin')}</strong></div>
        </div>
    `).join('');
}

// Master Product Submission
function submitProductWithStatus(forcedStatus) {
    const rad = document.querySelector(`input[name="m-status-radio"][value="${forcedStatus}"]`);
    if (rad) rad.checked = true;
    handleMasterProductSubmit(null, forcedStatus);
}
window.submitProductWithStatus = submitProductWithStatus;

async function handleMasterProductSubmit(e, overrideStatus) {
    if (e && e.preventDefault) e.preventDefault();

    const id = document.getElementById('edit-master-id').value;
    const name = (document.getElementById('m-name')?.value || '').trim();
    const slug = (document.getElementById('m-slug')?.value || '').trim();
    const sku = (document.getElementById('m-sku')?.value || '').trim();
    const barcode = (document.getElementById('m-barcode')?.value || '').trim();
    const brand = (document.getElementById('m-brand')?.value || '').trim();
    const category_id = document.getElementById('m-category-id')?.value || '';
    const subcategory = (document.getElementById('m-subcategory')?.value || '').trim();
    const short_description = (document.getElementById('m-short-desc')?.value || '').trim();
    const description = (document.getElementById('m-full-desc')?.value || '').trim();
    const features = (document.getElementById('m-features')?.value || '').split('\\n').map(s => s.trim()).filter(Boolean);
    const tags = (document.getElementById('m-tags')?.value || '').split(',').map(s => s.trim()).filter(Boolean);

    // Pricing
    const mrp = parseFloat(document.getElementById('m-mrp')?.value || 0);
    const selling_price = parseFloat(document.getElementById('m-selling-price')?.value || 0);
    const purchase_price = parseFloat(document.getElementById('m-cost-price')?.value || 0);
    const gst_percent = parseFloat(document.getElementById('m-gst-percent')?.value || 5);
    const tax_inclusive = document.getElementById('m-tax-inclusive')?.checked;

    // Inventory
    const stock = parseInt(document.getElementById('m-stock')?.value || 0, 10);
    const low_stock_threshold = parseInt(document.getElementById('m-low-threshold')?.value || 10, 10);
    const unit = (document.getElementById('m-unit')?.value || 'unit').trim();

    // Delivery
    const delivery = {
        weight_kg: parseFloat(document.getElementById('m-weight-kg')?.value || 0),
        dimensions: (document.getElementById('m-dimensions')?.value || '').trim(),
        prep_time_hours: parseInt(document.getElementById('m-prep-time')?.value || 1, 10),
        special_handling: document.getElementById('m-special-handling')?.value || 'Standard',
        serviceable_pins: (document.getElementById('m-serviceable-pins')?.value || '').trim()
    };

    // SEO
    const seo = {
        meta_title: (document.getElementById('m-meta-title')?.value || '').trim(),
        meta_description: (document.getElementById('m-meta-desc')?.value || '').trim(),
        keywords: (document.getElementById('m-keywords')?.value || '').trim(),
        is_featured: Boolean(document.getElementById('m-is-featured')?.checked),
        is_homepage: Boolean(document.getElementById('m-is-homepage')?.checked)
    };

    // Status
    const selectedRadio = document.querySelector('input[name="m-status-radio"]:checked');
    let status = overrideStatus || (selectedRadio ? selectedRadio.value : 'published');
    const scheduled_at = (status === 'scheduled') ? document.getElementById('m-scheduled-at')?.value : null;

    // Images
    const images = state.catalog.editorGallery || [];

    // Collect Variants
    const variants = [];
    document.querySelectorAll('#m-variants-tbody tr').forEach(row => {
        const vName = row.querySelector('.v-name')?.value?.trim();
        const vSku = row.querySelector('.v-sku')?.value?.trim();
        const vPrice = parseFloat(row.querySelector('.v-price')?.value || 0);
        const vMrp = parseFloat(row.querySelector('.v-mrp')?.value || 0);
        const vStock = parseInt(row.querySelector('.v-stock')?.value || 0, 10);
        if (vName) {
            variants.push({ name: vName, sku: vSku, price: vPrice, mrp: vMrp, stock: vStock });
        }
    });

    // Validations
    if (!name) {
        showToast("Product name is required", "error");
        switchEditorTab('pane-basic');
        document.getElementById('m-name')?.focus();
        return;
    }
    if (!sku) {
        showToast("SKU code is required", "error");
        switchEditorTab('pane-basic');
        document.getElementById('m-sku')?.focus();
        return;
    }
    if (isNaN(selling_price) || selling_price <= 0) {
        showToast("Please enter a valid selling price greater than 0", "error");
        switchEditorTab('pane-pricing');
        document.getElementById('m-selling-price')?.focus();
        return;
    }

    const payload = {
        name,
        slug,
        sku,
        barcode,
        brand,
        category_id,
        subcategory,
        short_description,
        description,
        features,
        tags,
        selling_price,
        original_price: mrp >= selling_price ? mrp : selling_price,
        mrp: mrp >= selling_price ? mrp : selling_price,
        purchase_price,
        cost_price: purchase_price,
        gst_percent,
        tax_inclusive,
        stock,
        low_stock_threshold,
        unit,
        images,
        image_url: images.length > 0 ? (images.find(i => i.is_primary)?.url || images[0].url) : '',
        variants,
        delivery,
        seo,
        status,
        scheduled_at
    };

    const isEdit = Boolean(id);
    if (isEdit) payload.product_id = id;

    const savePublishBtn = document.getElementById('btn-save-publish');
    const saveDraftBtn = document.getElementById('btn-save-draft');
    if (savePublishBtn) { savePublishBtn.disabled = true; savePublishBtn.innerText = 'Saving...'; }
    if (saveDraftBtn) { saveDraftBtn.disabled = true; }

    try {
        const method = isEdit ? 'PUT' : 'POST';
        const url = '/api/products';
        let res = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        res = await handleResponse(res);
        const data = await res.json();

        if (savePublishBtn) { savePublishBtn.disabled = false; savePublishBtn.innerText = '🚀 Save & Publish Live'; }
        if (saveDraftBtn) { saveDraftBtn.disabled = false; }

        if (res.ok) {
            showToast(status === 'published' ? `✅ "${name}" saved & published LIVE on storefront!` : `✅ "${name}" saved as ${status}.`);
            closeProductEditor();
            loadCatalog();
        } else {
            showToast(data.error || "Failed to save product", "error");
        }
    } catch(err) {
        if (savePublishBtn) { savePublishBtn.disabled = false; savePublishBtn.innerText = '🚀 Save & Publish Live'; }
        if (saveDraftBtn) { saveDraftBtn.disabled = false; }
        showToast("Connection error: " + err.message, "error");
    }
}
window.handleMasterProductSubmit = handleMasterProductSubmit;

// 9. Quick Restock Modal
let activeQuickStockId = null;
function openQuickStockModal(productId) {
    activeQuickStockId = productId;
    const prod = state.catalog.products.find(p => String(p.id) === String(productId));
    const modal = document.getElementById('quick-stock-modal');
    const nameEl = document.getElementById('quick-stock-prod-name');
    const input = document.getElementById('quick-stock-input');
    const reason = document.getElementById('quick-stock-reason');

    if (nameEl) nameEl.innerText = prod ? `${prod.name} (Current Stock: ${prod.stock} units)` : `Product #${productId}`;
    if (input) input.value = prod ? prod.stock : 0;
    if (reason) reason.value = '';
    if (modal) modal.classList.add('active');
}
window.openQuickStockModal = openQuickStockModal;

function closeQuickStockModal() {
    const modal = document.getElementById('quick-stock-modal');
    if (modal) modal.classList.remove('active');
    activeQuickStockId = null;
}
window.closeQuickStockModal = closeQuickStockModal;

async function submitQuickStock() {
    if (!activeQuickStockId) return;
    const stockVal = parseInt(document.getElementById('quick-stock-input')?.value || 0, 10);
    const reasonVal = document.getElementById('quick-stock-reason')?.value || 'Quick Stock Adjustment';

    try {
        const res = await fetch(`/api/products/${activeQuickStockId}/stock`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ absolute: stockVal, reason: reasonVal })
        });
        const data = await res.json();
        if (res.ok) {
            showToast(`✅ Stock updated to ${stockVal} units!`);
            closeQuickStockModal();
            loadCatalog();
        } else {
            showToast(data.error || "Failed to update stock", "error");
        }
    } catch(err) {
        showToast("Error updating stock: " + err.message, "error");
    }
}
window.submitQuickStock = submitQuickStock;

// 10. Duplicate Product
async function duplicateProduct(productId) {
    if (!confirm("Duplicate this product as a draft copy?")) return;
    try {
        const res = await fetch(`/api/products/${productId}/duplicate`, { method: 'POST' });
        const data = await res.json();
        if (res.ok) {
            showToast(data.message || "Product duplicated successfully!");
            loadCatalog();
        } else {
            showToast(data.error || "Failed to duplicate", "error");
        }
    } catch(err) {
        showToast("Error: " + err.message, "error");
    }
}
window.duplicateProduct = duplicateProduct;

// 11. Delete / Archive Product
async function deleteProduct(productId) {
    const prod = state.catalog.products.find(p => String(p.id) === String(productId));
    const pName = prod ? prod.name : `Product #${productId}`;

    if (!confirm(`Are you sure you want to delete "${pName}"?\\n\\nIf this product has been ordered by customers, it will be safely archived instead of deleted to protect customer receipts.`)) {
        return;
    }

    try {
        const res = await fetch(`/api/products/delete/${productId}`, { method: 'DELETE' });
        const data = await res.json();
        if (res.ok) {
            showToast(data.message || `"${pName}" removed.`);
            loadCatalog();
        } else {
            showToast(data.error || "Failed to delete product", "error");
        }
    } catch(err) {
        showToast("Delete failed: " + err.message, "error");
    }
}
window.deleteProduct = deleteProduct;

// 12. Bulk Modals: Price & Category
function openBulkPriceModal() {
    const count = state.catalog.selectedIds.size;
    const countEl = document.getElementById('bulk-price-count');
    if (countEl) countEl.innerText = count;
    const modal = document.getElementById('bulk-price-modal');
    if (modal) modal.classList.add('active');
}
window.openBulkPriceModal = openBulkPriceModal;

function closeBulkPriceModal() {
    const modal = document.getElementById('bulk-price-modal');
    if (modal) modal.classList.remove('active');
}
window.closeBulkPriceModal = closeBulkPriceModal;

function submitBulkPriceAdjustment() {
    const type = document.getElementById('bulk-price-type')?.value;
    const val = parseFloat(document.getElementById('bulk-price-val')?.value || 0);
    if (!val) {
        showToast("Please enter an adjustment value", "error");
        return;
    }
    const payload = (type === 'percent') ? { percent: val } : { delta: val };
    executeBulkAction('adjust_price', { value: payload });
    closeBulkPriceModal();
}
window.submitBulkPriceAdjustment = submitBulkPriceAdjustment;

function openBulkCategoryModal() {
    const count = state.catalog.selectedIds.size;
    const countEl = document.getElementById('bulk-cat-count');
    if (countEl) countEl.innerText = count;
    const select = document.getElementById('bulk-cat-select');
    if (select && state.catalog.categories) {
        select.innerHTML = state.catalog.categories.map(c => `<option value="${c.id}">${c.name}</option>`).join('');
    }
    const modal = document.getElementById('bulk-category-modal');
    if (modal) modal.classList.add('active');
}
window.openBulkCategoryModal = openBulkCategoryModal;

function closeBulkCategoryModal() {
    const modal = document.getElementById('bulk-category-modal');
    if (modal) modal.classList.remove('active');
}
window.closeBulkCategoryModal = closeBulkCategoryModal;

function submitBulkCategoryChange() {
    const catId = document.getElementById('bulk-cat-select')?.value;
    if (!catId) return;
    executeBulkAction('category', { value: catId });
    closeBulkCategoryModal();
}
window.submitBulkCategoryChange = submitBulkCategoryChange;

function togglePublishStatus(productId, targetStatus) {
    fetch(`/api/products/${productId}/publish`, { method: 'PATCH' })
        .then(res => res.json())
        .then(data => {
            showToast(data.message || `Product status changed to ${targetStatus}`);
            loadCatalog();
        })
        .catch(err => showToast("Error: " + err.message, "error"));
}
window.togglePublishStatus = togglePublishStatus;

"""

js_code = js_code[:start_idx] + new_catalog_engine + js_code[end_idx:]

with open("public_web/static/js/app.js", "w", encoding="utf-8") as f:
    f.write(js_code)

print("public_web/static/js/app.js successfully patched!")
