/* static/js/app.js */

// Native JavaScript Toast Notification Engine Class
class ToastManager {
    static show(message, type = 'success') {
        const container = document.getElementById('toast-container');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        
        const icon = type === 'success' ? '✅' : '❌';
        toast.innerHTML = `
            <span class="toast-icon">${icon}</span>
            <span class="toast-message">${message}</span>
        `;
        
        container.appendChild(toast);
        
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(120%) scale(0.9)';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
}

function showToast(message, type = 'success') {
    ToastManager.show(message, type);
}

// Global Application Reactive State Machine
const state = {
    user: null,
    activeView: 'Storefront', // Storefront | Cart | Admin
    products: [],            // Storefront catalog product listings
    cart: [],                // Storefront active customer selections
    posCart: [],             // Staff POS billing selections
    catalog: {
        currentPage: 1,
        perPage: 10,
        totalPages: 1,
        totalCount: 0,
        searchQuery: ''
    },
    pos: {
        suggestions: [],
        highlightedSuggestionIndex: -1
    },
    storefront: {
        categories: [],       // Flat list of category rows retrieved from server
        activeCategory: null,
        maxPrice: 2000,
        searchQuery: '',
        currentPage: 1,
        totalPages: 1,
        isLoading: false,
        hasMore: true,
        currentSession: null
    },
    rewards: {
        balance: 350,
        transactions: [
            { date: '10/07/2026', description: 'Counter signup bonus', points: 100 },
            { date: '10/07/2026', description: 'Counter loyalty transfer', points: 250 }
        ]
    }
};

// Helper for formatting INR currency values
function formatINR(number) {
    if (isNaN(number) || number === null) return "₹0.00";
    return "₹" + parseFloat(number).toLocaleString('en-IN', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

// Intercept unauthorized requests
async function handleResponse(response) {
    if (response.status === 401) {
        state.user = null;
        openLoginOverlay();
        throw new Error("Unauthorized");
    }
    return response;
}

// Boot application
document.addEventListener('DOMContentLoaded', async () => {
    loadCustomerCartFromStorage();
    await checkAuthStatus();
    
    const posSearchInput = document.getElementById('pos-search-input');
    if (posSearchInput) {
        posSearchInput.addEventListener('input', handlePOSSearchInput);
        posSearchInput.addEventListener('keydown', handlePOSSearchKeydown);
    }
    
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.search-container')) {
            closePOSSuggestions();
        }
    });

    document.addEventListener('keydown', (e) => {
        if (!state.user || state.user.role !== 'admin') return;
        
        if (e.key === 'F8') {
            e.preventDefault();
            completeCheckout();
        }
        if (e.key === 'Escape') {
            closeEditModal();
            closeReceiptModal();
            closePOSSuggestions();
            closePaymentModal();
        }
    });

    initInfiniteScrollObserver();
    initCardInputFormatters();
});

// ==========================================
// USER AUTHENTICATION & LOGIN FLOWS
// ==========================================

async function checkAuthStatus() {
    try {
        const response = await fetch('/api/auth/status');
        const data = await response.json();
        
        if (response.ok && data.authenticated) {
            loginSession(data.user);
        } else {
            state.user = null;
            routeUserLayout(null);
        }
    } catch (err) {
        state.user = null;
        routeUserLayout(null);
    }
}

function routeUserLayout(user) {
    const authContainer = document.getElementById('auth-container');
    const adminPortal = document.getElementById('admin-portal-view');
    const storefront = document.getElementById('customer-storefront-view');
    const headerSignInBtn = document.getElementById('btn-store-signin');
    const headerProfileWidget = document.getElementById('customer-profile-widget');
    const adminDashboardLink = document.getElementById('btn-admin-dashboard-link');

    if (!user) {
        if (authContainer) authContainer.classList.remove('hidden');
        if (adminPortal) adminPortal.style.display = 'none';
        if (storefront) storefront.style.display = 'flex';
        if (headerSignInBtn) headerSignInBtn.style.display = 'block';
        if (headerProfileWidget) headerProfileWidget.style.display = 'none';
        if (adminDashboardLink) adminDashboardLink.style.display = 'none';
        
        initStorefront();
    } else if (user.role === 'admin') {
        // Logged in as admin - show storefront with "Hi, Admin" link
        if (authContainer) authContainer.classList.add('hidden');
        if (adminPortal) adminPortal.style.display = 'none';
        if (storefront) storefront.style.display = 'flex';
        if (headerSignInBtn) headerSignInBtn.style.display = 'none';
        if (headerProfileWidget) headerProfileWidget.style.display = 'flex';
        if (adminDashboardLink) adminDashboardLink.style.display = 'block';
        
        const avatar = document.getElementById('customer-avatar');
        if (avatar) avatar.innerText = 'A';
        const dispName = document.getElementById('customer-display-name');
        if (dispName) dispName.innerText = user.fullname || 'Admin';
        
        initStorefront();
    } else {
        // Logged in as customer
        if (authContainer) authContainer.classList.add('hidden');
        if (adminPortal) adminPortal.style.display = 'none';
        if (storefront) storefront.style.display = 'flex';
        if (headerSignInBtn) headerSignInBtn.style.display = 'none';
        if (headerProfileWidget) headerProfileWidget.style.display = 'flex';
        if (adminDashboardLink) adminDashboardLink.style.display = 'none';
        
        const avatar = document.getElementById('customer-avatar');
        if (avatar) avatar.innerText = user.fullname ? user.fullname.charAt(0).toUpperCase() : 'C';
        const dispName = document.getElementById('customer-display-name');
        if (dispName) dispName.innerText = user.fullname || 'My Account';
        
        initStorefront();
        
        const profFullname = document.getElementById('profile-user-fullname');
        if (profFullname) profFullname.innerText = user.fullname || '-';
        const profIdentifier = document.getElementById('profile-user-identifier');
        if (profIdentifier) profIdentifier.innerText = user.email_or_phone || '-';
        const profRole = document.getElementById('profile-user-role');
        if (profRole) profRole.innerText = 'Customer';
    }
}

function routeToAdminDashboard() {
    window.location.href = '/admin';
}

function loginSession(user) {
    state.user = user;
    routeUserLayout(user);
}

async function handleLogout() {
    try {
        await fetch('/api/auth/logout', { method: 'POST' });
    } catch(e) {}
    
    state.user = null;
    state.posCart = [];
    renderPOSCart();
    calculatePOSCartTotals();
    
    showToast("Logged out successfully.");
    if (window.location.pathname.includes('/admin')) {
        window.location.href = '/admin';
    } else {
        window.location.href = '/';
    }
}

async function handleChangePassword(e) {
    e.preventDefault();
    const currentPassword = document.getElementById('change-pwd-current').value;
    const newPassword = document.getElementById('change-pwd-new').value;
    const confirmPassword = document.getElementById('change-pwd-confirm').value;
    
    if (newPassword !== confirmPassword) {
        showToast("New passwords do not match.", "error");
        return;
    }
    
    const submitBtn = e.target.querySelector('button[type="submit"]');
    const origText = submitBtn.innerText;
    submitBtn.disabled = true;
    submitBtn.innerText = 'Updating...';
    
    try {
        const response = await fetch('/api/auth/change-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                current_password: currentPassword,
                new_password: newPassword,
                confirm_password: confirmPassword
            })
        });
        const data = await response.json();
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        
        if (response.ok) {
            showToast("Password updated successfully!", "success");
            e.target.reset();
        } else {
            showToast(data.error || "Failed to change password.", "error");
        }
    } catch(err) {
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        showToast("Connection failed: " + err.message, "error");
    }
}

function openLoginOverlay() {
    window.location.href = '/login';
}

function slideAuthPanel(mode) {
    const authContainer = document.getElementById('auth-container');
    authContainer.classList.remove('signup-mode', 'otp-mode', 'login-mode', 'forgot-mode', 'reset-mode');
    
    if (mode === 'register') {
        authContainer.classList.add('signup-mode');
    } else if (mode === 'otp') {
        authContainer.classList.add('otp-mode');
    } else if (mode === 'forgot') {
        authContainer.classList.add('forgot-mode');
    } else if (mode === 'reset') {
        authContainer.classList.add('reset-mode');
    } else {
        authContainer.classList.add('login-mode');
    }
}

function toggleAuthMode(signupMode) {
    slideAuthPanel(signupMode ? 'register' : 'login');
}

const EMAIL_REGEX = /^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$/;
const PHONE_REGEX = /^\d{10}$/;

function isValidEmailOrPhone(val) {
    return EMAIL_REGEX.test(val) || PHONE_REGEX.test(val) || val.length >= 3; // username check
}

async function handleLoginSubmit(e) {
    e.preventDefault();
    const email_or_phone = document.getElementById('login-email-phone').value.trim();
    const password = document.getElementById('login-password').value;
    
    if (!isValidEmailOrPhone(email_or_phone)) {
        showToast("Please enter a valid username or email address.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email_or_phone, password })
        });
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Login failed.", "error");
            return;
        }
        
        showToast(`Welcome back, ${data.user.fullname}!`);
        loginSession(data.user);
        document.getElementById('login-form').reset();
    } catch (err) {
        showToast("Connection error: " + err.message, "error");
    }
}

