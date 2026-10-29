# scripts/patch_admin_vendors_module.py

with open("public_web/admin.html", "r", encoding="utf-8") as f:
    html = f.read()

# 1. Add sidebar item before sidebar-tab-firebase
old_nav_item = """            <button class="admin-nav-item" id="sidebar-tab-firebase" onclick="switchTab('firebase')">
                <span class="admin-nav-icon">🔥</span> Cloud Database Sync
            </button>"""

new_nav_item = """            <button class="admin-nav-item" id="sidebar-tab-vendors" onclick="switchTab('vendors')">
                <span class="admin-nav-icon">🏪</span> Vendors & Merchants
            </button>
            <button class="admin-nav-item" id="sidebar-tab-firebase" onclick="switchTab('firebase')">
                <span class="admin-nav-icon">🔥</span> Cloud Database Sync
            </button>"""

assert old_nav_item in html, "old_nav_item not found in admin.html"
html = html.replace(old_nav_item, new_nav_item, 1)

# 2. Add section #tab-vendors before toast-container
vendors_section_html = """
        <!-- TAB 11: VENDORS & MULTI-VENDOR MARKETPLACE MANAGEMENT -->
        <section id="tab-vendors" class="tab-content">
            <!-- Metric KPI Summary Row -->
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 1.25rem; margin-bottom: 2rem;">
                <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(184, 137, 43, 0.28); border-radius: 12px; padding: 1.25rem 1.5rem;">
                    <div style="font-size: 0.8rem; font-weight: 700; color: #94a3b8; text-transform: uppercase;">Total Registered Merchants</div>
                    <div id="adm-total-vendors" style="font-size: 1.85rem; font-weight: 800; color: #f8fafc; margin-top: 0.35rem;">0</div>
                </div>
                <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(245, 158, 11, 0.4); border-radius: 12px; padding: 1.25rem 1.5rem;">
                    <div style="font-size: 0.8rem; font-weight: 700; color: #fbbf24; text-transform: uppercase;">Pending Applications</div>
                    <div id="adm-pending-vendors" style="font-size: 1.85rem; font-weight: 800; color: #fbbf24; margin-top: 0.35rem;">0</div>
                </div>
                <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(16, 185, 129, 0.4); border-radius: 12px; padding: 1.25rem 1.5rem;">
                    <div style="font-size: 0.8rem; font-weight: 700; color: #34d399; text-transform: uppercase;">Approved & Active</div>
                    <div id="adm-approved-vendors" style="font-size: 1.85rem; font-weight: 800; color: #34d399; margin-top: 0.35rem;">0</div>
                </div>
                <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(239, 68, 68, 0.4); border-radius: 12px; padding: 1.25rem 1.5rem;">
                    <div style="font-size: 0.8rem; font-weight: 700; color: #f87171; text-transform: uppercase;">Pending Product Approvals</div>
                    <div id="adm-pending-prods-count" style="font-size: 1.85rem; font-weight: 800; color: #f87171; margin-top: 0.35rem;">0</div>
                </div>
            </div>

            <!-- PRODUCT APPROVAL QUEUE CARD -->
            <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(184, 137, 43, 0.28); border-radius: 14px; overflow: hidden; margin-bottom: 2rem;">
                <div class="card-header" style="background: #111c35 !important; border-bottom: 1px solid rgba(184, 137, 43, 0.28); padding: 1.25rem 1.75rem; display: flex; align-items: center; justify-content: space-between;">
                    <div>
                        <h3 style="margin: 0; color: #f8fafc; font-size: 1.2rem;">⚖️ Vendor Product Listings Approval Queue</h3>
                        <p style="margin: 4px 0 0 0; color: #94a3b8; font-size: 0.85rem;">Every vendor product requires Owner verification before appearing on the customer storefront.</p>
                    </div>
                    <button type="button" class="btn btn-secondary" onclick="loadAdminPendingProducts()" style="font-size: 0.825rem;">
                        🔄 Refresh Queue
                    </button>
                </div>
                <div class="table-responsive">
                    <table class="table" style="width: 100%; border-collapse: collapse;">
                        <thead>
                            <tr style="background: #0d1527; color: #cbd5e1; font-size: 0.775rem; text-transform: uppercase;">
                                <th style="padding: 0.85rem 1.25rem;">Item Details</th>
                                <th style="padding: 0.85rem 1.25rem;">Vendor / Shop</th>
                                <th style="padding: 0.85rem 1.25rem;">SKU</th>
                                <th style="padding: 0.85rem 1.25rem;">Selling Price</th>
                                <th style="padding: 0.85rem 1.25rem;">Stock</th>
                                <th style="padding: 0.85rem 1.25rem;">Review Actions</th>
                            </tr>
                        </thead>
                        <tbody id="admin-pending-products-body">
                            <tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading pending product submissions...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- VENDORS ROSTER & APPLICATION MANAGEMENT -->
            <div class="card" style="background: #0d1527 !important; border: 1px solid rgba(184, 137, 43, 0.28); border-radius: 14px; overflow: hidden;">
                <div class="card-header" style="background: #111c35 !important; border-bottom: 1px solid rgba(184, 137, 43, 0.28); padding: 1.25rem 1.75rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 1rem;">
                    <div>
                        <h3 style="margin: 0; color: #f8fafc; font-size: 1.2rem;">🏪 Merchant Partners & Application Dossiers</h3>
                        <p style="margin: 4px 0 0 0; color: #94a3b8; font-size: 0.85rem;">Approve, reject, or manage commission agreements for all marketplace sellers.</p>
                    </div>
                    <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                        <button type="button" class="btn btn-sm btn-secondary" onclick="loadAdminVendors('all')">All Vendors</button>
                        <button type="button" class="btn btn-sm btn-secondary" onclick="loadAdminVendors('submitted')">⏳ Pending Review</button>
                        <button type="button" class="btn btn-sm btn-secondary" onclick="loadAdminVendors('approved')">🟢 Approved</button>
                        <button type="button" class="btn btn-sm btn-secondary" onclick="loadAdminVendors('suspended')">🔒 Suspended</button>
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="table" style="width: 100%; border-collapse: collapse;">
                        <thead>
                            <tr style="background: #0d1527; color: #cbd5e1; font-size: 0.775rem; text-transform: uppercase;">
                                <th style="padding: 0.85rem 1.25rem;">Shop & Contact Info</th>
                                <th style="padding: 0.85rem 1.25rem;">Categories</th>
                                <th style="padding: 0.85rem 1.25rem;">Tax / GSTIN</th>
                                <th style="padding: 0.85rem 1.25rem;">Commission Rate</th>
                                <th style="padding: 0.85rem 1.25rem;">Status</th>
                                <th style="padding: 0.85rem 1.25rem;">Decisions & Controls</th>
                            </tr>
                        </thead>
                        <tbody id="admin-vendors-roster-body">
                            <tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading vendors...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
"""

