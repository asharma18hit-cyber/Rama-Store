# scripts/generate_admin_css.py
css_append = """
/* ==========================================================================
   PRODUCTION SAMAUR MART ADMIN CONSOLE & PRODUCT EDITOR SUITE
   ========================================================================== */

/* 1. Universal Dark Theme Override for Admin Console Cards */
.admin-body .card,
.inventory-table-card,
#product-form-card,
.checkout-card,
.cart-card,
.summary-card {
    background: #0d1527 !important;
    border: 1px solid rgba(184, 137, 43, 0.28) !important;
    border-radius: 12px !important;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5) !important;
    color: #f8fafc !important;
}

.admin-body .card-header,
.inventory-table-card .card-header {
    background: #111c35 !important;
    border-bottom: 1px solid rgba(184, 137, 43, 0.2) !important;
    padding: 1.25rem 1.5rem !important;
}

.admin-body .card-header h2,
.admin-body .card-header h3 {
    color: #ffffff !important;
    font-weight: 800 !important;
    letter-spacing: -0.01em !important;
}

.admin-body .card-header p {
    color: #94a3b8 !important;
    margin: 4px 0 0 0 !important;
}

/* 2. Toolbar & Filter Controls */
.catalog-toolbar-grid {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1.25rem;
}

.catalog-search-box {
    position: relative;
    display: inline-flex;
    align-items: center;
}

.catalog-search-box input {
    padding: 0.65rem 2.2rem 0.65rem 1.2rem;
    font-size: 0.9rem;
    border-radius: 24px;
    background: rgba(15, 23, 42, 0.9);
    border: 1px solid rgba(184, 137, 43, 0.3);
    color: #ffffff;
    width: 260px;
    transition: all 0.2s ease;
}

.catalog-search-box input:focus {
    outline: none;
    border-color: #f59e0b;
    box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.25);
    width: 300px;
}

.catalog-select-filter {
    padding: 0.65rem 1rem;
    font-size: 0.88rem;
    border-radius: 8px;
    background: #1e293b;
    border: 1px solid rgba(255, 255, 255, 0.15);
    color: #f8fafc;
    cursor: pointer;
}

.catalog-select-filter:focus {
    outline: none;
    border-color: #f59e0b;
}

/* 3. Status Filter Navigation Pills */
.status-tabs-container {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.85rem;
    margin-bottom: 1rem;
}

.status-tab-btn {
    padding: 0.5rem 1rem;
    font-size: 0.85rem;
    font-weight: 700;
    border-radius: 20px;
    background: rgba(30, 41, 59, 0.6);
    color: #94a3b8;
    border: 1px solid rgba(255, 255, 255, 0.1);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    transition: all 0.2s ease;
}

.status-tab-btn:hover {
    background: rgba(245, 158, 11, 0.12);
    color: #f8fafc;
    border-color: rgba(245, 158, 11, 0.4);
}

.status-tab-btn.active {
    background: #d97706 !important;
    color: #ffffff !important;
    border-color: #f59e0b !important;
    box-shadow: 0 4px 12px rgba(217, 119, 6, 0.35);
}

.status-tab-btn .tab-count {
    background: rgba(0, 0, 0, 0.35);
    padding: 2px 7px;
    border-radius: 12px;
    font-size: 0.76rem;
    font-family: 'IBM Plex Mono', monospace;
}

/* 4. Floating Bulk Actions Bar */
.bulk-actions-bar {
    display: none;
    align-items: center;
    justify-content: space-between;
    background: linear-gradient(90deg, #1e293b, #0f172a);
    border: 1px solid #f59e0b;
    border-radius: 10px;
    padding: 0.75rem 1.25rem;
    margin-bottom: 1rem;
    box-shadow: 0 8px 24px rgba(245, 158, 11, 0.2);
    animation: slideDown 0.25s ease forwards;
}

.bulk-actions-bar.active {
    display: flex !important;
}

@keyframes slideDown {
    from { opacity: 0; transform: translateY(-8px); }
    to { opacity: 1; transform: translateY(0); }
}

/* 5. Production Catalog Table Styling */
.admin-catalog-table {
    width: 100%;
    min-width: 1080px;
    border-collapse: collapse;
    font-size: 0.9rem;
}

.admin-catalog-table thead tr {
    background: #0b1220;
    border-bottom: 2px solid rgba(184, 137, 43, 0.3);
    text-transform: uppercase;
    font-size: 0.75rem;
    letter-spacing: 0.05em;
    color: #94a3b8;
}

.admin-catalog-table th {
    padding: 14px 12px;
    font-weight: 700;
}

.admin-catalog-table tbody tr {
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    transition: background 0.15s ease;
}

.admin-catalog-table tbody tr:hover {
    background: rgba(245, 158, 11, 0.04);
}

.admin-catalog-table td {
    padding: 14px 12px;
    vertical-align: middle;
}

.prod-thumb-wrapper {
    position: relative;
    width: 50px;
    height: 50px;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.15);
    background: #0f172a;
    display: flex;
    align-items: center;
    justify-content: center;
}

.prod-thumb-wrapper img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.2s ease;
}

.prod-thumb-wrapper:hover img {
    transform: scale(1.15);
}

.prod-img-badge {
    position: absolute;
    bottom: 2px;
    right: 2px;
    background: rgba(0, 0, 0, 0.75);
    color: #fff;
    font-size: 0.65rem;
    font-weight: 700;
    padding: 1px 4px;
    border-radius: 4px;
}

.prod-name-title {
    font-weight: 700;
    color: #ffffff;
    font-size: 0.95rem;
    line-height: 1.35;
    margin-bottom: 4px;
}

.prod-meta-chips {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-wrap: wrap;
}

.chip-sku {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.74rem;
    color: #cbd5e1;
    background: rgba(255, 255, 255, 0.08);
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.chip-brand {
    font-size: 0.74rem;
    color: #f59e0b;
    background: rgba(245, 158, 11, 0.1);
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
}

.chip-unit {
    font-size: 0.74rem;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.1);
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
}

.chip-variant {
    font-size: 0.74rem;
    color: #a855f7;
    background: rgba(168, 85, 247, 0.1);
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
}

/* Status Badges */
.badge-status {
    padding: 0.35rem 0.75rem;
    border-radius: 6px;
    font-size: 0.8rem;
    font-weight: 700;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    cursor: pointer;
    border: none;
    transition: all 0.15s ease;
    white-space: nowrap;
}

.badge-status.published {
    background: #064e3b;
    color: #34d399;
    border: 1px solid #059669;
}
.badge-status.published:hover {
    background: #047857;
    color: #fff;
}

.badge-status.draft {
    background: #78350f;
    color: #fcd34d;
    border: 1px solid #d97706;
}
.badge-status.draft:hover {
    background: #b45309;
    color: #fff;
}

.badge-status.scheduled {
    background: #581c87;
    color: #d8b4fe;
    border: 1px solid #9333ea;
}

.badge-status.archived {
    background: #1e293b;
    color: #94a3b8;
    border: 1px solid #475569;
}

/* Stock Pills */
.pill-stock {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border-radius: 12px;
    font-size: 0.78rem;
    font-weight: 700;
    font-family: 'IBM Plex Mono', monospace;
}

.pill-stock.in-stock {
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.35);
}

.pill-stock.low-stock {
    background: rgba(245, 158, 11, 0.18);
    color: #f59e0b;
    border: 1px solid rgba(245, 158, 11, 0.4);
}

.pill-stock.out-of-stock {
    background: rgba(239, 68, 68, 0.18);
    color: #ef4444;
    border: 1px solid rgba(239, 68, 68, 0.4);
}

/* 6. Product Editor Modal & Drawer Architecture */
.editor-modal-container {
    background: #090e1a !important;
    border: 1px solid rgba(184, 137, 43, 0.35) !important;
    border-radius: 14px !important;
    width: 95% !important;
    max-width: 1140px !important;
    height: 90vh !important;
    display: flex !important;
    flex-direction: column !important;
    padding: 0 !important;
    box-shadow: 0 25px 60px rgba(0, 0, 0, 0.8) !important;
    overflow: hidden !important;
}

.editor-header-bar {
    background: #111c35;
    border-bottom: 1px solid rgba(184, 137, 43, 0.25);
    padding: 1rem 1.75rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-shrink: 0;
}

.editor-body-layout {
    display: grid;
    grid-template-columns: 240px 1fr;
    flex: 1;
    overflow: hidden;
}

.editor-sidebar-nav {
    background: #0b1220;
    border-right: 1px solid rgba(255, 255, 255, 0.08);
    padding: 1.25rem 0.75rem;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
}

.editor-nav-tab {
    padding: 0.75rem 1rem;
    border-radius: 8px;
    font-size: 0.88rem;
    font-weight: 600;
    color: #94a3b8;
    background: transparent;
    border: none;
    text-align: left;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 10px;
    transition: all 0.15s ease;
}

.editor-nav-tab:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #f8fafc;
}

.editor-nav-tab.active {
    background: rgba(245, 158, 11, 0.15);
    color: #fbbf24;
    font-weight: 700;
    border-left: 3px solid #f59e0b;
}

.editor-content-pane {
    padding: 2rem;
    overflow-y: auto;
    background: #0d1527;
}

.editor-section-card {
    background: rgba(17, 28, 53, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
}

.editor-section-card h4 {
    margin: 0 0 1rem 0;
    font-size: 1.05rem;
    font-weight: 700;
    color: #ffffff;
    display: flex;
    align-items: center;
    gap: 8px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.75rem;
}

.editor-footer-bar {
    background: #111c35;
    border-top: 1px solid rgba(184, 137, 43, 0.25);
    padding: 1rem 1.75rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-shrink: 0;
}

/* Image gallery manager */
.editor-gallery-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}

.gallery-item-card {
    position: relative;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.15);
    background: #090e1a;
    aspect-ratio: 1;
    display: flex;
    align-items: center;
    justify-content: center;
}

.gallery-item-card img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.gallery-item-card.is-primary {
    border: 2px solid #f59e0b;
    box-shadow: 0 0 10px rgba(245, 158, 11, 0.35);
}

.gallery-primary-badge {
    position: absolute;
    top: 4px;
    left: 4px;
    background: #f59e0b;
    color: #0f172a;
    font-size: 0.68rem;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 4px;
}

.gallery-card-actions {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: rgba(15, 23, 42, 0.9);
    display: flex;
    justify-content: space-around;
    padding: 4px;
    opacity: 0;
    transition: opacity 0.2s ease;
}

.gallery-item-card:hover .gallery-card-actions {
    opacity: 1;
}

.gallery-action-btn {
    background: transparent;
    border: none;
    color: #cbd5e1;
    cursor: pointer;
    font-size: 0.85rem;
    padding: 2px 4px;
}

.gallery-action-btn:hover {
    color: #ffffff;
}

@media (max-width: 900px) {
    .editor-body-layout {
        grid-template-columns: 1fr;
    }
    .editor-sidebar-nav {
        flex-direction: row;
        overflow-x: auto;
        border-right: none;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        padding: 0.5rem;
    }
    .editor-nav-tab {
        white-space: nowrap;
        padding: 0.5rem 0.75rem;
    }
}
"""

with open("public_web/static/css/style.css", "a", encoding="utf-8") as f:
    f.write("\n" + css_append)

print("Appended production CSS to public_web/static/css/style.css successfully!")