async function handleRegisterSubmit(e) {
    e.preventDefault();
    const username = document.getElementById('reg-username').value.trim();
    const email = document.getElementById('reg-email').value.trim();
    const password = document.getElementById('reg-password').value;
    
    if (username.length < 3) {
        showToast("Username must be at least 3 characters.", "error");
        return;
    }
    if (!EMAIL_REGEX.test(email)) {
        showToast("Please enter a valid email address.", "error");
        return;
    }
    if (password.length < 6) {
        showToast("Password must be at least 6 characters.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/auth/register', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, email, password })
        });
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Registration failed.", "error");
            return;
        }
        
        showToast("Verification code sent successfully!");
        
        if (data.debug_otp) {
            showToast(`[DEV ONLY] OTP Code: ${data.debug_otp}`, "success");
            document.getElementById('reg-otp').value = data.debug_otp;
        }
        
        slideAuthPanel('otp');
    } catch (err) {
        showToast("Connection error: " + err.message, "error");
    }
}

async function handleOTPVerifySubmit(e) {
    e.preventDefault();
    const otp = document.getElementById('reg-otp').value.trim();
    
    if (otp.length !== 6 || isNaN(otp)) {
        showToast("OTP must be a 6-digit number.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/auth/verify_otp', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ otp })
        });
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "OTP verification failed.", "error");
            return;
        }
        
        showToast("Account created successfully! Please sign in.");
        document.getElementById('register-form').reset();
        document.getElementById('otp-form').reset();
        slideAuthPanel('login');
    } catch (err) {
        showToast("Connection error: " + err.message, "error");
    }
}

async function handleForgotPasswordSubmit(e) {
    e.preventDefault();
    const email_or_phone = document.getElementById('forgot-email-phone').value.trim();
    
    if (email_or_phone.length < 3) {
        showToast("Please enter a valid username or email address.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/auth/forgot-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email_or_phone })
        });
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Failed to request reset.", "error");
            return;
        }
        
        showToast("Reset verification code sent successfully!");
        state.resetEmailPhone = email_or_phone;
        
        if (data.debug_otp) {
            showToast(`[DEV ONLY] OTP Code: ${data.debug_otp}`, "success");
            document.getElementById('reset-otp').value = data.debug_otp;
        }
        
        slideAuthPanel('reset');
    } catch(err) {
        showToast("Connection error: " + err.message, "error");
    }
}

async function handleResetPasswordSubmit(e) {
    e.preventDefault();
    const otp = document.getElementById('reset-otp').value.trim();
    const new_password = document.getElementById('reset-new-password').value;
    
    if (otp.length !== 6 || isNaN(otp)) {
        showToast("OTP must be a 6-digit number.", "error");
        return;
    }
    if (new_password.length < 6) {
        showToast("Password must be at least 6 characters.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/auth/reset-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email_or_phone: state.resetEmailPhone,
                otp,
                new_password
            })
        });
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Reset password failed.", "error");
            return;
        }
        
        showToast("Password reset successfully! Please sign in with your new password.");
        document.getElementById('forgot-password-form').reset();
        document.getElementById('reset-password-form').reset();
        slideAuthPanel('login');
    } catch(err) {
        showToast("Connection error: " + err.message, "error");
    }
}

// Switch between tabs in Admin Panel
function switchTab(tabName) {
    if (!state.user || state.user.role !== 'admin') return;
    
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    
    if (tabName === 'pos') {
        document.getElementById('btn-tab-pos').classList.add('active');
        document.getElementById('tab-pos').classList.add('active');
        document.getElementById('pos-search-input').focus();
    } else if (tabName === 'inventory') {
        document.getElementById('btn-tab-inventory').classList.add('active');
        document.getElementById('tab-inventory').classList.add('active');
        loadCatalog();
    } else if (tabName === 'orders') {
        document.getElementById('btn-tab-orders').classList.add('active');
        document.getElementById('tab-orders').classList.add('active');
        loadAdminOrders();
    } else if (tabName === 'announcements') {
        document.getElementById('btn-tab-announcements').classList.add('active');
        document.getElementById('tab-announcements').classList.add('active');
        loadAnnouncementsIntoForm();
    }
}

// ==========================================
// ADMIN CATALOG OPERATIONS
// ==========================================

async function loadDashboardMetrics() {
    if (!state.user || state.user.role !== 'admin') return;
    try {
        const response = await fetch('/api/dashboard/metrics');
        const data = await response.json();
        if (response.ok) {
            document.getElementById('metric-total-products').innerText = data.total_products;
            document.getElementById('metric-low-stock').innerText = data.low_stock_count;
            document.getElementById('metric-revenue').innerText = formatINR(data.today_revenue);
            
            const lowStockCard = document.getElementById('metric-low-stock-card');
            if (data.low_stock_count > 0) {
                lowStockCard.style.borderColor = 'rgba(245, 158, 11, 0.4)';
            } else {
                lowStockCard.style.borderColor = '';
            }
        }
    } catch (err) {
        console.error(err);
    }
}

async function loadCatalog() {
    if (!state.user) return;
    
    const page = state.catalog.currentPage;
    const perPage = state.catalog.perPage;
    const search = state.catalog.searchQuery;
    
    try {
        let response = await fetch(`/api/products?page=${page}&per_page=${perPage}&search=${encodeURIComponent(search)}`);
        response = await handleResponse(response);
        const data = await response.json();
        
        state.catalog.products = data.products;
        state.catalog.totalPages = data.total_pages;
        state.catalog.totalCount = data.total_count;
        
        renderCatalogTable();
        await loadAdminCategoryDetails();
        loadDashboardMetrics();
    } catch (err) {
        if (err.message !== "Unauthorized") {
            showToast("Error loading catalog: " + err.message, "error");
        }
    }
}

