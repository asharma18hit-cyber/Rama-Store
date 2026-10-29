// public_web/static/js/vendor.js - Samaur Mart Vendor Portal Controller
(function() {
    'use strict';

    let currentVendor = null;
    let vendorProducts = [];
    let vendorOrders = [];
    let inactivityTimer = null;
    let secondsRemaining = 20 * 60; // 20 minutes
    let searchDebounceTimeout = null;

    // -------------------------------------------------------------
    // 1. INITIALIZATION & SESSION VERIFICATION
    // -------------------------------------------------------------
    async function initVendorPortal() {
        const token = localStorage.getItem('vendor_token');
        if (!token) {
            window.location.href = '/vendor/login';
            return;
        }

        try {
            const res = await fetch('/api/vendor/verify-session', {
                headers: { 'Authorization': `Bearer ${token}` }
            });

            if (!res.ok) {
                localStorage.removeItem('vendor_token');
                localStorage.removeItem('vendor_user');
                window.location.href = '/vendor/login';
                return;
            }

            const data = await res.json();
            currentVendor = data.vendor;
            localStorage.setItem('vendor_user', JSON.stringify(currentVendor));

            // Set UI elements
            const nameEl = document.getElementById('sidebar-vendor-name');
            if (nameEl) nameEl.textContent = currentVendor.business_name;

            // Start Inactivity Timer
            startInactivityTimer();

            // Setup Activity Listeners
            ['mousedown', 'keydown', 'scroll', 'touchstart'].forEach(evt => {
                document.addEventListener(evt, resetInactivityTimer, { passive: true });
            });

            // Route initial tab based on URL hash
            const hash = window.location.hash.replace('#', '') || 'dashboard';
            switchVendorTab(hash);
        } catch (err) {
            console.error("Session verification failed:", err);
            window.location.href = '/vendor/login';
        }
    }

    // -------------------------------------------------------------
    // 2. INACTIVITY SESSION WATCHDOG (20 MINUTES)
    // -------------------------------------------------------------
    function startInactivityTimer() {
        if (inactivityTimer) clearInterval(inactivityTimer);
        secondsRemaining = 20 * 60;
        updateCountdownDisplay();

        inactivityTimer = setInterval(() => {
            secondsRemaining--;
            updateCountdownDisplay();

            if (secondsRemaining <= 0) {
                clearInterval(inactivityTimer);
                alert("Your vendor session has expired after 20 minutes of inactivity. Please log in again.");
                handleVendorLogout();
            }
        }, 1000);
    }

    function resetInactivityTimer() {
        secondsRemaining = 20 * 60;
        updateCountdownDisplay();
    }

    function updateCountdownDisplay() {
        const el = document.getElementById('session-countdown');
        if (!el) return;
        const mins = Math.floor(secondsRemaining / 60);
        const secs = secondsRemaining % 60;
        el.textContent = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        if (secondsRemaining < 120) {
            el.style.color = '#ef4444';
        } else {
            el.style.color = '#fbbf24';
        }
    }

    // -------------------------------------------------------------
    // 3. TAB NAVIGATION
    // -------------------------------------------------------------
    function switchVendorTab(tabId, evt) {
        if (evt) evt.preventDefault();
        window.location.hash = tabId;

        // Update Nav Links
        document.querySelectorAll('.sidebar-nav .nav-link').forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === `#${tabId}`) link.classList.add('active');
        });

        // Update Tab Panes
        document.querySelectorAll('.v-tab-pane').forEach(pane => {
            pane.classList.remove('active');
        });

        const targetPane = document.getElementById(`v-tab-${tabId}`);
        if (targetPane) targetPane.classList.add('active');

        // Update Topbar Title
        const headings = {
            dashboard: { title: "Merchant Dashboard", sub: "Overview of your catalog performance and fulfillment pipeline" },
            products: { title: "My Products & Catalog", sub: "Manage your authorized merchandise, pricing, and stock" },
            orders: { title: "Order Fulfillment Desk", sub: "Process and dispatch customer orders containing your items" },
            settlements: { title: "Settlements & Ledger", sub: "Bi-weekly financial reconciliation and marketplace commissions" },
            profile: { title: "Merchant Profile & Settings", sub: "Manage your business contact, operating address, and payout details" }
        };

        const h = headings[tabId] || headings.dashboard;
        const headEl = document.getElementById('topbar-heading');
        const subEl = document.getElementById('topbar-sub');
        if (headEl) headEl.textContent = h.title;
        if (subEl) subEl.textContent = h.sub;

        // Load Tab Data
        if (tabId === 'dashboard') loadVendorDashboard();
        else if (tabId === 'products') loadVendorProducts();
        else if (tabId === 'orders') loadVendorOrders();
        else if (tabId === 'settlements') loadVendorSettlements();
        else if (tabId === 'profile') loadVendorProfile();
    }
    window.switchVendorTab = switchVendorTab;

    // -------------------------------------------------------------
    // 4. TAB 1: DASHBOARD
    // -------------------------------------------------------------
    async function loadVendorDashboard() {
        const token = localStorage.getItem('vendor_token');
        try {
            const res = await fetch('/api/vendor/dashboard', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error);

            const m = data.metrics || {};
            document.getElementById('kpi-live-prods').textContent = m.live_products || 0;
            document.getElementById('kpi-pending-prods').textContent = m.pending_approval || 0;
            document.getElementById('kpi-orders-count').textContent = m.pending_fulfillment || 0;
            document.getElementById('kpi-net-earnings').textContent = `₹${(m.net_payable || 0).toLocaleString('en-IN')}`;

            // Load brief orders into dashboard
            const ordersRes = await fetch('/api/vendor/orders', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const ordersData = await ordersRes.json();
            const tbody = document.getElementById('dashboard-recent-orders-body');
            if (tbody) {
                const orders = (ordersData.orders || []).slice(0, 5);
                if (orders.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2rem;">No pending orders in your fulfillment queue.</td></tr>`;
                } else {
                    tbody.innerHTML = orders.map(o => {
                        const firstItem = (o.items && o.items[0]) ? o.items[0] : {};
                        const loc = (o.shipping_address && o.shipping_address.city) ? `${o.shipping_address.city} (${o.shipping_address.pincode || ''})` : 'Registered Address';
                        return `
                            <tr>
                                <td style="font-family: 'IBM Plex Mono', monospace; font-weight: 700; color: #fbbf24;">${o.tracking_number || o.order_id}</td>
                                <td><strong>${firstItem.name || 'Order Item'}</strong> ${o.items.length > 1 ? `<span style="color: #94a3b8; font-size: 0.8rem;">(+${o.items.length - 1} more)</span>` : ''}</td>
                                <td>${firstItem.quantity || 1} units</td>
                                <td><span class="badge-v-status pending">${firstItem.fulfillment_status || 'new'}</span></td>
                                <td>${loc}</td>
                                <td><button onclick="switchVendorTab('orders')" class="btn-sm-action">Fulfill →</button></td>
                            </tr>
                        `;
                    }).join('');
                }
            }
        } catch (err) {
            console.error("loadVendorDashboard error:", err);
        }
    }

    // -------------------------------------------------------------
    // 5. TAB 2: MY PRODUCTS
    // -------------------------------------------------------------
    async function loadVendorProducts() {
        const token = localStorage.getItem('vendor_token');
        const searchInput = document.getElementById('vendor-product-search');
        const statusFilter = document.getElementById('vendor-status-filter');
        const q = searchInput ? searchInput.value.trim() : '';
        const st = statusFilter ? statusFilter.value : '';

        const tbody = document.getElementById('vendor-products-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading products from cloud...</td></tr>`;
        }

        try {
            const url = `/api/vendor/products?search=${encodeURIComponent(q)}&status=${encodeURIComponent(st)}`;
            const res = await fetch(url, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error);

            vendorProducts = data.products || [];
            renderVendorProductsTable();
        } catch (err) {
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: #fca5a5; padding: 2rem;">Error loading catalog: ${err.message}</td></tr>`;
            }
        }
    }
    window.loadVendorProducts = loadVendorProducts;

    function debounceVendorProductSearch(val) {
        if (searchDebounceTimeout) clearTimeout(searchDebounceTimeout);
        searchDebounceTimeout = setTimeout(() => {
            loadVendorProducts();
        }, 300);
    }
    window.debounceVendorProductSearch = debounceVendorProductSearch;

    function renderVendorProductsTable() {
        const tbody = document.getElementById('vendor-products-body');
        if (!tbody) return;

        if (vendorProducts.length === 0) {
            tbody.innerHTML = `
                <tr><td colspan="7" style="text-align: center; padding: 3rem; color: #94a3b8;">
                    <div style="font-size: 2rem; margin-bottom: 0.5rem;">📦</div>
                    <div>No products found matching the filter.</div>
                    <button onclick="openVendorProductEditor()" class="btn-gold" style="margin-top: 1rem;">+ Register First Product</button>
                </td></tr>
            `;
            return;
        }

        tbody.innerHTML = vendorProducts.map(p => {
            const img = p.image_url || (p.images && p.images[0] && p.images[0].url) || 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=100';
            const price = parseFloat(p.selling_price || p.price || 0);
            const mrp = parseFloat(p.original_price || p.mrp || price);
            const stock = parseInt(p.stock || 0, 10);
            const approval = p.approval_status || 'approved';
            const status = p.status || 'draft';

            let approvalBadge = `<span class="badge-v-status live">🟢 Approved</span>`;
            if (approval === 'pending_review') {
                approvalBadge = `<span class="badge-v-status pending">⏳ Awaiting Owner Review</span>`;
            } else if (approval === 'rejected' || approval === 'changes_requested') {
                approvalBadge = `<span class="badge-v-status rejected" title="${p.review_notes || ''}">❌ Changes Requested</span>`;
            }

            let statusBadge = `<span class="badge-v-status live">🟢 Live</span>`;
            if (status !== 'published') {
                statusBadge = `<span class="badge-v-status draft">🔒 Draft</span>`;
            }

            return `
                <tr>
                    <td>
                        <div style="display: flex; align-items: center; gap: 12px;">
                            <img src="${img}" alt="${p.name}" style="width: 44px; height: 44px; object-fit: cover; border-radius: 8px; border: 1px solid rgba(255,255,255,0.1);">
                            <div>
                                <div style="font-weight: 700; color: #f8fafc; font-size: 0.95rem;">${p.name}</div>
                                <div style="font-size: 0.775rem; color: #94a3b8;">${p.brand || 'No Brand'} • ${p.unit || 'unit'}</div>
                            </div>
                        </div>
                    </td>
                    <td style="font-family: 'IBM Plex Mono', monospace; font-size: 0.85rem; color: #cbd5e1;">${p.sku || '-'}</td>
                    <td>
                        <div style="font-weight: 700; color: #fbbf24;">₹${price.toFixed(2)}</div>
                        ${mrp > price ? `<div style="font-size: 0.75rem; color: #94a3b8; text-decoration: line-through;">₹${mrp.toFixed(2)}</div>` : ''}
                    </td>
                    <td>
                        <button onclick="openVendorStockModal('${p.id}', '${p.name.replace(/'/g, "\\'")}', ${stock})" class="btn-sm-action" style="font-family: 'IBM Plex Mono', monospace; font-weight: 700; color: ${stock <= 5 ? '#fca5a5' : '#6ee7b7'};">
                            📦 ${stock} units (Edit)
                        </button>
                    </td>
                    <td>${approvalBadge}</td>
                    <td>${statusBadge}</td>
                    <td>
                        <div style="display: flex; gap: 6px;">
                            <button onclick="openVendorProductEditor('${p.id}')" class="btn-sm-action">Edit</button>
                            <button onclick="deleteVendorProduct('${p.id}', '${p.name.replace(/'/g, "\\'")}')" class="btn-sm-action delete">Delete</button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    // -------------------------------------------------------------
    // 6. VENDOR PRODUCT EDITOR MODAL
    // -------------------------------------------------------------
    function openVendorProductEditor(prodId) {
        const modal = document.getElementById('v-product-modal');
        const form = document.getElementById('v-product-form');
        const titleEl = document.getElementById('v-modal-title');
        form.reset();

        if (prodId) {
            titleEl.textContent = "Edit Product Listing";
            const p = vendorProducts.find(item => String(item.id) === String(prodId));
            if (p) {
                document.getElementById('v-prod-id').value = p.id;
                document.getElementById('v-prod-name').value = p.name || '';
                document.getElementById('v-prod-sku').value = p.sku || '';
                document.getElementById('v-prod-category').value = p.category_id || '1';
                document.getElementById('v-prod-brand').value = p.brand || '';
                document.getElementById('v-prod-unit').value = p.unit || '';
                document.getElementById('v-prod-mrp').value = p.original_price || p.mrp || '';
                document.getElementById('v-prod-price').value = p.selling_price || p.price || '';
                document.getElementById('v-prod-stock').value = p.stock || '0';
                document.getElementById('v-prod-image').value = p.image_url || '';
                document.getElementById('v-prod-short-desc').value = p.short_description || '';
                document.getElementById('v-prod-desc').value = p.description || '';
            }
        } else {
            titleEl.textContent = "Register New Product Listing";
            document.getElementById('v-prod-id').value = '';
        }

        modal.classList.add('active');
    }
    window.openVendorProductEditor = openVendorProductEditor;

    function closeVendorProductEditor() {
        document.getElementById('v-product-modal').classList.remove('active');
    }
    window.closeVendorProductEditor = closeVendorProductEditor;

    async function handleVendorProductSubmit(e) {
        e.preventDefault();
        const token = localStorage.getItem('vendor_token');
        const prodId = document.getElementById('v-prod-id').value;
        const submitBtn = document.getElementById('btn-save-v-prod');

        submitBtn.disabled = true;
        submitBtn.textContent = "Submitting to cloud...";

        const payload = {
            name: document.getElementById('v-prod-name').value.trim(),
            sku: document.getElementById('v-prod-sku').value.trim(),
            category_id: document.getElementById('v-prod-category').value,
            brand: document.getElementById('v-prod-brand').value.trim(),
            unit: document.getElementById('v-prod-unit').value.trim(),
            mrp: parseFloat(document.getElementById('v-prod-mrp').value) || 0,
            original_price: parseFloat(document.getElementById('v-prod-mrp').value) || 0,
            selling_price: parseFloat(document.getElementById('v-prod-price').value) || 0,
            stock: parseInt(document.getElementById('v-prod-stock').value, 10) || 0,
            image_url: document.getElementById('v-prod-image').value.trim(),
            images: [document.getElementById('v-prod-image').value.trim()],
            short_description: document.getElementById('v-prod-short-desc').value.trim(),
            description: document.getElementById('v-prod-desc').value.trim()
        };

        try {
            const url = prodId ? `/api/vendor/products/${prodId}` : '/api/vendor/products';
            const method = prodId ? 'PUT' : 'POST';

            const res = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify(payload)
            });

            const data = await res.json();
            submitBtn.disabled = false;
            submitBtn.textContent = "Submit Listing for Review";

            if (res.ok && data.success) {
                alert(data.message || "Product saved successfully!");
                closeVendorProductEditor();
                loadVendorProducts();
            } else {
                alert(data.error || "Failed to save product.");
            }
        } catch (err) {
            submitBtn.disabled = false;
            submitBtn.textContent = "Submit Listing for Review";
            alert("Error: " + err.message);
        }
    }
    window.handleVendorProductSubmit = handleVendorProductSubmit;

    // -------------------------------------------------------------
    // 7. STOCK MODAL & QUICK ADJUSTMENT
    // -------------------------------------------------------------
    function openVendorStockModal(prodId, name, currStock) {
        document.getElementById('v-stock-prod-id').value = prodId;
        document.getElementById('v-stock-prod-name').textContent = name;
        document.getElementById('v-stock-input').value = currStock;
        document.getElementById('v-stock-reason').value = '';
        document.getElementById('v-stock-modal').classList.add('active');
    }
    window.openVendorStockModal = openVendorStockModal;

    function closeVendorStockModal() {
        document.getElementById('v-stock-modal').classList.remove('active');
    }
    window.closeVendorStockModal = closeVendorStockModal;

    async function submitVendorStockUpdate() {
        const token = localStorage.getItem('vendor_token');
        const prodId = document.getElementById('v-stock-prod-id').value;
        const newStock = parseInt(document.getElementById('v-stock-input').value, 10);
        const reason = document.getElementById('v-stock-reason').value.trim() || 'Manual stock update';

        if (isNaN(newStock) || newStock < 0) {
            alert("Please enter a valid stock number.");
            return;
        }

        try {
            const res = await fetch(`/api/vendor/products/${prodId}/stock`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ stock: newStock, reason })
            });

            const data = await res.json();
            if (res.ok && data.success) {
                closeVendorStockModal();
                loadVendorProducts();
            } else {
                alert(data.error || "Failed to update stock.");
            }
        } catch (err) {
            alert("Stock update failed: " + err.message);
        }
    }
    window.submitVendorStockUpdate = submitVendorStockUpdate;

    // -------------------------------------------------------------
    // 8. DELETE PRODUCT
    // -------------------------------------------------------------
    async function deleteVendorProduct(prodId, name) {
        if (!confirm(`Are you sure you want to remove "${name}" from your catalog?\n\nIf this product was ordered in the past, it will be moved to Archives to protect customer records.`)) {
            return;
        }

        const token = localStorage.getItem('vendor_token');
        try {
            const res = await fetch(`/api/vendor/products/${prodId}`, {
                method: 'DELETE',
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (res.ok && data.success) {
                alert(data.message || "Product removed.");
                loadVendorProducts();
            } else {
                alert(data.error || "Failed to delete product.");
            }
        } catch (err) {
            alert("Delete failed: " + err.message);
        }
    }
    window.deleteVendorProduct = deleteVendorProduct;

    // -------------------------------------------------------------
    // 9. TAB 3: ORDER FULFILLMENT
    // -------------------------------------------------------------
    async function loadVendorOrders() {
        const token = localStorage.getItem('vendor_token');
        const tbody = document.getElementById('vendor-orders-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading orders...</td></tr>`;
        }

        try {
            const res = await fetch('/api/vendor/orders', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error);

            vendorOrders = data.orders || [];
            renderVendorOrdersTable();
        } catch (err) {
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #fca5a5; padding: 2rem;">Error: ${err.message}</td></tr>`;
            }
        }
    }
    window.loadVendorOrders = loadVendorOrders;

    function renderVendorOrdersTable() {
        const tbody = document.getElementById('vendor-orders-body');
        if (!tbody) return;

        if (vendorOrders.length === 0) {
            tbody.innerHTML = `
                <tr><td colspan="6" style="text-align: center; padding: 3rem; color: #94a3b8;">
                    <div style="font-size: 2rem; margin-bottom: 0.5rem;">📋</div>
                    <div>No customer orders assigned to your merchant account yet.</div>
                </td></tr>
            `;
            return;
        }

        tbody.innerHTML = vendorOrders.map(o => {
            const dateStr = o.created_at ? new Date(o.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '-';
            const addr = o.shipping_address || {};
            const addrStr = typeof addr === 'string' ? addr : `${addr.city || ''} - ${addr.pincode || ''}`;

            const itemsHtml = (o.items || []).map(it => {
                const curSt = it.fulfillment_status || 'new';
                return `
                    <div style="display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 0.5rem 0; border-bottom: 1px solid rgba(255,255,255,0.05);">
                        <div>
                            <strong>${it.name}</strong> (Qty: ${it.quantity})
                            <div style="font-size: 0.775rem; color: #94a3b8;">SKU: ${it.sku || '-'}</div>
                        </div>
                        <div style="text-align: right;">
                            <span class="badge-v-status ${curSt === 'delivered' ? 'live' : 'pending'}">${curSt}</span>
                        </div>
                    </div>
                `;
            }).join('');

            const firstItem = (o.items && o.items[0]) ? o.items[0] : {};
            const curStatus = firstItem.fulfillment_status || 'new';

            return `
                <tr>
                    <td>
                        <div style="font-family: 'IBM Plex Mono', monospace; font-weight: 700; color: #fbbf24;">${o.tracking_number || o.order_id}</div>
                        <div style="font-size: 0.775rem; color: #94a3b8;">${dateStr}</div>
                    </td>
                    <td>
                        <div style="font-weight: 600; color: #f8fafc;">${o.customer_name || 'Customer'}</div>
                        <div style="font-size: 0.8rem; color: #cbd5e1; max-width: 250px;">${addrStr}</div>
                    </td>
                    <td>
                        <div style="max-width: 320px;">${itemsHtml}</div>
                    </td>
                    <td style="font-weight: 700; color: #34d399;">₹${(o.vendor_subtotal || 0).toFixed(2)}</td>
                    <td>
                        <span class="badge-v-status ${curStatus === 'delivered' ? 'live' : 'pending'}">${curStatus}</span>
                    </td>
                    <td>
                        <select onchange="updateVendorItemStatus('${o.order_id}', '${firstItem.id}', this.value)" style="background: #090f1d; border: 1px solid #1e293b; color: #f8fafc; padding: 0.45rem 0.65rem; border-radius: 6px; font-size: 0.8rem;">
                            <option value="">Update Status...</option>
                            <option value="accepted">Accepted</option>
                            <option value="processing">Processing</option>
                            <option value="packed">Packed</option>
                            <option value="ready_for_dispatch">Ready for Dispatch</option>
                            <option value="shipped">Shipped</option>
                            <option value="delivered">Delivered</option>
                        </select>
                    </td>
                </tr>
            `;
        }).join('');
    }

    async function updateVendorItemStatus(orderId, prodId, newStatus) {
        if (!newStatus) return;
        const token = localStorage.getItem('vendor_token');

        try {
            const res = await fetch(`/api/vendor/orders/${orderId}/item-status`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ product_id: prodId, status: newStatus })
            });

            const data = await res.json();
            if (res.ok && data.success) {
                alert(`Status updated to "${newStatus}"!`);
                loadVendorOrders();
            } else {
                alert(data.error || "Failed to update fulfillment status.");
            }
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
    window.updateVendorItemStatus = updateVendorItemStatus;

    // -------------------------------------------------------------
    // 10. TAB 4: SETTLEMENTS & LEDGER
    // -------------------------------------------------------------
    async function loadVendorSettlements() {
        const token = localStorage.getItem('vendor_token');
        try {
            const res = await fetch('/api/vendor/settlements', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error);

            document.getElementById('st-gross-sales').textContent = `₹${(data.gross_sales || 0).toLocaleString('en-IN')}`;
            document.getElementById('st-commission-rate').textContent = `${data.commission_rate || 10.0}%`;
            document.getElementById('st-commission-deducted').textContent = `₹${(data.marketplace_commission || 0).toLocaleString('en-IN')}`;
            document.getElementById('st-net-payable').textContent = `₹${(data.net_payable || 0).toLocaleString('en-IN')}`;

            const tbody = document.getElementById('vendor-ledger-body');
            if (tbody) {
                const ledger = data.ledger || [];
                if (ledger.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: #94a3b8; padding: 2rem;">No settlement entries recorded yet.</td></tr>`;
                } else {
                    tbody.innerHTML = ledger.map(l => `
                        <tr>
                            <td style="font-family: 'IBM Plex Mono', monospace; color: #fbbf24;">${l.order_id}</td>
                            <td>${l.date ? new Date(l.date).toLocaleDateString() : '-'}</td>
                            <td>${l.product_name}</td>
                            <td>${l.quantity}</td>
                            <td>₹${l.gross_amount.toFixed(2)}</td>
                            <td style="color: #fca5a5;">-₹${l.commission_deducted.toFixed(2)} (${l.commission_rate}%)</td>
                            <td style="font-weight: 700; color: #34d399;">₹${l.net_payable.toFixed(2)}</td>
                            <td><span class="badge-v-status ${l.status === 'eligible_for_payout' ? 'live' : 'pending'}">${l.status}</span></td>
                        </tr>
                    `).join('');
                }
            }
        } catch (err) {
            console.error("loadVendorSettlements error:", err);
        }
    }

    // -------------------------------------------------------------
    // 11. TAB 5: PROFILE & LOGOUT
    // -------------------------------------------------------------
    async function loadVendorProfile() {
        const token = localStorage.getItem('vendor_token');
        try {
            const res = await fetch('/api/vendor/profile', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const data = await res.json();
            if (res.ok && data.vendor) {
                const v = data.vendor;
                document.getElementById('prof-biz-name').value = v.business_name || '';
                document.getElementById('prof-contact-name').value = v.contact_name || '';
                document.getElementById('prof-address').value = v.address || '';
                document.getElementById('prof-pincode').value = v.pincode || '';
                document.getElementById('prof-email').value = v.email || '';
            }
        } catch (err) {
            console.error("loadVendorProfile error:", err);
        }
    }

    async function handleVendorProfileSave(e) {
        e.preventDefault();
        const token = localStorage.getItem('vendor_token');
        const payload = {
            contact_name: document.getElementById('prof-contact-name').value.trim(),
            address: document.getElementById('prof-address').value.trim(),
            pincode: document.getElementById('prof-pincode').value.trim()
        };

        try {
            const res = await fetch('/api/vendor/profile', {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (res.ok && data.success) {
                alert("Profile changes saved successfully!");
            } else {
                alert(data.error || "Failed to update profile.");
            }
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
    window.handleVendorProfileSave = handleVendorProfileSave;

    async function handleVendorLogout() {
        const token = localStorage.getItem('vendor_token');
        if (token) {
            try {
                await fetch('/api/vendor/logout', {
                    method: 'POST',
                    headers: { 'Authorization': `Bearer ${token}` }
                });
            } catch (_) {}
        }
        localStorage.removeItem('vendor_token');
        localStorage.removeItem('vendor_user');
        window.location.href = '/vendor/login';
    }
    window.handleVendorLogout = handleVendorLogout;

    // Boot
    document.addEventListener('DOMContentLoaded', initVendorPortal);
})();