target_toast = '    <!-- GLOBAL TOAST NOTIFICATIONS -->'
assert target_toast in html, "target_toast not found in admin.html"
html = html.replace(target_toast, vendors_section_html + "\n" + target_toast, 1)

# 3. Add Modal #modal-vendor-dossier
vendor_dossier_modal_html = """
    <!-- MODAL: OWNER VENDOR DOSSIER & REVIEW -->
    <div class="modal-overlay" id="modal-vendor-dossier">
        <div class="modal-container" style="max-width: 720px; background: #0d1527; border: 1px solid rgba(184, 137, 43, 0.4); border-radius: 16px;">
            <div class="modal-header" style="background: #111c35; border-bottom: 1px solid rgba(184, 137, 43, 0.3);">
                <h3 id="dossier-modal-title" style="color: #f8fafc; font-size: 1.25rem;">Merchant Application Dossier</h3>
                <button type="button" class="modal-close" onclick="closeVendorDossierModal()">×</button>
            </div>
            <div class="modal-body" style="padding: 1.75rem; color: #e2e8f0;">
                <input type="hidden" id="dossier-vendor-id">

                <div style="background: rgba(15, 23, 42, 0.7); border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; padding: 1.25rem; margin-bottom: 1.5rem;">
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 0.75rem;">
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Shop Name:</span>
                            <div id="dossier-biz-name" style="font-size: 1.05rem; font-weight: 700; color: #fbbf24;"></div>
                        </div>
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Contact Person:</span>
                            <div id="dossier-contact-name" style="font-size: 1.05rem; font-weight: 700; color: #f8fafc;"></div>
                        </div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 0.75rem;">
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Email:</span>
                            <div id="dossier-email" style="font-size: 0.95rem; color: #cbd5e1;"></div>
                        </div>
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Phone:</span>
                            <div id="dossier-phone" style="font-size: 0.95rem; color: #cbd5e1;"></div>
                        </div>
                    </div>
                    <div style="margin-bottom: 0.75rem;">
                        <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Operating Address & PIN:</span>
                        <div id="dossier-address" style="font-size: 0.95rem; color: #cbd5e1;"></div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Tax ID / GSTIN:</span>
                            <div id="dossier-tax-id" style="font-size: 0.95rem; color: #cbd5e1; font-family: monospace;"></div>
                        </div>
                        <div>
                            <span style="font-size: 0.775rem; color: #94a3b8; text-transform: uppercase;">Bank & IFSC:</span>
                            <div id="dossier-bank-info" style="font-size: 0.95rem; color: #cbd5e1;"></div>
                        </div>
                    </div>
                </div>

                <!-- OWNER COMMISSION & DIRECT PUBLISH CONFIGURATION -->
                <div style="background: rgba(184, 137, 43, 0.08); border: 1px solid rgba(184, 137, 43, 0.25); border-radius: 10px; padding: 1.25rem; margin-bottom: 1.5rem;">
                    <h4 style="margin: 0 0 1rem 0; color: #fbbf24; font-size: 1rem;">⚙️ Commercial Terms & Agreement</h4>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem;">
                        <div>
                            <label style="display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 0.4rem;">Marketplace Commission Rate (%)</label>
                            <input type="number" id="dossier-commission-input" step="0.5" min="0" max="50" style="width: 100%; box-sizing: border-box; background: #090f1d; border: 1px solid #1e293b; color: #f8fafc; padding: 0.7rem; border-radius: 6px; font-weight: 700;">
                        </div>
                        <div style="display: flex; align-items: center; gap: 10px; padding-top: 1.5rem;">
                            <input type="checkbox" id="dossier-auto-publish-check" style="width: 18px; height: 18px; accent-color: #b8892b;">
                            <label for="dossier-auto-publish-check" style="font-size: 0.85rem; color: #f8fafc; cursor: pointer;">
                                Grant Direct Auto-Publish (Trusted Merchant)
                            </label>
                        </div>
                    </div>
                </div>

                <!-- OWNER ACTION DECISION BUTTONS -->
                <div style="display: flex; gap: 0.75rem; justify-content: flex-end; flex-wrap: wrap;">
                    <button type="button" class="btn btn-secondary" onclick="closeVendorDossierModal()">Close</button>
                    <button type="button" class="btn btn-danger" onclick="executeVendorDecision('rejected')" style="background: rgba(239, 68, 68, 0.2); border-color: #ef4444; color: #fca5a5;">
                        ❌ Reject Application
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="executeVendorDecision('suspended')" style="background: rgba(245, 158, 11, 0.2); border-color: #f59e0b; color: #fcd34d;">
                        🔒 Suspend Account
                    </button>
                    <button type="button" class="btn btn-primary" onclick="executeVendorDecision('approved')" style="background: linear-gradient(135deg, #10b981, #059669); border: none; font-weight: 700;">
                        ✅ Approve Merchant Account
                    </button>
                </div>
            </div>
        </div>
    </div>
"""

target_end_modals = '    <!-- MODAL 1: EDIT PRODUCT DIALOG (Keep for backup safety) -->'
assert target_end_modals in html, "target_end_modals not found in admin.html"
html = html.replace(target_end_modals, vendor_dossier_modal_html + "\n" + target_end_modals, 1)

with open("public_web/admin.html", "w", encoding="utf-8") as f:
    f.write(html)

print("Successfully injected Vendors Management tab and Dossier Modal into admin.html!")