function renderCatalogTable() {
    const tbody = document.getElementById('catalog-table-body');
    tbody.innerHTML = '';
    
    if (state.catalog.products.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 2rem;">No products found in catalog.</td></tr>`;
        updatePaginationUI();
        return;
    }
    
    state.catalog.products.forEach(prod => {
        const tr = document.createElement('tr');
        
        let stockBadgeHtml = '';
        if (prod.stock === 0) {
            stockBadgeHtml = `<span class="badge badge-out-of-stock">Out of stock</span>`;
        } else if (prod.stock < 5) {
            stockBadgeHtml = `<span class="badge badge-low-stock">Low stock (${prod.stock})</span>`;
        } else {
            stockBadgeHtml = `<span class="badge badge-in-stock">In stock (${prod.stock})</span>`;
        }
        
        let statusBadge = prod.status === 'published' ? 
            `<span class="badge badge-published">Published</span>` : 
            `<span class="badge badge-draft">Draft</span>`;
            
        tr.innerHTML = `
            <td style="font-family: monospace; font-weight: 500;">${prod.sku}</td>
            <td style="font-weight: 600;">${prod.name}<br>${statusBadge}</td>
            <td><span style="font-size: 0.85rem; background: var(--background); padding: 0.2rem 0.6rem; border-radius: 6px;">${prod.category || 'General'}</span></td>
            <td>${formatINR(prod.purchase_price)}</td>
            <td style="font-weight: 700; color: var(--teal);">${formatINR(prod.selling_price)}</td>
            <td>${stockBadgeHtml}</td>
            <td style="text-align: center; display: flex; justify-content: center; gap: 0.5rem;">
                <button class="btn btn-secondary btn-icon" onclick="openEditModal(${prod.id})" title="Edit Details">✏️</button>
                <button class="btn btn-danger btn-icon" onclick="deleteProduct(${prod.id})" title="Delete Product">🗑️</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
    
    updatePaginationUI();
}

async function deleteProduct(productId) {
    if (!confirm("Are you sure you want to delete this product from the catalog?")) return;
    try {
        let response = await fetch(`/api/products/delete/${productId}`, { method: 'DELETE' });
        response = await handleResponse(response);
        if (response.ok) {
            showToast("Product deleted successfully.");
            loadCatalog();
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}

function updatePaginationUI() {
    const infoText = document.getElementById('pagination-info-text');
    const prevBtn = document.getElementById('pagination-prev');
    const nextBtn = document.getElementById('pagination-next');
    
    infoText.innerText = `Showing page ${state.catalog.currentPage} of ${state.catalog.totalPages} (${state.catalog.totalCount} total products)`;
    prevBtn.disabled = state.catalog.currentPage <= 1;
    nextBtn.disabled = state.catalog.currentPage >= state.catalog.totalPages;
}

function changeCatalogPage(direction) {
    state.catalog.currentPage += direction;
    loadCatalog();
}

function handleInventorySearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        state.catalog.searchQuery = document.getElementById('inventory-search-input').value.trim();
        state.catalog.currentPage = 1;
        loadCatalog();
    }, 300);
}

// Dynamic Category tree builder mapping (Hierarchical mapping)
function buildCategoryTree(categories) {
    const map = {};
    const roots = [];
    categories.forEach(item => {
        map[item.id] = { ...item, children: [] };
    });
    categories.forEach(item => {
        if (item.parent_id) {
            if (map[item.parent_id]) {
                map[item.parent_id].children.push(map[item.id]);
            }
        } else {
            roots.push(map[item.id]);
        }
    });
    return roots;
}

// Populates category selects under indented prefixes
function populateCategoryDropdowns(categories) {
    const tree = buildCategoryTree(categories);
    
    const prodSelect = document.getElementById('prod-category-id');
    const editSelect = document.getElementById('edit-prod-category-id');
    const parentSelect = document.getElementById('cat-parent-id');
    
    let optionsHtml = '<option value="">-- Choose Category --</option>';
    let parentOptionsHtml = '<option value="">-- None (Root Node) --</option>';
    
    function buildOptions(nodes, depth = 0) {
        let html = '';
        const prefix = '&nbsp;&nbsp;'.repeat(depth) + (depth > 0 ? '↳ ' : '');
        nodes.forEach(node => {
            html += `<option value="${node.id}">${prefix}${node.name}</option>`;
            if (node.children && node.children.length > 0) {
                html += buildOptions(node.children, depth + 1);
            }
        });
        return html;
    }
    
    const treeOptions = buildOptions(tree, 0);
    optionsHtml += treeOptions;
    parentOptionsHtml += treeOptions;
    
    if (prodSelect) prodSelect.innerHTML = optionsHtml;
    if (editSelect) editSelect.innerHTML = optionsHtml;
    if (parentSelect) parentSelect.innerHTML = parentOptionsHtml;
}

async function loadAdminCategoryDetails() {
    try {
        const response = await fetch('/api/categories');
        const categories = await response.json();
        state.storefront.categories = categories;
        populateCategoryDropdowns(categories);
    } catch(e) {
        console.error(e);
    }
}

async function handleCategoryFormSubmit(e) {
    e.preventDefault();
    const name = document.getElementById('cat-name').value.trim();
    const parent_id_val = document.getElementById('cat-parent-id').value;
    
    const parent_id = parent_id_val ? parseInt(parent_id_val) : null;
    
    try {
        const response = await fetch('/api/categories', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, parent_id })
        });
        const data = await response.json();
        
        if (response.ok) {
            showToast("Category node created successfully!");
            document.getElementById('admin-category-form').reset();
            await loadAdminCategoryDetails();
        } else {
            showToast(data.error || "Failed to create category.", "error");
        }
    } catch(err) {
        showToast("Connection failed: " + err.message, "error");
    }
}

async function handleProductFormSubmit(e) {
    e.preventDefault();
    const sku = document.getElementById('prod-sku').value.trim();
    const name = document.getElementById('prod-name').value.trim();
    const category_id = document.getElementById('prod-category-id').value;
    const status = document.getElementById('prod-status').value;
    const image_url = document.getElementById('prod-image-url').value.trim();
    const purchase_price = parseFloat(document.getElementById('prod-purchase-price').value);
    const selling_price = parseFloat(document.getElementById('prod-selling-price').value);
    const stock = parseInt(document.getElementById('prod-stock').value);
    
    const payload = { sku, name, category_id, status, purchase_price, selling_price, stock, image_url };
    
    try {
        let response = await fetch('/api/products', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        response = await handleResponse(response);
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Failed to add product", "error");
            return;
        }
        
        showToast("Product added to catalog successfully!");
        document.getElementById('product-form').reset();
        loadCatalog();
    } catch (err) {
        if (err.message !== "Unauthorized") {
            showToast("Connection error: " + err.message, "error");
        }
    }
}

async function openEditModal(productId) {
    const product = state.catalog.products.find(p => p.id === productId);
    if (!product) return;
    
    document.getElementById('edit-prod-id').value = product.id;
    document.getElementById('edit-prod-sku').value = product.sku;
    document.getElementById('edit-prod-name').value = product.name;
    document.getElementById('edit-prod-category-id').value = product.category_id || '';
    document.getElementById('edit-prod-status').value = product.status || 'draft';
    document.getElementById('edit-prod-image-url').value = product.image_url || '';
    document.getElementById('edit-prod-purchase-price').value = product.purchase_price;
    document.getElementById('edit-prod-selling-price').value = product.selling_price;
    document.getElementById('edit-prod-stock').value = product.stock;
    
    document.getElementById('edit-product-modal').classList.add('active');
}

function closeEditModal() {
    document.getElementById('edit-product-modal').classList.remove('active');
}

async function handleEditFormSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('edit-prod-id').value;
    const sku = document.getElementById('edit-prod-sku').value.trim();
    const name = document.getElementById('edit-prod-name').value.trim();
    const category_id = document.getElementById('edit-prod-category-id').value;
    const status = document.getElementById('edit-prod-status').value;
    const image_url = document.getElementById('edit-prod-image-url').value.trim();
    const purchase_price = parseFloat(document.getElementById('edit-prod-purchase-price').value);
    const selling_price = parseFloat(document.getElementById('edit-prod-selling-price').value);
    const stock = parseInt(document.getElementById('edit-prod-stock').value);
    
    const payload = { product_id: id, sku, name, category_id, status, purchase_price, selling_price, stock, image_url };
    
    try {
        let response = await fetch('/api/products', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        response = await handleResponse(response);
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Failed to update product", "error");
            return;
        }
        
        showToast("Product updated successfully!");
        closeEditModal();
        loadCatalog();
    } catch (err) {
        showToast(err.message, "error");
    }
}

// ==========================================
// POINT OF SALE (POS) CASH BILLING
// ==========================================

async function handlePOSSearchInput(e) {
    const query = e.target.value.trim();
    if (!query) {
        closePOSSuggestions();
        return;
    }
    
    try {
        const response = await fetch(`/api/products/search?q=${encodeURIComponent(query)}`);
        const suggestions = await response.json();
        state.pos.suggestions = suggestions;
        state.pos.highlightedSuggestionIndex = -1;
        
        renderPOSSuggestions();
    } catch (err) {
        console.error(err);
    }
}

function renderPOSSuggestions() {
    const container = document.getElementById('pos-suggestions');
    container.innerHTML = '';
    
    if (state.pos.suggestions.length === 0) {
        container.style.display = 'none';
        return;
    }
    
    state.pos.suggestions.forEach((item, index) => {
        const div = document.createElement('div');
        div.className = 'suggestion-item';
        if (index === state.pos.highlightedSuggestionIndex) {
            div.classList.add('highlighted');
        }
        
        let stockIndicator = `<span class="suggestion-stock">Stock: ${item.stock}</span>`;
        if (item.stock === 0) {
            stockIndicator = `<span class="suggestion-stock low">Out of Stock</span>`;
        } else if (item.stock < 5) {
            stockIndicator = `<span class="suggestion-stock low">Low Stock (${item.stock})</span>`;
        }
        
        div.innerHTML = `
            <div>
                <div class="suggestion-name">${item.name}</div>
                <div class="suggestion-meta">SKU: ${item.sku} | ${stockIndicator}</div>
            </div>
            <div class="suggestion-price">${formatINR(item.selling_price)}</div>
        `;
        
        div.addEventListener('click', () => {
            selectPOSSuggestion(item);
        });
        
        container.appendChild(div);
    });
    
    container.style.display = 'block';
}

function selectPOSSuggestion(product) {
    if (product.stock === 0) {
        showToast(`Product '${product.name}' is out of stock.`, "error");
        return;
    }
    
    addPOSCartItem(product);
    
    const searchInput = document.getElementById('pos-search-input');
    searchInput.value = '';
    closePOSSuggestions();
    searchInput.focus();
}

function handlePOSSearchKeydown(e) {
    const suggestions = state.pos.suggestions;
    let index = state.pos.highlightedSuggestionIndex;
    
    if (e.key === 'ArrowDown') {
        e.preventDefault();
        index = (index + 1) % suggestions.length;
        state.pos.highlightedSuggestionIndex = index;
        renderPOSSuggestions();
    } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        index = (index - 1 + suggestions.length) % suggestions.length;
        state.pos.highlightedSuggestionIndex = index;
        renderPOSSuggestions();
    } else if (e.key === 'Enter') {
        e.preventDefault();
        if (index >= 0 && index < suggestions.length) {
            selectPOSSuggestion(suggestions[index]);
        } else if (suggestions.length > 0) {
            selectPOSSuggestion(suggestions[0]);
        }
    }
}

function closePOSSuggestions() {
    document.getElementById('pos-suggestions').style.display = 'none';
    state.pos.suggestions = [];
    state.pos.highlightedSuggestionIndex = -1;
}

function addPOSCartItem(product) {
    const existingItem = state.posCart.find(item => item.product_id === product.id);
    
    if (existingItem) {
        if (existingItem.quantity + 1 > product.stock) {
            showToast(`Cannot add more '${product.name}': Exceeds stock limit (${product.stock}).`, "error");
            return;
        }
        existingItem.quantity += 1;
    } else {
        state.posCart.push({
            product_id: product.id,
            sku: product.sku,
            name: product.name,
            selling_price: product.selling_price,
            quantity: 1,
            stock: product.stock
        });
    }
    
    renderPOSCart();
    calculatePOSCartTotals();
    triggerPOSRowFlash(product.id);
}

function renderPOSCart() {
    const tbody = document.getElementById('cart-items-body');
    const emptyState = document.getElementById('cart-empty-message');
    
    tbody.innerHTML = '';
    
    if (state.posCart.length === 0) {
        emptyState.style.display = 'block';
        document.getElementById('cart-table').style.display = 'none';
        return;
    }
    
    emptyState.style.display = 'none';
    document.getElementById('cart-table').style.display = 'table';
    
    state.posCart.forEach(item => {
        const tr = document.createElement('tr');
        tr.id = `cart-row-${item.product_id}`;
        const itemTotal = item.selling_price * item.quantity;
        
        tr.innerHTML = `
            <td style="font-weight: 600; color: var(--primary);">${item.name}</td>
            <td style="font-family: monospace;">${item.sku}</td>
            <td>${formatINR(item.selling_price)}</td>
            <td>
                <div class="cart-item-qty">
                    <button class="btn btn-secondary btn-icon" onclick="changePOSQty(${item.product_id}, -1)">-</button>
                    <input type="number" value="${item.quantity}" min="1" max="${item.stock}" onchange="setPOSQty(${item.product_id}, this.value)">
                    <button class="btn btn-secondary btn-icon" onclick="changePOSQty(${item.product_id}, 1)">+</button>
                </div>
            </td>
            <td style="font-weight: 700; color: var(--primary);">${formatINR(itemTotal)}</td>
            <td style="text-align: center;">
                <button class="btn btn-danger btn-icon" onclick="removeFromPOSCart(${item.product_id})">🗑️</button>
            </td>
        `;
        
        tbody.appendChild(tr);
    });
}

function triggerPOSRowFlash(productId) {
    const row = document.getElementById(`cart-row-${productId}`);
    if (row) {
        row.classList.remove('item-flash');
        void row.offsetWidth;
        row.classList.add('item-flash');
    }
}

function changePOSQty(productId, delta) {
    const item = state.posCart.find(i => i.product_id === productId);
    if (!item) return;
    
    const newQty = item.quantity + delta;
    if (newQty < 1) {
        removeFromPOSCart(productId);
        return;
    }
    if (newQty > item.stock) {
        showToast(`Cannot exceed available stock limit (${item.stock}).`, "error");
        return;
    }
    
    item.quantity = newQty;
    renderPOSCart();
    calculatePOSCartTotals();
    triggerPOSRowFlash(productId);
}

function setPOSQty(productId, value) {
    const item = state.posCart.find(i => i.product_id === productId);
    if (!item) return;
    
    let newQty = parseInt(value);
    if (isNaN(newQty) || newQty < 1) newQty = 1;
    
    if (newQty > item.stock) {
        showToast(`Requested quantity exceeds available stock (${item.stock}).`, "error");
        newQty = item.stock;
    }
    
    item.quantity = newQty;
    renderPOSCart();
    calculatePOSCartTotals();
    triggerPOSRowFlash(productId);
}

function removeFromPOSCart(productId) {
    state.posCart = state.posCart.filter(item => item.product_id !== productId);
    renderPOSCart();
    calculatePOSCartTotals();
    showToast("Item removed from billing.");
}

function clearCart() {
    if (state.posCart.length === 0) return;
    state.posCart = [];
    renderPOSCart();
    calculatePOSCartTotals();
    showToast("Billing cart cleared.");
}

function calculatePOSCartTotals() {
    let subtotal = 0;
    state.posCart.forEach(item => {
        subtotal += item.selling_price * item.quantity;
    });
    
    const taxRateInput = document.getElementById('pos-tax-rate');
    let taxRate = parseFloat(taxRateInput.value);
    if (isNaN(taxRate) || taxRate < 0) taxRate = 0;
    
    const taxAmount = subtotal * (taxRate / 100);
    const grandTotal = subtotal + taxAmount;
    
    document.getElementById('pos-summary-subtotal').innerText = formatINR(subtotal);
    document.getElementById('pos-summary-tax').innerText = formatINR(taxAmount);
    
    const totalEl = document.getElementById('pos-summary-total');
    totalEl.innerText = formatINR(grandTotal);
    
    totalEl.classList.remove('total-pulse');
    void totalEl.offsetWidth;
    totalEl.classList.add('total-pulse');
}

async function completeCheckout() {
    if (state.posCart.length === 0) {
        showToast("Cart is empty.", "error");
        return;
    }
    
    const taxRate = parseFloat(document.getElementById('pos-tax-rate').value) || 0;
    const checkoutCart = state.posCart.map(item => ({
        product_id: item.product_id,
        quantity: item.quantity
    }));
    
    try {
        let response = await fetch('/api/sales/complete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ cart: checkoutCart, tax_rate: taxRate })
        });
        response = await handleResponse(response);
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Checkout failed", "error");
            return;
        }
        
        showToast("Transaction logged successfully!");
        renderPrintableReceipt(data.receipt);
        
        state.posCart = [];
        renderPOSCart();
        calculatePOSCartTotals();
        loadCatalog();
    } catch (err) {
        showToast(err.message, "error");
    }
}

function renderPrintableReceipt(receipt) {
    const container = document.getElementById('receipt-modal-content');
    
    let itemsHtml = receipt.items.map(item => `
        <div class="receipt-item-row">
            <span>${item.name} (x${item.quantity})</span>
            <span>${formatINR(item.total)}</span>
        </div>
        <div class="receipt-item-desc">
            ${item.quantity} x ${formatINR(item.price)}
        </div>
    `).join('');
    
    const dateFormatted = new Date(receipt.sale_date).toLocaleString('en-IN');
    
    container.innerHTML = `
        <div class="receipt-wrapper">
            <div class="receipt-header">
                <div class="receipt-store-name">RAMA STORE</div>
                <div class="receipt-meta">
                    <div>Tracking ID: ${receipt.tracking_number}</div>
                    <div>Date: ${dateFormatted}</div>
                </div>
            </div>
            <div class="receipt-items">
                ${itemsHtml}
            </div>
            <div class="receipt-totals">
                <div class="receipt-divider"></div>
                <div class="receipt-line">
                    <span>Subtotal</span>
                    <span>${formatINR(receipt.subtotal)}</span>
                </div>
                <div class="receipt-line">
                    <span>GST Tax (${receipt.tax_rate}%)</span>
                    <span>${formatINR(receipt.tax_amount)}</span>
                </div>
                <div class="receipt-divider"></div>
                <div class="receipt-line grand-total">
                    <span>Total Amount</span>
                    <span>${formatINR(receipt.total_amount)}</span>
                </div>
            </div>
            <div class="receipt-footer">
                Thank you for shopping with us!
            </div>
        </div>
    `;
    
    document.getElementById('receipt-modal').classList.add('active');
}

function closeReceiptModal() {
    document.getElementById('receipt-modal').classList.remove('active');
}

function printReceipt() {
    window.print();
}

// ==========================================
// CUSTOMER STOREFRONT & CATALOGS (RETAIL)
// ==========================================

async function initStorefront() {
    state.storefront.currentPage = 1;
    state.storefront.hasMore = true;
    state.products = [];
    
    document.getElementById('storefront-products-grid').innerHTML = '';
    
    await loadStoreCategories();
    await fetchStorefrontProducts(true);
    await loadAnnouncementsStorefront();
}

async function loadStoreCategories() {
    try {
        const response = await fetch('/api/categories');
        const categories = await response.json();
        state.storefront.categories = categories;
        
        const container = document.getElementById('store-filter-categories');
        const tree = buildCategoryTree(categories);
        renderSidebarCategoryTree(tree, container);
    } catch (err) {
        console.error(err);
    }
}

// Renders Amazon-Style Left Sidebar Categories Tree (with nested indents)
function renderSidebarCategoryTree(treeNodes, containerEl) {
    containerEl.innerHTML = '';
    
    const allChip = document.createElement('div');
    allChip.className = `category-tree-node ${state.storefront.activeCategory === null ? 'active' : ''}`;
    allChip.innerHTML = `📁 All Collection`;
    allChip.onclick = () => selectStoreCategory(null);
    containerEl.appendChild(allChip);
    
    function renderNode(node, parentEl) {
        const nodeEl = document.createElement('div');
        nodeEl.className = 'category-node-wrapper';
        
        const chip = document.createElement('div');
        chip.className = `category-tree-node ${state.storefront.activeCategory === node.id ? 'active' : ''}`;
        chip.innerHTML = `📄 ${node.name}`;
        chip.onclick = (e) => {
            e.stopPropagation();
            selectStoreCategory(node.id);
        };
        nodeEl.appendChild(chip);
        
        if (node.children && node.children.length > 0) {
            const childrenEl = document.createElement('div');
            childrenEl.className = 'category-tree-children';
            node.children.forEach(child => {
                renderNode(child, childrenEl);
            });
            nodeEl.appendChild(childrenEl);
        }
        parentEl.appendChild(nodeEl);
    }
    
    treeNodes.forEach(node => {
        renderNode(node, containerEl);
    });
}

function selectStoreCategory(categoryId) {
    state.storefront.activeCategory = categoryId;
    loadStoreCategories();
    
    state.storefront.currentPage = 1;
    state.storefront.hasMore = true;
    document.getElementById('storefront-products-grid').innerHTML = '';
    fetchStorefrontProducts(true);
}

function updatePriceSliderLabel(value) {
    state.storefront.maxPrice = parseFloat(value);
    document.getElementById('price-slider-max-label').innerText = formatINR(value);
    
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        state.storefront.currentPage = 1;
        state.storefront.hasMore = true;
        document.getElementById('storefront-products-grid').innerHTML = '';
        fetchStorefrontProducts(true);
    }, 400);
}

function triggerStoreSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        state.storefront.searchQuery = document.getElementById('store-search-input').value.trim();
        state.storefront.currentPage = 1;
        state.storefront.hasMore = true;
        document.getElementById('storefront-products-grid').innerHTML = '';
        fetchStorefrontProducts(true);
    }, 300);
}

function resetStoreFilters() {
    state.storefront.activeCategory = null;
    state.storefront.maxPrice = 2000;
    state.storefront.searchQuery = '';
    
    document.getElementById('price-slider-input').value = 2000;
    document.getElementById('price-slider-max-label').innerText = "₹2,000";
    document.getElementById('store-search-input').value = '';
    
    initStorefront();
}

function scrollStoreToCatalog() {
    const el = document.getElementById('storefront-grid-boundary');
    if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

async function fetchStorefrontProducts(isNewQuery = false) {
    if (state.storefront.isLoading || (!state.storefront.hasMore && !isNewQuery)) return;
    
    state.storefront.isLoading = true;
    renderStorefrontSkeletons();
    
    const page = state.storefront.currentPage;
    const cat = state.storefront.activeCategory;
    const price = state.storefront.maxPrice;
    const search = state.storefront.searchQuery;
    
    try {
        const response = await fetch(`/api/store/products?page=${page}&per_page=8&category_id=${cat}&max_price=${price}&search=${encodeURIComponent(search)}`);
        const data = await response.json();
        
        removeStorefrontSkeletons();
        
        const grid = document.getElementById('storefront-products-grid');
        
        if (data.products.length === 0 && page === 1) {
            grid.innerHTML = `<div style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 4rem;">No items match your criteria.</div>`;
            state.storefront.hasMore = false;
            state.storefront.isLoading = false;
            return;
        }
        
        if (isNewQuery) {
            state.products = data.products;
        } else {
            state.products.push(...data.products);
        }
        
        // Render Usual Basket Row
        renderUsualBasket();
        
        data.products.forEach(prod => {
            const card = document.createElement('div');
            card.className = 'product-card';
            
            const imageSrc = prod.image_url || 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400&q=80';
            
            card.innerHTML = `
                <div class="product-card-img-wrapper">
                    <img data-src="${imageSrc}" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1 1'%3E%3C/svg%3E" alt="${prod.name}" class="lazy-load-image">
                </div>
                <div class="product-card-body">
                    <span class="product-card-category">${prod.category || 'General'}</span>
                    <h3 class="product-card-title">${prod.name}</h3>
                    <div class="product-card-footer">
                        <span class="product-card-price">${formatINR(prod.selling_price)}</span>
                        <button class="btn-add-to-cart" onclick="addToCart(${prod.id})" title="Add to Cart">🛒</button>
                    </div>
                </div>
            `;
            grid.appendChild(card);
        });
        
        triggerLazyLoading();
        
        state.storefront.totalPages = data.total_pages;
        state.storefront.hasMore = page < data.total_pages;
        state.storefront.isLoading = false;
    } catch (err) {
        removeStorefrontSkeletons();
        state.storefront.isLoading = false;
        console.error(err);
    }
}

