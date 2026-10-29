# scripts/patch_admin_js_vendors.py

with open("public_web/static/js/app.js", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add vendors to switchTab titles
old_titles = """        delivery: { h: "Delivery & Serviceable PIN Codes", sub: "Control deliverable area PIN codes and shipping fee rules", metrics: false },
        firebase: { h: "Firebase Cloud Console", sub: "Monitor Cloud Firestore NoSQL synchronization and Identity Platform", metrics: false }"""

new_titles = """        delivery: { h: "Delivery & Serviceable PIN Codes", sub: "Control deliverable area PIN codes and shipping fee rules", metrics: false },
        vendors: { h: "Vendors & Marketplace Management", sub: "Review vendor applications, approve product listings, and configure commissions", metrics: false },
        firebase: { h: "Firebase Cloud Console", sub: "Monitor Cloud Firestore NoSQL synchronization and Identity Platform", metrics: false }"""

assert old_titles in text, "old_titles not found in app.js"
text = text.replace(old_titles, new_titles, 1)

# 2. Add vendors loader to switchTab
old_loader = """        } else if (tabName === 'firebase') {
            if (typeof loadFirebaseStatus === 'function') loadFirebaseStatus();
        }"""

new_loader = """        } else if (tabName === 'vendors') {
            loadAdminVendors();
            loadAdminPendingProducts();
        } else if (tabName === 'firebase') {
            if (typeof loadFirebaseStatus === 'function') loadFirebaseStatus();
        }"""

assert old_loader in text, "old_loader not found in app.js"
text = text.replace(old_loader, new_loader, 1)

# 3. Append the vendor management controller functions
vendor_admin_functions = """
// =========================================================================
// MULTI-VENDOR MARKETPLACE CONTROLLER (OWNER ADMIN CONSOLE)
// =========================================================================

let adminVendorsList = [];
let adminPendingProductsList = [];

async function loadAdminVendors(statusFilter = 'all') {
    const tbody = document.getElementById('admin-vendors-roster-body');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading merchant roster...</td></tr>';
    }

    try {
        const url = statusFilter && statusFilter !== 'all' ? `/api/admin/vendors?status=${encodeURIComponent(statusFilter)}` : '/api/admin/vendors';
        const res = await fetch(url, { credentials: 'omit' });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error);

        adminVendorsList = data.vendors || [];
        const counts = data.counts || {};

        const totalEl = document.getElementById('adm-total-vendors');
        const pendingEl = document.getElementById('adm-pending-vendors');
        const approvedEl = document.getElementById('adm-approved-vendors');
        if (totalEl) totalEl.textContent = counts.all || adminVendorsList.length;
        if (pendingEl) pendingEl.textContent = counts.submitted || 0;
        if (approvedEl) approvedEl.textContent = counts.approved || 0;

        renderAdminVendorsTable();
    } catch (err) {
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #fca5a5; padding: 2rem;">Error loading vendors: ${err.message}</td></tr>`;
        }
    }
}
window.loadAdminVendors = loadAdminVendors;

function renderAdminVendorsTable() {
    const tbody = document.getElementById('admin-vendors-roster-body');
    if (!tbody) return;

    if (adminVendorsList.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">No merchant accounts found in this category.</td></tr>';
        return;
    }

    tbody.innerHTML = adminVendorsList.map(v => {
        let badge = '<span class="badge" style="background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid rgba(16,185,129,0.3); padding: 4px 10px; border-radius: 999px;">🟢 Approved</span>';
        if (v.status === 'submitted' || v.status === 'under_review') {
            badge = '<span class="badge" style="background: rgba(245, 158, 11, 0.2); color: #fbbf24; border: 1px solid rgba(245,158,11,0.3); padding: 4px 10px; border-radius: 999px;">⏳ Pending Decision</span>';
        } else if (v.status === 'suspended') {
            badge = '<span class="badge" style="background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid rgba(239,68,68,0.3); padding: 4px 10px; border-radius: 999px;">🔒 Suspended</span>';
        } else if (v.status === 'rejected') {
            badge = '<span class="badge" style="background: rgba(148, 163, 184, 0.2); color: #cbd5e1; border: 1px solid rgba(148,163,184,0.3); padding: 4px 10px; border-radius: 999px;">❌ Rejected</span>';
        }

        const cats = Array.isArray(v.categories) ? v.categories.join(', ') : (v.categories || 'General');

        return `
            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
                <td style="padding: 1rem 1.25rem;">
                    <div style="font-weight: 700; color: #fbbf24; font-size: 1rem;">${v.business_name}</div>
                    <div style="font-size: 0.825rem; color: #cbd5e1;">${v.contact_name} • ${v.phone}</div>
                    <div style="font-size: 0.775rem; color: #94a3b8;">${v.email}</div>
                </td>
                <td style="padding: 1rem 1.25rem; color: #cbd5e1; font-size: 0.85rem;">${cats}</td>
                <td style="padding: 1rem 1.25rem; font-family: monospace; color: #94a3b8; font-size: 0.85rem;">${v.tax_id || 'N/A'}</td>
                <td style="padding: 1rem 1.25rem; font-weight: 700; color: #f8fafc;">${v.commission_rate || 10.0}%</td>
                <td style="padding: 1rem 1.25rem;">${badge}</td>
                <td style="padding: 1rem 1.25rem;">
                    <button type="button" class="btn btn-sm btn-primary" onclick="openVendorDossierModal('${v.id}')" style="background: linear-gradient(135deg, #b8892b, #936b1d); border: none; font-weight: 600; padding: 0.4rem 0.85rem; border-radius: 6px;">
                        🔍 Review Dossier
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

async function loadAdminPendingProducts() {
    const tbody = document.getElementById('admin-pending-products-body');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2rem;">Loading pending review submissions...</td></tr>';
    }

    try {
        const res = await fetch('/api/admin/products/pending-review');
        const data = await res.json();
        if (!res.ok) throw new Error(data.error);

        adminPendingProductsList = data.products || [];
        const countEl = document.getElementById('adm-pending-prods-count');
        if (countEl) countEl.textContent = adminPendingProductsList.length;

        renderAdminPendingProductsTable();
    } catch (err) {
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #fca5a5; padding: 1.5rem;">Error loading queue: ${err.message}</td></tr>`;
        }
    }
}
window.loadAdminPendingProducts = loadAdminPendingProducts;

function renderAdminPendingProductsTable() {
    const tbody = document.getElementById('admin-pending-products-body');
    if (!tbody) return;

    if (adminPendingProductsList.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #34d399; padding: 2.5rem;">✨ All vendor product listings have been reviewed! Zero pending submissions.</td></tr>';
        return;
    }

    tbody.innerHTML = adminPendingProductsList.map(p => {
        const img = p.image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=100';
        const price = parseFloat(p.selling_price || p.price || 0);

        return `
            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
                <td style="padding: 1rem 1.25rem;">
                    <div style="display: flex; align-items: center; gap: 12px;">
                        <img src="${img}" alt="${p.name}" style="width: 44px; height: 44px; object-fit: cover; border-radius: 8px; border: 1px solid rgba(255,255,255,0.1);">
                        <div>
                            <div style="font-weight: 700; color: #f8fafc;">${p.name}</div>
                            <div style="font-size: 0.775rem; color: #94a3b8;">${p.brand || 'No Brand'} • ${p.category || 'General'}</div>
                        </div>
                    </div>
                </td>
                <td style="padding: 1rem 1.25rem; font-weight: 600; color: #fbbf24;">${p.vendor_name || 'Marketplace Vendor'}</td>
                <td style="padding: 1rem 1.25rem; font-family: monospace; color: #cbd5e1;">${p.sku || '-'}</td>
                <td style="padding: 1rem 1.25rem; font-weight: 700; color: #34d399;">₹${price.toFixed(2)}</td>
                <td style="padding: 1rem 1.25rem; color: #cbd5e1;">${p.stock || 0} units</td>
                <td style="padding: 1rem 1.25rem;">
                    <div style="display: flex; gap: 8px;">
                        <button type="button" class="btn btn-sm btn-primary" onclick="reviewVendorListing('${p.id}', 'approve')" style="background: linear-gradient(135deg, #10b981, #059669); border: none; font-weight: 700; padding: 0.4rem 0.75rem;">
                            ✅ Approve (Live)
                        </button>
                        <button type="button" class="btn btn-sm btn-danger" onclick="reviewVendorListing('${p.id}', 'reject')" style="background: rgba(239, 68, 68, 0.2); border: 1px solid #ef4444; color: #fca5a5; font-weight: 600; padding: 0.4rem 0.75rem;">
                            ❌ Reject
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

async function reviewVendorListing(prodId, action) {
    let notes = '';
    if (action === 'reject') {
        notes = prompt("Please enter the rejection reason or requested changes for this vendor listing:", "Image quality or description incomplete");
        if (notes === null) return;
    }

    try {
        const res = await fetch(`/api/admin/products/${prodId}/review`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, review_notes: notes })
        });
        const data = await res.json();
        if (res.ok && data.success) {
            showToast(data.message || `Product ${action}d successfully!`);
            loadAdminPendingProducts();
            loadCatalog(); // Refresh active catalog
        } else {
            showToast(data.error || "Review action failed", "error");
        }
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}
window.reviewVendorListing = reviewVendorListing;

async function openVendorDossierModal(vendorId) {
    const modal = document.getElementById('modal-vendor-dossier');
    try {
        const res = await fetch(`/api/admin/vendors/${vendorId}`);
        const data = await res.json();
        if (!res.ok) throw new Error(data.error);

        const v = data.vendor || {};
        document.getElementById('dossier-vendor-id').value = v.id;
        document.getElementById('dossier-biz-name').textContent = v.business_name || 'N/A';
        document.getElementById('dossier-contact-name').textContent = v.contact_name || 'N/A';
        document.getElementById('dossier-email').textContent = v.email || 'N/A';
        document.getElementById('dossier-phone').textContent = v.phone || 'N/A';
        document.getElementById('dossier-address').textContent = `${v.address || 'N/A'} (PIN: ${v.pincode || 'N/A'})`;
        document.getElementById('dossier-tax-id').textContent = v.tax_id || 'Not Provided';

        const bank = v.bank_details || {};
        document.getElementById('dossier-bank-info').textContent = bank.bank_name ? `${bank.bank_name} • A/C: ${bank.account_number || 'N/A'} • IFSC: ${bank.ifsc_code || 'N/A'}` : 'Not Provided';
        document.getElementById('dossier-commission-input').value = v.commission_rate || 10.0;
        document.getElementById('dossier-auto-publish-check').checked = Boolean(v.auto_publish);

        modal.classList.add('active');
    } catch (err) {
        showToast("Error opening dossier: " + err.message, "error");
    }
}
window.openVendorDossierModal = openVendorDossierModal;

function closeVendorDossierModal() {
    const modal = document.getElementById('modal-vendor-dossier');
    if (modal) modal.classList.remove('active');
}
window.closeVendorDossierModal = closeVendorDossierModal;

async function executeVendorDecision(status) {
    const vendorId = document.getElementById('dossier-vendor-id').value;
    const commission = parseFloat(document.getElementById('dossier-commission-input').value) || 10.0;
    const autoPublish = document.getElementById('dossier-auto-publish-check').checked;
    let reason = null;

    if (status === 'rejected') {
        reason = prompt("Please specify rejection reason for vendor notification:", "Business documentation incomplete");
        if (reason === null) return;
    }

    try {
        const res = await fetch(`/api/admin/vendors/${vendorId}/status`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                status,
                rejection_reason: reason,
                commission_rate: commission,
                auto_publish: autoPublish
            })
        });
        const data = await res.json();
        if (res.ok && data.success) {
            showToast(data.message || `Vendor ${status} successfully!`);
            closeVendorDossierModal();
            loadAdminVendors();
        } else {
            showToast(data.error || "Decision execution failed", "error");
        }
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}
window.executeVendorDecision = executeVendorDecision;
"""

text += "\n" + vendor_admin_functions

with open("public_web/static/js/app.js", "w", encoding="utf-8") as f:
    f.write(text)

print("Successfully injected Multi-Vendor controller functions into app.js!")
