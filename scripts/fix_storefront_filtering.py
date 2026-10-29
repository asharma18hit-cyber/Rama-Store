# scripts/fix_storefront_filtering.py

# 1. Update functions/index.js handleProducts
with open("functions/index.js", "r", encoding="utf-8") as f:
    fn_text = f.read()

target_filter = """      // 1. Storefront / Public filtering: Only show published, approved products that are not scheduled in future or archived
      const isPublicStore = isStorefront || (!req.isAdmin && statusFilter !== "all" && statusFilter !== "draft" && statusFilter !== "archived");
      if (isPublicStore) {
        if (status === "archived") return;
        if (status === "draft") return;
        if (status === "scheduled" && scheduledAt && scheduledAt > now) return;
        if (status !== "published" && status !== "scheduled") return;
        // Strict Multi-Vendor rule: Vendor products must be approved by Owner before public storefront publication
        if (d.approval_status === "pending_review" || d.approval_status === "rejected" || d.approval_status === "changes_requested") return;
      }"""

rep_filter = """      // 1. Storefront / Public customer filtering:
      // If caller is NOT an authenticated Admin, strictly restrict to published, approved items
      const isPublicStore = isStorefront || !req.isAdmin;
      if (isPublicStore) {
        if (status === "archived") return;
        if (status === "draft") return;
        if (status === "scheduled" && scheduledAt && scheduledAt > now) return;
        if (status !== "published" && status !== "scheduled") return;
        // Strict Multi-Vendor rule: Vendor products must be approved by Owner before public storefront publication
        if (d.approval_status === "pending_review" || d.approval_status === "rejected" || d.approval_status === "changes_requested") return;
        if (d.vendor_id && d.vendor_id !== "owner" && d.approval_status !== "approved") return;
      }"""

assert target_filter in fn_text, "target_filter not found in functions/index.js"
fn_text = fn_text.replace(target_filter, rep_filter, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(fn_text)

print("Updated functions/index.js storefront filtering rule!")

# 2. Update app.js loadCatalog and loadCatalogCounts to include Admin Authorization header
with open("public_web/static/js/app.js", "r", encoding="utf-8") as f:
    app_text = f.read()

target_catalog_fetch = """        const url = `/api/products?page=${page}&per_page=${perPage}&status=${encodeURIComponent(status)}&category_id=${encodeURIComponent(cat)}&search=${encodeURIComponent(search)}&sort=${encodeURIComponent(sort)}`;
        let response = await fetch(url);"""

rep_catalog_fetch = """        const url = `/api/products?page=${page}&per_page=${perPage}&status=${encodeURIComponent(status)}&category_id=${encodeURIComponent(cat)}&search=${encodeURIComponent(search)}&sort=${encodeURIComponent(sort)}`;
        const admToken = localStorage.getItem('adminToken') || localStorage.getItem('admin_token');
        const admHeaders = admToken ? { 'Authorization': `Bearer ${admToken}` } : {};
        let response = await fetch(url, { headers: admHeaders });"""

assert target_catalog_fetch in app_text, "target_catalog_fetch not found in app.js"
app_text = app_text.replace(target_catalog_fetch, rep_catalog_fetch, 1)

target_counts_fetch = """        const res = await fetch('/api/products/counts');"""
rep_counts_fetch = """        const admToken = localStorage.getItem('adminToken') || localStorage.getItem('admin_token');
        const admHeaders = admToken ? { 'Authorization': `Bearer ${admToken}` } : {};
        const res = await fetch('/api/products/counts', { headers: admHeaders });"""

assert target_counts_fetch in app_text, "target_counts_fetch not found in app.js"
app_text = app_text.replace(target_counts_fetch, rep_counts_fetch, 1)

with open("public_web/static/js/app.js", "w", encoding="utf-8") as f:
    f.write(app_text)

print("Updated app.js to pass Admin authorization headers in catalog queries!")