function renderStorefrontSkeletons() {
    const grid = document.getElementById('storefront-products-grid');
    for (let i = 0; i < 4; i++) {
        const div = document.createElement('div');
        div.className = 'skeleton-card temp-skeleton';
        div.innerHTML = `
            <div class="skeleton-shimmer skeleton-img"></div>
            <div class="skeleton-shimmer skeleton-line-sm"></div>
            <div class="skeleton-shimmer skeleton-line-md"></div>
            <div class="skeleton-footer">
                <div class="skeleton-shimmer skeleton-price"></div>
                <div class="skeleton-shimmer skeleton-btn"></div>
            </div>
        `;
        grid.appendChild(div);
    }
}

function removeStorefrontSkeletons() {
    document.querySelectorAll('.temp-skeleton').forEach(el => el.remove());
}

function triggerLazyLoading() {
    const images = document.querySelectorAll('.lazy-load-image');
    
    if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const img = entry.target;
                    img.src = img.getAttribute('data-src');
                    img.classList.remove('lazy-load-image');
                    observer.unobserve(img);
                }
            });
        });
        images.forEach(img => observer.observe(img));
    } else {
        images.forEach(img => img.src = img.getAttribute('data-src'));
    }
}

function initInfiniteScrollObserver() {
    const trigger = document.getElementById('infinite-scroll-trigger');
    if (!trigger) return;
    
    const observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && !state.storefront.isLoading && state.storefront.hasMore) {
            state.storefront.currentPage++;
            fetchStorefrontProducts();
        }
    }, { rootMargin: '100px' });
    
    observer.observe(trigger);
}

// ==========================================
// ACTIVE CLIENT CART OPERATIONS
// ==========================================

function loadCustomerCartFromStorage() {
    try {
        const localData = localStorage.getItem('rama_store_client_cart');
        state.cart = localData ? JSON.parse(localData) : [];
        updateCustomerCartBadgeUI();
    } catch(e) {
        state.cart = [];
    }
}

function saveCustomerCartToStorage() {
    localStorage.setItem('rama_store_client_cart', JSON.stringify(state.cart));
    updateCustomerCartBadgeUI();
}

function updateCustomerCartBadgeUI() {
    const badge = document.getElementById('cart-badge-count');
    const totalCount = state.cart.reduce((sum, item) => sum + item.quantity, 0);
    badge.innerText = totalCount;
    
    badge.classList.remove('total-pulse');
    void badge.offsetWidth;
    badge.classList.add('total-pulse');
}

async function addToCart(productId) {
    const product = state.products ? state.products.find(p => p.id === productId) : null;
    
    let targetProduct = product;
    if (!targetProduct) {
        try {
            const res = await fetch(`/api/products/search?q=${productId}`);
            const items = await res.json();
            targetProduct = items.find(i => i.id === productId);
        } catch(e) {}
    }
    
    if (!targetProduct) {
        try {
            const response = await fetch(`/api/store/products?search=${productId}`);
            const data = await response.json();
            targetProduct = data.products.find(p => p.id === productId);
        } catch(e) {}
    }
    
    if (!targetProduct) {
        showToast("Product details not available.", "error");
        return;
    }
    
    const existing = state.cart.find(item => item.product_id === targetProduct.id);
    if (existing) {
        if (existing.quantity + 1 > targetProduct.stock) {
            showToast(`Exceeds maximum store stock limit.`, "error");
            return;
        }
        existing.quantity += 1;
    } else {
        state.cart.push({
            product_id: targetProduct.id,
            sku: targetProduct.sku,
            name: targetProduct.name,
            selling_price: targetProduct.selling_price,
            image_url: targetProduct.image_url,
            quantity: 1,
            stock: targetProduct.stock
        });
    }
    
    saveCustomerCartToStorage();
    showToast(`Added '${targetProduct.name}' to cart successfully!`);
}

function removeFromCart(productId) {
    state.cart = state.cart.filter(item => item.product_id !== productId);
    saveCustomerCartToStorage();
    renderCustomerCart();
    showToast("Item removed from cart.");
}

function updateQuantity(productId, delta) {
    const item = state.cart.find(i => i.product_id === productId);
    if (!item) return;
    
    const newQty = item.quantity + delta;
    if (newQty < 1) {
        removeFromCart(productId);
        return;
    }
    
    if (newQty > item.stock) {
        showToast("Exceeds available inventory stock.", "error");
        return;
    }
    
    item.quantity = newQty;
    saveCustomerCartToStorage();
    renderCustomerCart();
}

function changeCustomerCartQty(pid, delta) {
    updateQuantity(pid, delta);
}

function removeCustomerCartItem(pid) {
    removeFromCart(pid);
}

function toggleCartDrawer(open) {
    const drawer = document.getElementById('cart-drawer');
    if (open) {
        drawer.classList.add('active');
        renderCustomerCart();
    } else {
        drawer.classList.remove('active');
    }
}

function renderCustomerCart() {
    const list = document.getElementById('store-cart-list');
    const emptyState = document.getElementById('store-cart-empty');
    const footer = document.getElementById('store-cart-footer');
    
    list.innerHTML = '';
    
    if (state.cart.length === 0) {
        emptyState.style.display = 'block';
        list.style.display = 'none';
        footer.style.display = 'none';
        return;
    }
    
    emptyState.style.display = 'none';
    list.style.display = 'flex';
    footer.style.display = 'block';
    
    let subtotal = 0.0;
    
    state.cart.forEach(item => {
        const itemTotal = item.selling_price * item.quantity;
        subtotal += itemTotal;
        
        const div = document.createElement('div');
        div.className = 'drawer-cart-item';
        
        const imgUrl = item.image_url || 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400&q=80';
        
        div.innerHTML = `
            <img src="${imgUrl}" alt="${item.name}" class="drawer-item-img">
            <div class="drawer-item-info">
                <div class="drawer-item-title">${item.name}</div>
                <div class="drawer-item-sku">SKU: ${item.sku}</div>
                <div class="drawer-item-price">${formatINR(item.selling_price)}</div>
                <div class="drawer-item-actions">
                    <div class="drawer-item-qty">
                        <button class="btn btn-secondary btn-icon" onclick="changeCustomerCartQty(${item.product_id}, -1)">-</button>
                        <input type="number" value="${item.quantity}" readonly>
                        <button class="btn btn-secondary btn-icon" onclick="changeCustomerCartQty(${item.product_id}, 1)">+</button>
                    </div>
                    <button class="btn btn-danger btn-icon" onclick="removeCustomerCartItem(${item.product_id})">🗑️</button>
                </div>
            </div>
        `;
        list.appendChild(div);
    });
    
    const tax = subtotal * 0.18; // 18% GST tax rate
    const total = subtotal + tax;
    
    document.getElementById('store-cart-subtotal').innerText = formatINR(subtotal);
    document.getElementById('store-cart-tax').innerText = formatINR(tax);
    
    const totalEl = document.getElementById('store-cart-total');
    totalEl.innerText = formatINR(total);
    
    totalEl.classList.remove('total-pulse');
    void totalEl.offsetWidth;
    totalEl.classList.add('total-pulse');
}

// ==========================================
// STOREFRONT CHECKOUT DRAWER
// ==========================================

function toggleCheckoutDrawer(open) {
    const sheet = document.getElementById('checkout-sheet');
    if (open) {
        sheet.classList.add('active');
        populateCheckoutReviewTotals();
    } else {
        sheet.classList.remove('active');
    }
}

function openCheckoutDrawer() {
    if (!state.user) {
        toggleCartDrawer(false);
        showToast("Authentication required to complete order. Please sign in.", "error");
        openLoginOverlay();
        return;
    }
    
    toggleCartDrawer(false);
    toggleCheckoutDrawer(true);
}

function populateCheckoutReviewTotals() {
    let subtotal = 0.0;
    state.cart.forEach(item => {
        subtotal += item.selling_price * item.quantity;
    });
    const total = subtotal * 1.18; // 18% GST
    
    document.getElementById('checkout-review-subtotal').innerText = formatINR(subtotal);
    document.getElementById('checkout-review-total').innerText = formatINR(total);
}

async function handleCustomerCheckoutSubmit(e) {
    e.preventDefault();
    
    const address = document.getElementById('checkout-shipping-address').value.trim();
    if (!address) {
        showToast("Delivery address is required.", "error");
        return;
    }
    
    const checkoutCart = state.cart.map(item => ({
        product_id: item.product_id,
        quantity: item.quantity
    }));
    
    try {
        let response = await fetch('/api/checkout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                cart: checkoutCart,
                shipping_address: address
            })
        });
        
        response = await handleResponse(response);
        const data = await response.json();
        
        if (!response.ok) {
            showToast(data.error || "Order checkout session failed", "error");
            return;
        }
        
        state.storefront.currentSession = data.session;
        toggleCheckoutDrawer(false);
        openPaymentModal(data.session.total_amount);
    } catch(err) {
        showToast(err.message, "error");
    }
}

// ==========================================
// SANDBOX CARD PAYMENT GATEWAY PROCESSOR
// ==========================================

function openPaymentModal(totalAmount) {
    document.getElementById('payment-intent-total').innerText = formatINR(totalAmount);
    document.getElementById('payment-card-form').reset();
    document.getElementById('payment-card-brand').innerText = '💳';
    document.getElementById('payment-processing-overlay').style.display = 'none';
    
    document.getElementById('checkout-payment-modal').classList.add('active');
}

function closePaymentModal() {
    document.getElementById('checkout-payment-modal').classList.remove('active');
}

function initCardInputFormatters() {
    const cardInput = document.getElementById('payment-card-number');
    const expiryInput = document.getElementById('payment-card-expiry');
    const cardBrandLogo = document.getElementById('payment-card-brand');
    
    if (cardInput) {
        cardInput.addEventListener('input', (e) => {
            let value = e.target.value.replace(/\D/g, '');
            
            if (value.length > 16) value = value.slice(0, 16);
            
            if (value.startsWith('4')) {
                cardBrandLogo.innerText = 'Visa 💳';
                cardBrandLogo.style.color = '#2563eb';
            } else if (value.startsWith('5')) {
                cardBrandLogo.innerText = 'MC 💳';
                cardBrandLogo.style.color = '#ea580c';
            } else {
                cardBrandLogo.innerText = '💳';
                cardBrandLogo.style.color = '';
            }
            
            let formatted = value.match(/.{1,4}/g);
            e.target.value = formatted ? formatted.join(' ') : '';
        });
    }
    
    if (expiryInput) {
        expiryInput.addEventListener('input', (e) => {
            let value = e.target.value.replace(/\D/g, '');
            if (value.length > 4) value = value.slice(0, 4);
            
            if (value.length >= 2) {
                e.target.value = value.slice(0, 2) + '/' + value.slice(2);
            } else {
                e.target.value = value;
            }
        });
    }
}

async function handlePaymentFormSubmit(e) {
    e.preventDefault();
    
    const cardNum = document.getElementById('payment-card-number').value.replace(/\s/g, '');
    const expiry = document.getElementById('payment-card-expiry').value;
    const cvv = document.getElementById('payment-card-cvv').value;
    
    if (cardNum.length !== 16) {
        showToast("Please enter a valid 16-digit card number.", "error");
        return;
    }
    if (expiry.length !== 5) {
        showToast("Expiry must be formatted as MM/YY.", "error");
        return;
    }
    if (cvv.length !== 3) {
        showToast("CVV code must be 3 digits.", "error");
        return;
    }
    
    document.getElementById('payment-processing-overlay').style.display = 'flex';
    const session = state.storefront.currentSession;
    
    setTimeout(async () => {
        try {
            const response = await fetch('/api/payment/process', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    tracking_number: session.tracking_number,
                    card_number: cardNum,
                    cvv: cvv,
                    expiry: expiry
                })
            });
            
            const result = await response.json();
            document.getElementById('payment-processing-overlay').style.display = 'none';
            closePaymentModal();
            
            if (response.ok) {
                showToast("Payment processed successfully!");
                state.cart = [];
                saveCustomerCartToStorage();
                renderPrintableReceipt(session);
                creditCheckoutLoyaltyPoints(session.total_amount, session.tracking_number);
            } else {
                showToast(result.error || "Payment was declined by card issuer.", "error");
            }
        } catch (err) {
            document.getElementById('payment-processing-overlay').style.display = 'none';
            showToast("Gateway connection error: " + err.message, "error");
        }
    }, 2000);
}

async function cancelPaymentIntent() {
    const session = state.storefront.currentSession;
    if (!session) {
        closePaymentModal();
        return;
    }
    
    closePaymentModal();
    showToast("Cancelling checkout session... releasing stock.");
    
    try {
        await fetch('/api/payments/webhook', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                event: 'payment.failed',
                payment_intent_id: session.tracking_number
            })
        });
        showToast("Stock reservation released successfully.");
        state.storefront.currentSession = null;
    } catch(e) {
        console.error(e);
    }
}

// ==========================================
// STOREFRONT PROFILE NAVIGATION TABS
// ==========================================

function switchStorefrontTab(tab) {
    document.querySelectorAll('.store-tab-content').forEach(c => c.classList.remove('active'));
    document.querySelectorAll('.mobile-nav-item').forEach(i => i.classList.remove('active'));
    
    // Check if redirecting from admin panel view back to storefront view
    document.getElementById('admin-portal-view').style.display = 'none';
    document.getElementById('customer-storefront-view').style.display = 'flex';
    
    if (tab === 'home') {
        state.activeView = 'Storefront';
        document.getElementById('store-tab-home').classList.add('active');
        document.querySelectorAll('.mobile-nav-item')[0].classList.add('active');
    } else if (tab === 'profile') {
        if (!state.user) {
            showToast("Please sign in to view your profile.", "error");
            openLoginOverlay();
            return;
        }
        state.activeView = 'Profile';
        document.getElementById('store-tab-profile').classList.add('active');
        document.querySelectorAll('.mobile-nav-item')[4].classList.add('active');
        loadCustomerOrdersHistory();
    } else if (tab === 'rewards') {
        if (!state.user) {
            showToast("Please sign in to view your rewards.", "error");
            openLoginOverlay();
            return;
        }
        state.activeView = 'Rewards';
        document.getElementById('store-tab-rewards').classList.add('active');
        document.querySelectorAll('.mobile-nav-item')[3].classList.add('active');
        renderRewardsLedger();
        animatePoints(state.rewards.balance);
    }
}

async function loadCustomerOrdersHistory() {
    const container = document.getElementById('customer-orders-list-wrapper');
    container.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 2rem;">Loading your order history...</div>`;
    
    try {
        let response = await fetch('/api/orders/history');
        response = await handleResponse(response);
        const orders = await response.json();
        
        if (orders.length === 0) {
            container.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 3rem;">You haven't placed any orders yet.</div>`;
            return;
        }
        
        container.innerHTML = '';
        
        orders.forEach(order => {
            const div = document.createElement('div');
            div.className = 'order-ticket-stub';
            
            const dateStr = new Date(order.created_at).toLocaleDateString('en-IN');
            const estDate = new Date(new Date(order.created_at).getTime() + 2 * 24 * 60 * 60 * 1000).toLocaleDateString('en-IN');
            let itemsText = order.items.map(i => `${i.name} (x${i.quantity})`).join(', ');
            
            const currentStatus = order.status; // Pending | Paid | Shipped | Delivered | Cancelled
            let timelineHtml = '';
            let progressPct = '0%';
            
            if (currentStatus === 'Cancelled' || currentStatus === 'Failed') {
                timelineHtml = `
                    <div style="text-align: center; padding: 1rem; border: 2px dashed var(--vermilion); border-radius: var(--radius-sm); background-color: rgba(193, 69, 46, 0.05); color: var(--vermilion); font-weight: 700; font-family: var(--font-mono);">
                        ❌ ORDER STATUS: CANCELLED / FAILED
                    </div>
                `;
            } else {
                // Determine active/completed steps
                // Placed -> Packed -> Out for Delivery -> Delivered
                const stages = [
                    { key: 'placed', label: 'Placed', icon: '📝', completed: true, active: currentStatus === 'Pending' },
                    { key: 'packed', label: 'Packed', icon: '📦', completed: currentStatus === 'Paid' || currentStatus === 'Shipped' || currentStatus === 'Delivered', active: currentStatus === 'Paid' },
                    { key: 'out_for_delivery', label: 'Out for Delivery', icon: '🚚', completed: currentStatus === 'Shipped' || currentStatus === 'Delivered', active: currentStatus === 'Shipped' },
                    { key: 'delivered', label: 'Delivered', icon: '🏠', completed: currentStatus === 'Delivered', active: currentStatus === 'Delivered' }
                ];
                
                // Adjust active flags (highest completed is active if none is explicitly active)
                let activeFound = stages.some(s => s.active);
                if (!activeFound) {
                    for (let i = stages.length - 1; i >= 0; i--) {
                        if (stages[i].completed) {
                            stages[i].active = true;
                            break;
                        }
                    }
                }
                
                // Set progress percentage
                if (currentStatus === 'Paid') progressPct = '33.3%';
                else if (currentStatus === 'Shipped') progressPct = '66.6%';
                else if (currentStatus === 'Delivered') progressPct = '100%';
                
                const nodesHtml = stages.map(stage => {
                    let nodeClass = '';
                    if (stage.completed) nodeClass = 'completed';
                    if (stage.active) nodeClass = 'active';
                    
                    return `
                        <div class="stage-node ${nodeClass}">
                            <div class="stage-stamp">${stage.icon}</div>
                            <span class="stage-label">${stage.label}</span>
                        </div>
                    `;
                }).join('');
                
                timelineHtml = `
                    <div class="ticket-timeline-wrapper">
                        <div class="ticket-connecting-line-bg"></div>
                        <div class="ticket-connecting-line" id="progress-line-${order.id}"></div>
                        <div class="stage-nodes-row">
                            ${nodesHtml}
                        </div>
                    </div>
                `;
            }
            
            div.innerHTML = `
                <div class="ticket-stub-header">
                    <span class="ticket-no">ORDER NO. #TKT-${1000 + order.id}</span>
                    <span>EST. DELIVERY: ${estDate}</span>
                </div>
                <div class="ticket-stub-info-row">
                    <div class="ticket-stub-items">
                        <div style="font-weight: 700; color: var(--ink); margin-bottom: 0.25rem;">Items: <span style="font-weight: normal; color: var(--primary-muted);">${itemsText}</span></div>
                        <div style="font-size: 0.8rem; color: var(--text-muted);">Placed on: ${dateStr} | Tracking: ${order.tracking_number}</div>
                        <div style="font-size: 0.8rem; color: var(--text-muted); margin-top: 0.25rem;">Shipping to: ${order.shipping_address}</div>
                    </div>
                    <div class="ticket-stub-price">
                        ${formatINR(order.total_amount)}
                    </div>
                </div>
                ${timelineHtml}
            `;
            
            container.appendChild(div);
            
            // Animate progress line drawing
            if (currentStatus !== 'Cancelled' && currentStatus !== 'Failed') {
                setTimeout(() => {
                    const line = document.getElementById(`progress-line-${order.id}`);
                    if (line) line.style.width = progressPct;
                }, 100);
            }
        });
    } catch(err) {
        container.innerHTML = `<div style="text-align: center; color: var(--danger); padding: 2rem;">Error loading orders.</div>`;
    }
}

// ==========================================
// ADMIN PORTAL ORDERS MANAGEMENT
// ==========================================

async function loadAdminOrders() {
    const tbody = document.getElementById('admin-orders-table-body');
    tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 2rem;">Loading orders manager...</td></tr>`;
    
    try {
        let response = await fetch('/api/orders/admin/list');
        response = await handleResponse(response);
        const orders = await response.json();
        
        tbody.innerHTML = '';
        
        if (orders.length === 0) {
            tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 2rem;">No orders placed yet.</td></tr>`;
            return;
        }
        
        orders.forEach(order => {
            const tr = document.createElement('tr');
            const dateStr = new Date(order.created_at).toLocaleString('en-IN');
            
            let statusBadge = '';
            const status = order.status;
            
            if (status === 'Delivered') {
                statusBadge = '<span class="badge badge-in-stock">DELIVERED</span>';
            } else if (status === 'Shipped') {
                statusBadge = '<span class="badge badge-low-stock" style="background: rgba(99, 102, 241, 0.1); color: var(--accent); border-color: rgba(99, 102, 241, 0.2);">SHIPPED</span>';
            } else if (status === 'Cancelled') {
                statusBadge = '<span class="badge badge-out-of-stock" style="background: var(--danger-light); color: var(--danger); border-color: #fca5a5;">CANCELLED</span>';
            } else if (status === 'Paid') {
                statusBadge = '<span class="badge badge-in-stock" style="background: rgba(16, 185, 129, 0.1); color: var(--teal); border-color: rgba(16, 185, 129, 0.2);">PAID</span>';
            } else {
                statusBadge = '<span class="badge badge-low-stock">PENDING</span>';
            }
            
            const clientDetails = order.username ? `${order.username}<br><span style="font-size: 0.8rem; color: var(--text-muted);">${order.email}</span>` : 'Anonymous POS Walk-in';
            let addressDetails = order.shipping_address || 'Walk-in POS Collect';
            
            let actionSelect = '';
            if (order.shipping_address) {
                actionSelect = `
                    <select style="font-size: 0.85rem; padding: 0.25rem 0.5rem;" onchange="updateAdminOrderStatus(${order.id}, this.value)">
                        <option value="Pending" ${status === 'Pending' ? 'selected' : ''}>PENDING</option>
                        <option value="Paid" ${status === 'Paid' ? 'selected' : ''}>PAID</option>
                        <option value="Shipped" ${status === 'Shipped' ? 'selected' : ''}>SHIPPED</option>
                        <option value="Delivered" ${status === 'Delivered' ? 'selected' : ''}>DELIVERED</option>
                        <option value="Cancelled" ${status === 'Cancelled' ? 'selected' : ''}>CANCELLED</option>
                    </select>
                `;
            } else {
                actionSelect = `<span style="font-size: 0.8rem; color: var(--text-muted); font-weight: 500;">POS Completed</span>`;
            }
            
            tr.innerHTML = `
                <td style="font-weight: 700;">#${order.id}</td>
                <td style="font-size: 0.85rem;">${dateStr}</td>
                <td>${clientDetails}</td>
                <td style="font-size: 0.85rem;">${addressDetails}</td>
                <td style="font-weight: bold; color: var(--teal);">${formatINR(order.total_amount)}<br><span style="font-size: 0.75rem; color: var(--text-muted);">Tracking: ${order.tracking_number}</span></td>
                <td>${statusBadge}</td>
                <td style="text-align: center;">${actionSelect}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch(err) {
        tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--danger); padding: 2rem;">Failed to load order rows: ${err.message}</td></tr>`;
    }
}

async function updateAdminOrderStatus(orderId, newStatus) {
    try {
        let response = await fetch(`/api/orders/${orderId}/status`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: newStatus })
        });
        response = await handleResponse(response);
        const data = await response.json();
        
        if (response.ok) {
            showToast(`Order #${orderId} status changed to ${newStatus}.`);
            loadAdminOrders();
        } else {
            showToast(data.error || "Failed to change order status.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}

// ==========================================================================
// TRADITIONAL DESIGN SYSTEM MODULE FUNCTIONS
// ==========================================================================

function getProductIcon(product) {
    const name = (product.name || '').toLowerCase();
    if (name.includes('headphone') || name.includes('audio')) return '🎧';
    if (name.includes('soundbar') || name.includes('speaker')) return '🔊';
    if (name.includes('book') || name.includes('novel')) return '📚';
    if (name.includes('pen')) return '✒️';
    if (name.includes('pencil')) return '✏️';
    if (name.includes('notebook') || name.includes('copy')) return '📔';
    if (name.includes('bookmark')) return '🔖';
    return '📦';
}

function renderUsualBasket() {
    const container = document.getElementById('usual-basket-items-container');
    if (!container) return;
    
    const usualItems = [
        { id: '1', name: 'A4 Register', defaultIcon: '📔', searchName: 'register' },
        { id: '2', name: 'Ink Pen', defaultIcon: '✒️', searchName: 'pen' },
        { id: '3', name: 'Leather Bookmark', defaultIcon: '🔖', searchName: 'bookmark' },
        { id: '4', name: 'Writing Notebook', defaultIcon: '📚', searchName: 'notebook' }
    ];
    
    container.innerHTML = '';
    
    usualItems.forEach(item => {
        let matchedProduct = state.products ? state.products.find(p => p.name.toLowerCase().includes(item.searchName)) : null;
        
        const productId = matchedProduct ? matchedProduct.id : item.id;
        const icon = matchedProduct ? getProductIcon(matchedProduct) : item.defaultIcon;
        const name = matchedProduct ? matchedProduct.name : item.name;
        
        const div = document.createElement('div');
        div.className = 'usual-basket-item';
        div.innerHTML = `
            <div style="display: flex; align-items: center; gap: 0.75rem;">
                <span class="usual-basket-icon-circle">${icon}</span>
                <span class="usual-basket-name">${name}</span>
            </div>
            <button class="usual-basket-add-btn" onclick="handleUsualBasketAdd('${productId}', '${icon}', event)">+</button>
        `;
        container.appendChild(div);
    });
}

function handleUsualBasketAdd(productId, icon, event) {
    const btn = event.target;
    const cartTrigger = document.querySelector('.cart-trigger-btn');
    
    queueFlyAnimation(icon, btn, cartTrigger);
    
    // Add to cart directly!
    addToCart(productId);
}

// Queue system for arcing fly animations
const flyQueue = [];
let flyProcessing = false;

function queueFlyAnimation(itemIcon, startEl, endEl) {
    flyQueue.push({ itemIcon, startEl, endEl });
    processFlyQueue();
}

function processFlyQueue() {
    if (flyProcessing || flyQueue.length === 0) return;
    flyProcessing = true;
    
    const { itemIcon, startEl, endEl } = flyQueue.shift();
    animateFlyToBasket(itemIcon, startEl, endEl);
    
    setTimeout(() => {
        flyProcessing = false;
        processFlyQueue();
    }, 120);
}

function animateFlyToBasket(itemIcon, startEl, endEl) {
    if (!startEl || !endEl) return;
    
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        incrementBasketBadge();
        return;
    }
    
    const startRect = startEl.getBoundingClientRect();
    const endRect = endEl.getBoundingClientRect();
    
    const clone = document.createElement('div');
    clone.className = 'basket-flyer-icon';
    clone.innerText = itemIcon;
    clone.style.position = 'fixed';
    clone.style.left = '0';
    clone.style.top = '0';
    clone.style.zIndex = '9999';
    clone.style.pointerEvents = 'none';
    
    document.body.appendChild(clone);
    
    const p0 = { x: startRect.left + startRect.width / 2, y: startRect.top + startRect.height / 2 };
    const p2 = { x: endRect.left + endRect.width / 2, y: endRect.top + endRect.height / 2 };
    
    // Elevated midpoint for curve arc path
    const p1 = {
        x: (p0.x + p2.x) / 2,
        y: Math.min(p0.y, p2.y) - 150
    };
    
    const duration = 650;
    const startTime = performance.now();
    
    function step(now) {
        const elapsed = now - startTime;
        const t = Math.min(elapsed / duration, 1);
        
        // Quadratic Bezier interpolation
        const x = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * p1.x + t * t * p2.x;
        const y = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * p1.y + t * t * p2.y;
        
        clone.style.transform = `translate(${x}px, ${y}px) scale(${1 - 0.4 * t})`;
        clone.style.opacity = (1 - t).toString();
        
        if (t < 1) {
            requestAnimationFrame(step);
        } else {
            clone.remove();
            incrementBasketBadge();
        }
    }
    requestAnimationFrame(step);
}

function incrementBasketBadge() {
    const badge = document.getElementById('cart-badge-count');
    if (!badge) return;
    
    badge.classList.remove('cart-badge-bounce');
    void badge.offsetWidth; // force reflow
    badge.classList.add('cart-badge-bounce');
}

// 2. LOYALTY LEDGER UTILITIES
function renderRewardsLedger() {
    const container = document.getElementById('rewards-ledger-container');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (!state.rewards || state.rewards.transactions.length === 0) {
        container.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 2rem;">No transaction ledger rows found.</div>`;
        return;
    }
    
    state.rewards.transactions.forEach((tx, idx) => {
        const row = document.createElement('div');
        row.className = 'store-ledger-row';
        
        const ptSign = tx.points >= 0 ? '+' : '';
        const ptClass = tx.points >= 0 ? 'plus' : 'minus';
        
        row.innerHTML = `
            <div class="store-ledger-left">
                <span class="store-ledger-date">${tx.date}</span>
                <span class="store-ledger-desc">${tx.description}</span>
            </div>
            <span class="store-ledger-points ${ptClass}">${ptSign}${tx.points} pts</span>
        `;
        
        container.appendChild(row);
        
        // Staggered slide in animation from right
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            row.style.opacity = '1';
        } else {
            setTimeout(() => {
                row.classList.add('new-transaction');
            }, idx * 100);
        }
    });
}

function animatePoints(targetValue, deltaVal = 0) {
    const pointsEl = document.getElementById('loyalty-points-value');
    if (!pointsEl) return;
    
    const startValue = parseInt(pointsEl.innerText) || 0;
    const diff = targetValue - startValue;
    
    if (deltaVal !== 0) {
        const deltaEl = document.getElementById('loyalty-points-delta');
        if (deltaEl) {
            deltaEl.innerText = (deltaVal > 0 ? '+' : '') + deltaVal + ' pts';
            deltaEl.style.transition = 'none';
            deltaEl.style.opacity = '1';
            deltaEl.style.transform = 'translateY(0)';
            deltaEl.style.color = deltaVal > 0 ? 'var(--teal)' : 'var(--vermilion)';
        }
    }
    
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || startValue === targetValue) {
        pointsEl.innerText = targetValue;
        setTimeout(() => {
            const deltaEl = document.getElementById('loyalty-points-delta');
            if (deltaEl) {
                deltaEl.style.opacity = '0';
            }
        }, 600);
        return;
    }
    
    const duration = 600;
    const startTime = performance.now();
    
    function update(now) {
        const elapsed = now - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const ease = progress * (2 - progress); // easeOutQuad
        
        const current = Math.round(startValue + diff * ease);
        pointsEl.innerText = current;
        
        if (progress < 1) {
            requestAnimationFrame(update);
        } else {
            pointsEl.innerText = targetValue;
            setTimeout(() => {
                const deltaEl = document.getElementById('loyalty-points-delta');
                if (deltaEl) {
                    deltaEl.style.transition = 'opacity 0.4s ease, transform 0.4s ease';
                    deltaEl.style.opacity = '0';
                    deltaEl.style.transform = 'translateY(-10px)';
                }
            }, 600);
        }
    }
    requestAnimationFrame(update);
}

function creditCheckoutLoyaltyPoints(totalAmount, trackingNumber) {
    const pts = Math.round(totalAmount * 0.1);
    const dateStr = new Date().toLocaleDateString('en-IN');
    
    if (!state.rewards) {
        state.rewards = {
            balance: 350,
            transactions: [
                { date: '10/07/2026', description: 'Counter signup bonus', points: 100 },
                { date: '10/07/2026', description: 'Counter loyalty transfer', points: 250 }
            ]
        };
    }
    
    const newTx = {
        date: dateStr,
        description: `Order checkout #${trackingNumber.slice(0, 8)}...`,
        points: pts
    };
    
    state.rewards.transactions.unshift(newTx);
    state.rewards.balance += pts;
    
    showToast(`Earned +${pts} Counter Points!`);
}

// ==========================================
// DYNAMIC ANNOUNCEMENT SYSTEM (Phase 6 Admin Publisher)
// ==========================================

async function loadAnnouncementsStorefront() {
    try {
        const response = await fetch('/api/announcements');
        const data = await response.json();
        if (response.ok) {
            const banner = document.getElementById('store-announcement-banner');
            const text = document.getElementById('store-announcement-text');
            if (banner && text) {
                text.innerText = `Stock: ${data.stock_status} | Offer: ${data.loyalty_offer} | Delivery: ${data.home_delivery}`;
                banner.style.display = 'flex';
            }
        }
    } catch(err) {
        console.error("Failed to load storefront announcements:", err);
    }
}

async function loadAnnouncementsIntoForm() {
    try {
        const response = await fetch('/api/announcements');
        const data = await response.json();
        if (response.ok) {
            document.getElementById('ann-stock-status').value = data.stock_status || '';
            document.getElementById('ann-loyalty-offer').value = data.loyalty_offer || '';
            document.getElementById('ann-home-delivery').value = data.home_delivery || '';
        }
    } catch(err) {
        console.error("Failed to load announcements into edit form:", err);
    }
}

async function handleAnnouncementSubmit(e) {
    e.preventDefault();
    const stock = document.getElementById('ann-stock-status').value.trim();
    const offer = document.getElementById('ann-loyalty-offer').value.trim();
    const delivery = document.getElementById('ann-home-delivery').value.trim();
    
    const submitBtn = e.target.querySelector('button[type="submit"]');
    const origText = submitBtn.innerText;
    submitBtn.disabled = true;
    submitBtn.innerText = 'Publishing...';
    
    try {
        const response = await fetch('/api/announcements', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                stock_status: stock,
                loyalty_offer: offer,
                home_delivery: delivery
            })
        });
        const data = await response.json();
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        
        if (response.ok) {
            showToast("Announcements published live successfully!", "success");
            loadAnnouncementsStorefront();
        } else {
            showToast(data.error || "Failed to publish announcements.", "error");
        }
    } catch(err) {
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        showToast("Connection failed: " + err.message, "error");
    }
}

// Call on boot
document.addEventListener("DOMContentLoaded", () => {
    loadAnnouncementsStorefront();
});
