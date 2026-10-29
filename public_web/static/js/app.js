/* static/js/app.js */

// Automatically attach Admin Authorization Bearer Token ONLY on Admin Pages (/admin)
const _nativeFetch = window.fetch;
window.fetch = function(url, options = {}) {
    try {
        const isAdminPage = window.location.pathname.startsWith('/admin');
        const adminToken = localStorage.getItem('adminToken');
        const customerToken = localStorage.getItem('firebase_id_token') || localStorage.getItem('customerToken');
        
        let tokenToAttach = null;
        if (isAdminPage && adminToken) {
            tokenToAttach = adminToken;
        } else if (!isAdminPage && customerToken) {
            tokenToAttach = customerToken;
        }

        if (tokenToAttach && typeof url === 'string' && url.startsWith('/api/')) {
            options = options || {};
            options.headers = options.headers || {};
            if (options.headers instanceof Headers) {
                if (!options.headers.has('Authorization')) {
                    options.headers.set('Authorization', `Bearer ${tokenToAttach}`);
                }
            } else if (Array.isArray(options.headers)) {
                options.headers.push(['Authorization', `Bearer ${tokenToAttach}`]);
            } else {
                if (!options.headers['Authorization'] && !options.headers['authorization']) {
                    options.headers['Authorization'] = `Bearer ${tokenToAttach}`;
                }
            }
        }
    } catch (_) {}
    return _nativeFetch(url, options);
};

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
        searchQuery: '',
        statusFilter: 'all'
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
document.addEventListener('DOMContentLoaded', () => {
    loadCustomerCartFromStorage();
    checkAuthStatus();
    
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
    const isAdminPage = window.location.pathname.startsWith('/admin');
    
    if (isAdminPage) {
        const token = localStorage.getItem('adminToken');
        if (token) {
            try {
                const res = await fetch('/api/auth/admin-verify-session', {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                if (res.ok) {
                    const data = await res.json();
                    state.user = data.user || { role: 'admin' };
                    return;
                }
            } catch (_) {}
        }
        if (window.location.pathname !== '/admin/login') {
            window.location.replace('/admin/login');
        }
        return;
    }

    // Customer page auth check
    const localUser = localStorage.getItem('customerUser') || localStorage.getItem('currentUser') || localStorage.getItem('user');
    const savedName = localStorage.getItem('saved_customer_name') || '';
    if (localUser) {
        try {
            const parsed = JSON.parse(localUser);
            if (parsed && (parsed.fullname || parsed.username || parsed.email || parsed.phone || parsed.uid)) {
                let resolvedName = (savedName && savedName !== 'Customer') ? savedName :
                                   (parsed.fullname && parsed.fullname !== 'Customer') ? parsed.fullname :
                                   (parsed.displayName && parsed.displayName !== 'Customer') ? parsed.displayName :
                                   (parsed.username && parsed.username !== 'Customer') ? parsed.username :
                                   (parsed.name && parsed.name !== 'Customer') ? parsed.name : '';
                const phoneStr = parsed.phone || parsed.email_or_phone || '';
                if (!resolvedName || resolvedName === 'Customer') {
                    if (phoneStr.includes('7268903804')) {
                        resolvedName = 'Rahul';
                    } else if (phoneStr.replace(/\D/g, '').length >= 10) {
                        resolvedName = `User (${phoneStr.replace(/\D/g, '').slice(-4)})`;
                    } else {
                        resolvedName = 'Rahul';
                    }
                }
                const userObj = {
                    id: parsed.uid || parsed.id,
                    uid: parsed.uid || parsed.id,
                    fullname: resolvedName,
                    displayName: resolvedName,
                    name: resolvedName,
                    phone: phoneStr,
                    email_or_phone: parsed.email || phoneStr || '',
                    address: parsed.address || localStorage.getItem('saved_shipping_address') || '',
                    role: 'customer'
                };
                loginSession(userObj);

                // Asynchronously verify with server to retrieve any updated profile
                const fToken = localStorage.getItem('firebase_id_token');
                if (fToken) {
                    fetch('/api/auth/status', {
                        headers: { 'Authorization': `Bearer ${fToken}` }
                    }).then(r => r.json()).then(data => {
                        if (data && data.user && data.user.fullname && data.user.fullname !== 'Customer') {
                            state.user.fullname = data.user.fullname;
                            state.user.displayName = data.user.fullname;
                            state.user.name = data.user.fullname;
                            if (data.user.phone) state.user.phone = data.user.phone;
                            if (data.user.address) state.user.address = data.user.address;
                            localStorage.setItem('saved_customer_name', data.user.fullname);
                            localStorage.setItem('currentUser', JSON.stringify(state.user));
                            routeUserLayout(state.user);
                        }
                    }).catch(() => {});
                }
                return;
            }
        } catch (_) {}
    }
    state.user = null;
    routeUserLayout(null);
}

function routeUserLayout(user) {
    const headerSignInBtn = document.getElementById('btn-store-signin');
    const headerProfileWidget = document.getElementById('customer-profile-widget');
    const adminDashboardLink = document.getElementById('btn-admin-dashboard-link');
    if (adminDashboardLink) adminDashboardLink.style.display = 'none';

    if (!user) {
        if (headerSignInBtn) headerSignInBtn.style.display = 'block';
        if (headerProfileWidget) headerProfileWidget.style.display = 'none';
        initStorefront();
    } else {
        // Logged in as customer on storefront
        if (headerSignInBtn) headerSignInBtn.style.display = 'none';
        if (headerProfileWidget) headerProfileWidget.style.display = 'flex';
        
        let realName = (user.fullname && user.fullname !== 'Customer') ? user.fullname :
                       (user.displayName && user.displayName !== 'Customer') ? user.displayName :
                       (user.name && user.name !== 'Customer') ? user.name :
                       (localStorage.getItem('saved_customer_name') || '');
        const phone = user.phone || user.email_or_phone || '';
        if (!realName || realName === 'Customer') {
            if (phone.includes('7268903804')) {
                realName = 'Rahul';
            } else if (phone.replace(/\D/g, '').length >= 10) {
                realName = `User (${phone.replace(/\D/g, '').slice(-4)})`;
            } else {
                realName = 'Rahul';
            }
        }
        
        const avatar = document.getElementById('customer-avatar');
        if (avatar) avatar.innerText = realName.charAt(0).toUpperCase();
        const dispName = document.getElementById('customer-display-name');
        if (dispName) dispName.innerText = realName;
        
        initStorefront();
        
        const profFullname = document.getElementById('profile-user-fullname');
        if (profFullname) profFullname.innerText = realName;
        const profIdentifier = document.getElementById('profile-user-identifier');
        if (profIdentifier) profIdentifier.innerText = phone || user.email || '-';
        const profRole = document.getElementById('profile-user-role');
        if (profRole) profRole.innerText = 'Verified Customer';

        // Pre-fill profile edit form if present
        const editName = document.getElementById('profile-edit-name');
        if (editName && !editName.value) editName.value = realName;
        const editPhone = document.getElementById('profile-edit-phone');
        if (editPhone && !editPhone.value) {
            const cleanP = phone.replace(/\D/g, '');
            if (cleanP.length >= 10) editPhone.value = cleanP.slice(-10);
        }
        const editAddr = document.getElementById('profile-edit-address');
        if (editAddr && !editAddr.value) {
            editAddr.value = user.address || localStorage.getItem('saved_shipping_address') || '';
        }
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
    localStorage.removeItem('currentUser');
    localStorage.removeItem('customerUser');
    localStorage.removeItem('customerToken');
    localStorage.removeItem('firebase_id_token');
    localStorage.removeItem('user');
    state.user = null;
    routeUserLayout(null);
    showToast("Logged out successfully.");
    setTimeout(() => {
        window.location.href = '/store';
    }, 400);
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

// Switch between tabs in Admin Panel - Robust Unified Implementation
function switchTab(tabName) {
    if (!tabName) tabName = 'dashboard';
    
    // Auto close mobile drawer if open
    if (window.innerWidth <= 992) {
        const sb = document.querySelector('.admin-sidebar');
        if (sb) sb.classList.remove('open');
    }
    
    // Update active classes on buttons safely
    document.querySelectorAll('.admin-nav-item, .tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    
    const activeBtn = document.getElementById(`sidebar-tab-${tabName}`) ||
                      document.getElementById(`btn-tab-${tabName}`) ||
                      document.querySelector(`[data-tab="${tabName}"]`);
    if (activeBtn) activeBtn.classList.add('active');
    
    // Activate target tab panel
    const activeContent = document.getElementById(`tab-${tabName}`);
    if (activeContent) {
        activeContent.classList.add('active');
    }
    
    // Update headers and metric row visibility
    const heading = document.getElementById('admin-view-heading');
    const subheading = document.getElementById('admin-view-subheading');
    const metricsRow = document.getElementById('admin-metrics-row');
    
    const titles = {
        dashboard: { h: "Dashboard Overview", sub: "Analyze active sales metrics and counter inventory", metrics: true },
        pos: { h: "Cashier POS Desk", sub: "Process retail billing bills for counter buyers", metrics: false },
        inventory: { h: "Inventory Catalog", sub: "Manage products catalog registers and hierarchy trees", metrics: false },
        orders: { h: "Fulfillment Manager", sub: "Track and update customer checkout deliveries", metrics: false },
        announcements: { h: "Announcements Publisher", sub: "Display announcements at the top of the storefront", metrics: false },
        coupons: { h: "Coupons & Discounts Manager", sub: "Create and manage customer discount promo codes", metrics: false },
        delivery: { h: "Delivery & Serviceable PIN Codes", sub: "Control deliverable area PIN codes and shipping fee rules", metrics: false },
        vendors: { h: "Vendors & Marketplace Management", sub: "Review vendor applications, approve product listings, and configure commissions", metrics: false },
        firebase: { h: "Firebase Cloud Console", sub: "Monitor Cloud Firestore NoSQL synchronization and Identity Platform", metrics: false }
    };
    
    if (titles[tabName]) {
        if (heading) heading.innerText = titles[tabName].h;
        if (subheading) subheading.innerText = titles[tabName].sub;
        if (metricsRow) metricsRow.style.display = titles[tabName].metrics ? 'grid' : 'none';
    }
    
    // Safely execute tab data loaders with try/catch to ensure NO tab switch ever hangs
    try {
        if (tabName === 'dashboard') {
            loadDashboardMetrics();
            if (typeof loadAdminDashboardLowStock === 'function') loadAdminDashboardLowStock();
        } else if (tabName === 'pos') {
            if (typeof renderPOSCart === 'function') renderPOSCart();
            const posInput = document.getElementById('pos-search-input');
            if (posInput) setTimeout(() => posInput.focus(), 80);
        } else if (tabName === 'inventory') {
            loadCatalog();
            if (typeof loadAdminCategoryDetails === 'function') loadAdminCategoryDetails();
        } else if (tabName === 'orders') {
            loadAdminOrders();
        } else if (tabName === 'announcements') {
            loadAnnouncementsIntoForm();
        } else if (tabName === 'coupons') {
            loadAdminCoupons();
        } else if (tabName === 'delivery') {
            loadAdminDeliverySettings();
        } else if (tabName === 'vendors') {
            loadAdminVendors();
            loadAdminPendingProducts();
        } else if (tabName === 'firebase') {
            if (typeof loadFirebaseStatus === 'function') loadFirebaseStatus();
        }
    } catch(err) {
        console.error(`[switchTab] Notice for tab ${tabName}:`, err);
    }
}
window.switchTab = switchTab;

// ==========================================
// ADMIN CATALOG OPERATIONS
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
        const admToken = localStorage.getItem('adminToken') || localStorage.getItem('admin_token');
        const admHeaders = admToken ? { 'Authorization': `Bearer ${admToken}` } : {};
        const res = await fetch('/api/products/counts', { headers: admHeaders });
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
        const admToken = localStorage.getItem('adminToken') || localStorage.getItem('admin_token');
        const admHeaders = admToken ? { 'Authorization': `Bearer ${admToken}` } : {};
        let response = await fetch(url, { headers: admHeaders });
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
                document.getElementById('m-features').value = Array.isArray(p.features) ? p.features.join('\n') : (p.features || '');
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
    const features = (document.getElementById('m-features')?.value || '').split('\n').map(s => s.trim()).filter(Boolean);
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

    if (!confirm(`Are you sure you want to delete "${pName}"?\n\nIf this product has been ordered by customers, it will be safely archived instead of deleted to protect customer receipts.`)) {
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
window.clearCart = clearCart;

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
    
    const paymentMethodBadge = receipt.payment_method ? `
        <div style="margin-top: 8px; font-size: 0.85rem; padding: 6px 10px; background: rgba(255,255,255,0.05); border-radius: 6px;">
            <div><strong>Payment:</strong> ${receipt.payment_method}</div>
            ${receipt.customer_name ? `<div><strong>Customer:</strong> ${receipt.customer_name} ${receipt.customer_phone ? `(📱 ${receipt.customer_phone})` : ''}</div>` : ''}
            ${receipt.shipping_address ? `<div style="font-size: 0.8rem; color: #94a3b8; margin-top: 2px;"><strong>Address:</strong> ${receipt.shipping_address}</div>` : ''}
        </div>
    ` : '';

    const codCallout = (receipt.payment_method && receipt.payment_method.includes('Cash on Delivery')) ? `
        <div style="background: rgba(229, 171, 55, 0.12); border: 1px dashed #e5ab37; color: #e5ab37; padding: 10px; border-radius: 6px; font-weight: 700; font-size: 0.88rem; margin: 12px 0; text-align: center;">
            💵 Cash on Delivery: Please pay ${formatINR(receipt.total_amount)} in cash or UPI to delivery person upon arrival.
        </div>
    ` : '';
    
    container.innerHTML = `
        <div class="receipt-wrapper">
            <div class="receipt-header">
                <div class="receipt-store-name">SAMAUR MART</div>
                <div class="receipt-meta">
                    <div>Tracking ID: ${receipt.tracking_number}</div>
                    <div>Date: ${dateFormatted}</div>
                </div>
                ${paymentMethodBadge}
            </div>
            ${codCallout}
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
                    <span>GST Tax (${receipt.tax_rate || 18}%)</span>
                    <span>${formatINR(receipt.tax_amount || 0)}</span>
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
    const rm = document.getElementById('receipt-modal');
    if (rm) rm.classList.remove('active');
}
window.closeReceiptModal = closeReceiptModal;

function printReceipt() {
    window.print();
}
window.printReceipt = printReceipt;

function handlePOSCheckout(e) {
    if (e && e.preventDefault) e.preventDefault();
    completeCheckout();
}
window.handlePOSCheckout = handlePOSCheckout;

// ==========================================
// CUSTOMER STOREFRONT & CATALOGS (RETAIL)
// ==========================================

async function initStorefront() {
    state.storefront.currentPage = 1;
    state.storefront.hasMore = true;
    state.products = [];
    
    const grid = document.getElementById('storefront-products-grid');
    if (grid && !grid.children.length) {
        grid.innerHTML = `
            <div style="grid-column: 1/-1; text-align: center; padding: 3rem 1rem; color: var(--gold-line);">
                <div style="font-size: 1.5rem; margin-bottom: 0.5rem;">🏬</div>
                <div style="font-weight: 600; font-family: var(--font-display); letter-spacing: 0.03em;">Loading catalog essentials...</div>
            </div>`;
    }
    
    // Fetch categories, products, and announcements simultaneously in parallel!
    await Promise.allSettled([
        loadStoreCategories(),
        fetchStorefrontProducts(true),
        loadAnnouncementsStorefront()
    ]);
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
            
            const imageSrc = prod.image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80';
            
            const origPrice = parseFloat(prod.original_price || prod.mrp || 0);
            const sellPrice = parseFloat(prod.selling_price || prod.price || 0);
            const hasDiscount = origPrice > sellPrice;
            const discountPct = hasDiscount ? Math.round(((origPrice - sellPrice) / origPrice) * 100) : 0;
            
            card.innerHTML = `
                <div class="product-card-img-wrapper" style="position: relative;">
                    <img src="${imageSrc}" alt="${prod.name}" loading="lazy" class="product-card-img" onerror="this.onerror=null;this.src='https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80'">
                    ${hasDiscount ? `<span style="position: absolute; top: 8px; left: 8px; background: #10b981; color: #fff; font-size: 0.7rem; font-weight: 800; padding: 2px 6px; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.2);">${discountPct}% OFF</span>` : ''}
                </div>
                <div class="product-card-body">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                        <span class="product-card-category">${prod.category || 'General'}</span>
                        <span style="font-size: 0.72rem; color: #b8892b; font-weight: 600; max-width: 120px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="Sold by ${prod.vendor_name || 'Rama Store'}">🏷️ ${prod.vendor_name || 'Rama Store'}</span>
                    </div>
                    <h3 class="product-card-title">${prod.name}</h3>
                    <div class="product-card-footer" style="display: flex; justify-content: space-between; align-items: center;">
                        <div style="display: flex; flex-direction: column;">
                            <span class="product-card-price" style="font-weight: 800; color: var(--teal);">${formatINR(sellPrice)}</span>
                            ${hasDiscount ? `<span style="font-size: 0.75rem; color: #94a3b8; text-decoration: line-through;">${formatINR(origPrice)}</span>` : ''}
                        </div>
                        <button class="btn-add-to-cart" onclick="addToCart('${prod.id}')" title="Add to Cart">🛒 Add</button>
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
        const localData = localStorage.getItem('samaur_mart_client_cart') || localStorage.getItem('rama_store_client_cart');
        state.cart = localData ? JSON.parse(localData) : [];
        updateCustomerCartBadgeUI();
    } catch(e) {
        state.cart = [];
    }
}

function saveCustomerCartToStorage() {
    localStorage.setItem('samaur_mart_client_cart', JSON.stringify(state.cart));
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
    let targetProduct = state.products ? state.products.find(p => String(p.id) === String(productId)) : null;
    
    if (!targetProduct) {
        try {
            const res = await fetch(`/api/products/search?q=${encodeURIComponent(productId)}`);
            const items = await res.json();
            if (Array.isArray(items)) {
                targetProduct = items.find(i => String(i.id) === String(productId));
            }
        } catch(e) {}
    }
    
    if (!targetProduct) {
        try {
            const response = await fetch(`/api/store/products?search=${encodeURIComponent(productId)}`);
            const data = await response.json();
            if (data && Array.isArray(data.products)) {
                targetProduct = data.products.find(p => String(p.id) === String(productId));
            }
        } catch(e) {}
    }
    
    if (!targetProduct) {
        showToast("Product details not available.", "error");
        return;
    }
    
    const existing = state.cart.find(item => String(item.product_id) === String(targetProduct.id));
    if (existing) {
        if (existing.quantity + 1 > (targetProduct.stock || 999)) {
            showToast(`Exceeds available store stock limit.`, "error");
            return;
        }
        existing.quantity += 1;
    } else {
        state.cart.push({
            product_id: targetProduct.id,
            sku: targetProduct.sku || ('SKU-' + targetProduct.id),
            name: targetProduct.name,
            selling_price: parseFloat(targetProduct.selling_price || targetProduct.price || 0),
            image_url: targetProduct.image_url,
            quantity: 1,
            stock: targetProduct.stock || 999
        });
    }
    
    saveCustomerCartToStorage();
    renderCustomerCart();
    showToast(`Added '${targetProduct.name}' to cart!`);
}

function removeFromCart(productId) {
    state.cart = state.cart.filter(item => String(item.product_id) !== String(productId));
    saveCustomerCartToStorage();
    renderCustomerCart();
    showToast("Item removed from cart.");
}

function updateQuantity(productId, delta) {
    const item = state.cart.find(i => String(i.product_id) === String(productId));
    if (!item) return;
    
    const newQty = item.quantity + delta;
    if (newQty < 1) {
        removeFromCart(productId);
        return;
    }
    
    if (newQty > (item.stock || 999)) {
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
    
    if (!list) return;
    list.innerHTML = '';
    
    if (state.cart.length === 0) {
        if (emptyState) emptyState.style.display = 'block';
        if (list) list.style.display = 'none';
        if (footer) footer.style.display = 'none';
        updateCartBadgeCount();
        return;
    }
    
    if (emptyState) emptyState.style.display = 'none';
    if (list) list.style.display = 'flex';
    if (footer) footer.style.display = 'block';
    
    let subtotal = 0.0;
    
    state.cart.forEach(item => {
        const itemTotal = item.selling_price * item.quantity;
        subtotal += itemTotal;
        
        const div = document.createElement('div');
        div.className = 'drawer-cart-item';
        
        const imgUrl = item.image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80';
        
        div.innerHTML = `
            <img src="${imgUrl}" alt="${item.name}" class="drawer-item-img">
            <div class="drawer-item-info">
                <div class="drawer-item-title">${item.name}</div>
                <div class="drawer-item-sku">SKU: ${item.sku}</div>
                <div class="drawer-item-price">${formatINR(item.selling_price)}</div>
                <div class="drawer-item-actions">
                    <div class="drawer-item-qty">
                        <button class="btn btn-secondary btn-icon" onclick="changeCustomerCartQty('${item.product_id}', -1)">-</button>
                        <input type="number" value="${item.quantity}" readonly>
                        <button class="btn btn-secondary btn-icon" onclick="changeCustomerCartQty('${item.product_id}', 1)">+</button>
                    </div>
                    <button class="btn btn-danger btn-icon" onclick="removeCustomerCartItem('${item.product_id}')">🗑️</button>
                </div>
            </div>
        `;
        list.appendChild(div);
    });
    
    updateCartBadgeCount();
    
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
    if (!sheet) return;
    if (open) {
        sheet.classList.add('active');
        populateCheckoutReviewTotals();
        
        // Auto-fill user contact info if logged in or saved in storage
        const savedName = localStorage.getItem('saved_customer_name') || 
                          (state.user && state.user.fullname !== 'Customer' ? state.user.fullname : '') || 
                          (state.user && state.user.displayName !== 'Customer' ? state.user.displayName : '');
        const nameInput = document.getElementById('checkout-full-name');
        if (nameInput && !nameInput.value && savedName) {
            nameInput.value = savedName;
        }
        const phoneInput = document.getElementById('checkout-phone-number');
        if (phoneInput && !phoneInput.value) {
            const p = (state.user?.phone || state.user?.email_or_phone || localStorage.getItem('saved_customer_phone') || '').replace(/\D/g, '');
            if (p.length >= 10) phoneInput.value = p.slice(-10);
        }
    } else {
        sheet.classList.remove('active');
    }
}

function handlePaymentMethodChange(method) {
    const cardCod = document.getElementById('card-method-cod');
    const cardOnline = document.getElementById('card-method-online');
    const submitBtn = document.getElementById('btn-checkout-submit');
    
    if (method === 'COD') {
        if (cardCod) {
            cardCod.style.borderColor = 'var(--gold-accent, #e5ab37)';
            cardCod.style.background = 'rgba(229, 171, 55, 0.08)';
        }
        if (cardOnline) {
            cardOnline.style.borderColor = '#334155';
            cardOnline.style.background = '#0f172a';
        }
        if (submitBtn) {
            submitBtn.innerHTML = '<span>💵</span> Confirm & Place Order (Cash on Delivery)';
        }
    } else {
        if (cardOnline) {
            cardOnline.style.borderColor = 'var(--gold-accent, #e5ab37)';
            cardOnline.style.background = 'rgba(229, 171, 55, 0.08)';
        }
        if (cardCod) {
            cardCod.style.borderColor = '#334155';
            cardCod.style.background = '#0f172a';
        }
        if (submitBtn) {
            submitBtn.innerHTML = '<span>💳</span> Proceed to Card Payment';
        }
    }
}
window.handlePaymentMethodChange = handlePaymentMethodChange;

function openCheckoutDrawer() {
    if (!state.cart || state.cart.length === 0) {
        showToast("Your cart is empty.", "error");
        return;
    }
    toggleCartDrawer(false);
    toggleCheckoutDrawer(true);
}

let pincodeTimer = null;
function handlePincodeCheck(pincode) {
    const badge = document.getElementById('pincode-service-badge');
    const clean = String(pincode || '').trim().replace(/\D/g, '');
    if (clean.length !== 6) {
        if (badge) badge.innerHTML = '';
        return;
    }
    
    if (pincodeTimer) clearTimeout(pincodeTimer);
    if (badge) badge.innerHTML = `<span style="color: #94a3b8;">Checking delivery serviceability...</span>`;
    
    pincodeTimer = setTimeout(async () => {
        try {
            const res = await fetch('/api/delivery/check-pincode', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ pincode: clean })
            });
            const data = await res.json();
            if (res.ok && data.serviceable) {
                if (badge) {
                    badge.innerHTML = `<span style="color: #10b981; font-weight: 700;">✅ Serviceable • Est. ${data.estimated_days || '1-2 Days'}</span>`;
                }
            } else {
                if (badge) {
                    badge.innerHTML = `<span style="color: #ef4444; font-weight: 700;">❌ Delivery not available for PIN ${clean}</span>`;
                }
            }
        } catch (_) {
            if (badge) badge.innerHTML = `<span style="color: #10b981; font-weight: 700;">✅ Serviceable</span>`;
        }
    }, 400);
}
window.handlePincodeCheck = handlePincodeCheck;

async function applyCheckoutCoupon() {
    const input = document.getElementById('checkout-coupon-code');
    const statusEl = document.getElementById('checkout-coupon-status');
    const code = (input?.value || '').trim().toUpperCase();
    if (!code) {
        showToast("Please enter a coupon code.", "error");
        return;
    }
    
    let subtotal = 0;
    state.cart.forEach(i => subtotal += i.selling_price * i.quantity);
    
    try {
        const res = await fetch('/api/coupons/apply', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ code: code, subtotal: subtotal })
        });
        const data = await res.json();
        if (res.ok && data.success) {
            state.checkoutCoupon = data;
            populateCheckoutReviewTotals();
            if (statusEl) {
                statusEl.innerHTML = `<span style="color: #10b981; font-weight: 700;">${data.message}</span>`;
            }
            showToast(data.message);
        } else {
            state.checkoutCoupon = null;
            populateCheckoutReviewTotals();
            if (statusEl) {
                statusEl.innerHTML = `<span style="color: #ef4444;">❌ ${data.error || 'Invalid coupon'}</span>`;
            }
            showToast(data.error || "Coupon could not be applied.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}
window.applyCheckoutCoupon = applyCheckoutCoupon;

function populateCheckoutReviewTotals() {
    let subtotal = 0.0;
    state.cart.forEach(item => {
        subtotal += item.selling_price * item.quantity;
    });
    
    let discount = 0;
    if (state.checkoutCoupon) {
        if (state.checkoutCoupon.type === 'percent') {
            discount = Math.round((subtotal * (state.checkoutCoupon.value / 100)) * 100) / 100;
            if (state.checkoutCoupon.max_discount && discount > state.checkoutCoupon.max_discount) {
                discount = state.checkoutCoupon.max_discount;
            }
        } else {
            discount = Math.min(subtotal, state.checkoutCoupon.value || state.checkoutCoupon.discount_amount || 0);
        }
    }
    
    const discountedSubtotal = Math.max(0, subtotal - discount);
    const shipping = discountedSubtotal >= 500 ? 0 : (discountedSubtotal > 0 ? 49 : 0);
    const total = discountedSubtotal + shipping;
    
    const subEl = document.getElementById('checkout-review-subtotal');
    if (subEl) subEl.innerText = formatINR(subtotal);
    
    const discRow = document.getElementById('checkout-review-discount-row');
    const discEl = document.getElementById('checkout-review-discount');
    if (discRow && discEl) {
        if (discount > 0) {
            discRow.style.display = 'flex';
            discEl.innerText = `-${formatINR(discount)}`;
        } else {
            discRow.style.display = 'none';
        }
    }
    
    const shipEl = document.getElementById('checkout-review-shipping');
    if (shipEl) {
        shipEl.innerText = shipping === 0 ? 'FREE' : formatINR(shipping);
        shipEl.style.color = shipping === 0 ? '#10b981' : '#f8fafc';
    }
    
    const totEl = document.getElementById('checkout-review-total');
    if (totEl) totEl.innerText = formatINR(total);
}

async function handleCustomerCheckoutSubmit(e) {
    if (e && e.preventDefault) e.preventDefault();
    
    // Structured mandatory address validation
    const fullName = (document.getElementById('checkout-full-name')?.value || '').trim();
    const phone = (document.getElementById('checkout-phone-number')?.value || '').trim().replace(/\D/g, '');
    const pincode = (document.getElementById('checkout-pincode')?.value || '').trim().replace(/\D/g, '');
    const city = (document.getElementById('checkout-city')?.value || '').trim();
    const house = (document.getElementById('checkout-house')?.value || '').trim();
    const street = (document.getElementById('checkout-street')?.value || '').trim();
    const landmark = (document.getElementById('checkout-landmark')?.value || '').trim();
    const stateName = (document.getElementById('checkout-state')?.value || 'Uttar Pradesh').trim();
    
    if (!fullName) {
        showToast("Full Name is mandatory for delivery.", "error");
        document.getElementById('checkout-full-name')?.focus();
        return;
    }
    if (phone.length !== 10) {
        showToast("Please enter a valid 10-digit mobile number.", "error");
        document.getElementById('checkout-phone-number')?.focus();
        return;
    }
    if (pincode.length !== 6) {
        showToast("Please enter a valid 6-digit PIN code.", "error");
        document.getElementById('checkout-pincode')?.focus();
        return;
    }
    if (!house) {
        showToast("Flat, House number / Building is mandatory.", "error");
        document.getElementById('checkout-house')?.focus();
        return;
    }
    if (!street) {
        showToast("Area, Street or Sector is mandatory.", "error");
        document.getElementById('checkout-street')?.focus();
        return;
    }
    if (!city) {
        showToast("Town / City is mandatory.", "error");
        document.getElementById('checkout-city')?.focus();
        return;
    }

    // Auto-create or update local session with real customer name
    if (!state.user) {
        state.user = {
            uid: 'cust_' + phone,
            fullname: fullName,
            displayName: fullName,
            name: fullName,
            phone: phone,
            address: formattedAddress,
            role: 'customer'
        };
    } else {
        state.user.fullname = fullName;
        state.user.displayName = fullName;
        state.user.name = fullName;
        if (phone) state.user.phone = phone;
        state.user.address = formattedAddress;
    }
    localStorage.setItem('currentUser', JSON.stringify(state.user));
    localStorage.setItem('customerUser', JSON.stringify(state.user));
    localStorage.setItem('saved_customer_name', fullName);
    localStorage.setItem('saved_customer_phone', phone);
    localStorage.setItem('saved_shipping_address', formattedAddress);
    routeUserLayout(state.user);

    const formattedAddress = `${house}, ${street}${landmark ? ', Landmark: ' + landmark : ''}, ${city}, ${stateName} - ${pincode}`;
    const paymentMethod = document.querySelector('input[name="checkout-payment-method"]:checked')?.value || 'COD';
    
    const checkoutCart = state.cart.map(item => ({
        id: item.product_id,
        product_id: item.product_id,
        name: item.name,
        selling_price: item.selling_price,
        price: item.selling_price,
        quantity: item.quantity
    }));
    
    const submitBtn = document.getElementById('btn-checkout-submit');
    const originalBtnText = submitBtn ? submitBtn.innerHTML : '';
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span>⏳</span> Placing Order...';
    }
    
    try {
        let response = await fetch('/api/checkout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                cart: checkoutCart,
                shipping_address: formattedAddress,
                payment_method: paymentMethod,
                user_name: fullName,
                user_phone: phone,
                user_email: state.user.email || '',
                coupon_code: state.checkoutCoupon?.code || ''
            })
        });
        
        response = await handleResponse(response);
        const data = await response.json();
        
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = originalBtnText;
        }
        
        if (!response.ok) {
            showToast(data.error || "Order placement failed.", "error");
            return;
        }
        
        const session = data.session || data;
        state.storefront.currentSession = session;
        toggleCheckoutDrawer(false);
        state.checkoutCoupon = null;
        
        if (paymentMethod === 'COD') {
            // Cash on delivery: Order confirmed immediately!
            state.cart = [];
            saveCustomerCartToStorage();
            renderCustomerCart();
            
            showToast("🎉 Order confirmed via Cash on Delivery!");
            
            // Render confirmation receipt modal
            renderPrintableReceipt({
                id: session.order_id,
                order_id: session.order_id,
                tracking_number: session.tracking_number,
                total_amount: session.total_amount || session.total || 0,
                subtotal: session.subtotal || session.total_amount || 0,
                tax_rate: 0,
                tax_amount: 0,
                payment_method: 'Cash on Delivery (COD)',
                payment_status: 'PENDING (Pay at Doorstep)',
                customer_name: fullName,
                customer_phone: phone,
                shipping_address: formattedAddress,
                sale_date: new Date().toISOString(),
                items: checkoutCart.map(i => ({
                    name: i.name,
                    quantity: i.quantity,
                    price: i.selling_price,
                    total: i.selling_price * i.quantity
                }))
            });
            
            creditCheckoutLoyaltyPoints(session.total_amount, session.tracking_number);
        } else {
            // Online Card payment modal
            openPaymentModal(session.total_amount || session.total || 0);
        }
    } catch(err) {
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = originalBtnText;
        }
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
    const adminPortal = document.getElementById('admin-portal-view');
    if (adminPortal) adminPortal.style.display = 'none';
    const storefront = document.getElementById('customer-storefront-view');
    if (storefront) storefront.style.display = 'flex';
    
    const navItems = document.querySelectorAll('.mobile-nav-item');
    if (tab === 'home') {
        state.activeView = 'Storefront';
        const homeTab = document.getElementById('store-tab-home');
        if (homeTab) homeTab.classList.add('active');
        if (navItems[0]) navItems[0].classList.add('active');
    } else if (tab === 'profile') {
        if (!state.user) {
            showToast("Please sign in to view your profile.", "error");
            openLoginOverlay();
            return;
        }
        state.activeView = 'Profile';
        const profileTab = document.getElementById('store-tab-profile');
        if (profileTab) profileTab.classList.add('active');
        if (navItems[4]) navItems[4].classList.add('active');

        // Pre-fill profile fields
        const editName = document.getElementById('profile-edit-name');
        if (editName) editName.value = state.user.fullname || state.user.displayName || localStorage.getItem('saved_customer_name') || '';
        const editPhone = document.getElementById('profile-edit-phone');
        if (editPhone) {
            const p = (state.user.phone || state.user.email_or_phone || localStorage.getItem('saved_customer_phone') || '').replace(/\D/g, '');
            if (p.length >= 10) editPhone.value = p.slice(-10);
        }
        const editAddr = document.getElementById('profile-edit-address');
        if (editAddr) editAddr.value = state.user.address || localStorage.getItem('saved_shipping_address') || '';

        loadCustomerOrdersHistory();
    } else if (tab === 'rewards') {
        if (!state.user) {
            showToast("Please sign in to view your rewards.", "error");
            openLoginOverlay();
            return;
        }
        state.activeView = 'Rewards';
        const rewardsTab = document.getElementById('store-tab-rewards');
        if (rewardsTab) rewardsTab.classList.add('active');
        if (navItems[3]) navItems[3].classList.add('active');
        renderRewardsLedger();
        animatePoints(state.rewards.balance);
    }
}

async function handleCustomerProfileSave(event) {
    if (event && event.preventDefault) event.preventDefault();
    const name = (document.getElementById('profile-edit-name')?.value || '').trim();
    const phone = (document.getElementById('profile-edit-phone')?.value || '').trim().replace(/\D/g, '');
    const address = (document.getElementById('profile-edit-address')?.value || '').trim();

    if (!name) {
        showToast("Full Name is required.", "error");
        return;
    }
    if (phone && phone.length !== 10) {
        showToast("Please enter a valid 10-digit mobile number.", "error");
        return;
    }

    if (!state.user) {
        state.user = { uid: 'cust_' + (phone || Date.now()), role: 'customer' };
    }
    state.user.fullname = name;
    state.user.displayName = name;
    state.user.name = name;
    if (phone) state.user.phone = phone;
    if (address) state.user.address = address;

    localStorage.setItem('currentUser', JSON.stringify(state.user));
    localStorage.setItem('customerUser', JSON.stringify(state.user));
    localStorage.setItem('saved_customer_name', name);
    if (phone) localStorage.setItem('saved_customer_phone', phone);
    if (address) localStorage.setItem('saved_shipping_address', address);

    routeUserLayout(state.user);

    // Sync to backend Firestore profile
    try {
        const token = localStorage.getItem('firebase_id_token');
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = `Bearer ${token}`;
        await fetch('/api/user/profile', {
            method: 'POST',
            headers: headers,
            body: JSON.stringify({
                fullname: name,
                displayName: name,
                phone: phone,
                address: address
            })
        });
    } catch (_) {}

    showToast(`Profile details saved! Welcome, ${name}.`, "success");
}
window.handleCustomerProfileSave = handleCustomerProfileSave;

async function loadCustomerOrdersHistory() {
    const container = document.getElementById('customer-orders-list-wrapper');
    container.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 2rem;">Loading your order history...</div>`;
    
    try {
        const phone = (state.user?.phone || state.user?.email_or_phone || localStorage.getItem('saved_customer_phone') || '').replace(/\D/g, '');
        const historyUrl = phone ? `/api/orders/history?phone=${phone}` : '/api/orders/history';
        let response = await fetch(historyUrl);
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
    if (!tbody) return;
    tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 2rem;">Loading orders manager...</td></tr>`;
    
    try {
        let response = await fetch('/api/orders/admin/list');
        response = await handleResponse(response);
        const orders = await response.json();
        
        tbody.innerHTML = '';
        
        if (!orders || orders.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="7" style="text-align: center; color: #94a3b8; padding: 4rem 1.5rem;">
                        <div style="font-size: 3rem; margin-bottom: 0.75rem;">📭</div>
                        <div style="font-weight: 800; font-size: 1.2rem; color: #f1f5f9; margin-bottom: 0.4rem;">No Customer Orders Placed Yet</div>
                        <p style="font-size: 0.88rem; color: #94a3b8; max-width: 480px; margin: 0 auto; line-height: 1.5;">
                            Your store is 100% active and live. When customers place real checkout orders online or at the POS counter, authentic delivery records with verified addresses and phone numbers will appear here automatically.
                        </p>
                    </td>
                </tr>
            `;
            return;
        }
        
        orders.forEach(order => {
            const tr = document.createElement('tr');
            const dateStr = order.created_at ? new Date(order.created_at).toLocaleString('en-IN') : 'Recent';
            
            let statusBadge = '';
            const status = order.status || order.order_status || 'Pending';
            
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
            
            let customerName = (order.customer_name && order.customer_name !== 'Customer' && !order.customer_name.startsWith('pro_shopper_') && !order.customer_name.startsWith('paynow_user_') && !order.customer_name.startsWith('cancel_user_')) ? order.customer_name :
                               (order.username && order.username !== 'Customer') ? order.username : '';

            if (!customerName || customerName === 'Customer') {
                if (order.customer_phone && order.customer_phone.includes('7268903804')) {
                    customerName = 'Rahul';
                } else if (order.customer_phone && order.customer_phone.replace(/\D/g, '').length >= 10) {
                    customerName = `Customer (${order.customer_phone.replace(/\D/g, '').slice(-4)})`;
                } else if (order.customer_id === 'counter_pos') {
                    customerName = 'In-Store Walk-in';
                } else {
                    customerName = 'Verified Customer';
                }
            }

            let clientDetails = `<div style="font-weight: 800; color: #f8fafc; font-size: 0.95rem; display: flex; align-items: center; gap: 4px;"><span>👤</span> ${customerName}</div>`;
            if (order.customer_phone) {
                clientDetails += `<div style="font-size: 0.82rem; margin-top: 4px;"><a href="tel:${order.customer_phone}" style="color: #38bdf8; text-decoration: none; font-weight: 700; display: inline-flex; align-items: center; gap: 4px;"><span>📱</span> ${order.customer_phone}</a></div>`;
            }
            if (order.customer_email && !order.customer_email.includes('@store.local') && !order.customer_email.includes('@example.com')) {
                clientDetails += `<div style="font-size: 0.78rem; color: #94a3b8; margin-top: 2px;">✉️ ${order.customer_email}</div>`;
            }

            let rawAddress = order.shipping_address || (order.customer_id === 'counter_pos' ? 'Store Counter Collection' : 'Store Pickup');
            let itemsSummaryHtml = '';
            if (Array.isArray(order.items) && order.items.length > 0) {
                const itemsList = order.items.map(it => `<span style="display: inline-block; background: #1e293b; color: #f1f5f9; padding: 2px 6px; border-radius: 4px; border: 1px solid #334155; margin: 2px 2px 2px 0; font-size: 0.74rem;">${it.name || 'Product'} ×<strong>${it.quantity || 1}</strong></span>`).join('');
                itemsSummaryHtml = `<div style="margin-top: 6px;">${itemsList}</div>`;
            }

            const fullAddressHtml = `
                <div style="font-size: 0.85rem; color: #e2e8f0; line-height: 1.4; display: flex; align-items: flex-start; gap: 4px;">
                    <span style="font-size: 1rem;">📍</span>
                    <div>${rawAddress}</div>
                </div>
                ${itemsSummaryHtml}
            `;
            
            const isCod = order.payment_method === 'COD';
            const paymentMethodHtml = isCod ? 
                `<div style="margin-top: 4px;"><span class="badge" style="background: rgba(245, 158, 11, 0.15); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.3); font-weight: 700; font-size: 0.72rem; padding: 2px 6px; border-radius: 4px;">💵 CASH ON DELIVERY</span></div>` :
                `<div style="margin-top: 4px;"><span class="badge" style="background: rgba(16, 185, 129, 0.15); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.3); font-weight: 700; font-size: 0.72rem; padding: 2px 6px; border-radius: 4px;">💳 ONLINE PAID</span></div>`;

            let codActionHtml = '';
            if (isCod && status !== 'Delivered' && status !== 'Paid') {
                codActionHtml = `
                    <div style="margin-top: 6px;">
                        <button type="button" onclick="collectAdminCod('${order.tracking_number || order.id}')" style="width: 100%; font-size: 0.72rem; padding: 0.25rem 0.4rem; background: rgba(16, 185, 129, 0.2); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.4); border-radius: 4px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 4px;">
                            <span>✅</span> Mark COD Collected
                        </button>
                    </div>
                `;
            }
            
            const actionSelect = `
                <div style="display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;">
                    <select style="font-size: 0.82rem; padding: 0.3rem 0.5rem; background: #1e293b; color: #f8fafc; border: 1px solid #334155; border-radius: 6px;" onchange="updateAdminOrderStatus('${order.id}', this.value)">
                        <option value="Pending" ${status === 'Pending' ? 'selected' : ''}>PENDING</option>
                        <option value="Paid" ${status === 'Paid' ? 'selected' : ''}>PAID</option>
                        <option value="Shipped" ${status === 'Shipped' ? 'selected' : ''}>SHIPPED</option>
                        <option value="Delivered" ${status === 'Delivered' ? 'selected' : ''}>DELIVERED</option>
                        <option value="Cancelled" ${status === 'Cancelled' ? 'selected' : ''}>CANCELLED</option>
                    </select>
                    <button type="button" onclick="deleteAdminOrder('${order.id}')" title="Delete this order" style="padding: 0.3rem 0.55rem; background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 6px; cursor: pointer; font-size: 0.85rem;">🗑️</button>
                </div>
            `;
            
            tr.innerHTML = `
                <td style="font-weight: 700; color: #f8fafc;">#${order.id}<br><span style="font-size: 0.72rem; color: #94a3b8;">${order.tracking_number || ''}</span></td>
                <td style="font-size: 0.82rem; color: #cbd5e1;">${dateStr}</td>
                <td>${clientDetails}</td>
                <td style="max-width: 260px;">${fullAddressHtml}</td>
                <td style="font-weight: bold; color: var(--teal);">${formatINR(order.total_amount)}${paymentMethodHtml}</td>
                <td>${statusBadge}</td>
                <td style="text-align: center;">
                    ${actionSelect}
                    ${codActionHtml}
                </td>
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
            loadDashboardMetrics();
        } else {
            showToast(data.error || "Failed to change order status.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}

async function deleteAdminOrder(orderId) {
    if (!confirm(`Are you sure you want to permanently delete order #${orderId}?`)) return;
    try {
        const res = await fetch(`/api/orders/${orderId}`, { method: 'DELETE' });
        const data = await res.json();
        if (res.ok) {
            showToast(data.message || `Order #${orderId} deleted.`);
            loadAdminOrders();
            loadDashboardMetrics();
        } else {
            showToast(data.error || "Failed to delete order", "error");
        }
    } catch(err) {
        showToast("Connection error: " + err.message, "error");
    }
}

async function purgeAllOrders() {
    if (!confirm("Are you sure you want to permanently delete ALL test and dummy orders? The orders manager will become completely clean and empty.")) return;
    try {
        const res = await fetch('/api/orders/admin/purge-all', { method: 'DELETE' });
        const data = await res.json();
        if (res.ok) {
            showToast(data.message || "All orders cleared. Database is clean.");
            loadAdminOrders();
            loadDashboardMetrics();
        } else {
            showToast(data.error || "Failed to purge orders", "error");
        }
    } catch(err) {
        showToast("Connection error: " + err.message, "error");
    }
}

window.loadAdminOrders = loadAdminOrders;
window.updateAdminOrderStatus = updateAdminOrderStatus;
window.deleteAdminOrder = deleteAdminOrder;
window.purgeAllOrders = purgeAllOrders;

async function collectAdminCod(trackingNumber) {
    if (!confirm(`Confirm collection of Cash on Delivery payment for order ${trackingNumber}? This will mark the order as Paid and Delivered.`)) return;
    try {
        const res = await fetch(`/api/orders/${trackingNumber}/collect-cod`, { method: 'POST' });
        const data = await res.json();
        if (res.ok) {
            showToast("COD Payment recorded successfully! Order marked Delivered.");
            loadAdminOrders();
            loadDashboardMetrics();
        } else {
            showToast(data.error || "Failed to record COD payment", "error");
        }
    } catch(e) {
        showToast("Error: " + e.message, "error");
    }
}
window.collectAdminCod = collectAdminCod;

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
        { id: '1', name: 'Aashirvaad Atta', defaultIcon: '🌾', searchName: 'atta' },
        { id: '2', name: 'India Gate Rice', defaultIcon: '🍚', searchName: 'rice' },
        { id: '3', name: 'Amul Butter', defaultIcon: '🧈', searchName: 'butter' },
        { id: '4', name: 'MDH Chilli Powder', defaultIcon: '🌶️', searchName: 'mirch' }
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
// DYNAMIC ANNOUNCEMENT & DEALS SYSTEM (Flipkart / Amazon Style Admin Publisher)
// ==========================================

async function loadAnnouncementsStorefront() {
    try {
        const response = await fetch('/api/announcements?t=' + Date.now());
        const data = await response.json();
        if (response.ok) {
            // 1. Ticker Header
            const banner = document.getElementById('store-announcement-banner');
            const text = document.getElementById('store-announcement-text');
            if (banner && text) {
                const parts = [];
                if (data.stock_status) parts.push(`📦 ${data.stock_status}`);
                if (data.loyalty_offer) parts.push(`⚡ ${data.loyalty_offer}`);
                if (data.home_delivery) parts.push(`🚚 ${data.home_delivery}`);
                text.innerText = parts.length > 0 ? parts.join("   |   ") : "Welcome to Rama Store - Samaur's Trusted Supermart!";
                banner.style.display = 'flex';
            }

            // 2. Deal of the Day Banner
            const dealBanner = document.getElementById('storefront-deal-banner');
            if (dealBanner) {
                if (data.deal_active !== false && data.deal_title) {
                    dealBanner.style.display = 'block';
                    const titleEl = document.getElementById('deal-banner-title');
                    const subEl = document.getElementById('deal-banner-subtitle');
                    const badgeEl = document.getElementById('deal-banner-badge');
                    const tagEl = document.getElementById('deal-banner-tag');
                    const imgEl = document.getElementById('deal-banner-img');

                    if (titleEl) titleEl.innerText = data.deal_title;
                    if (subEl) subEl.innerText = data.deal_subtitle || '';
                    if (badgeEl) badgeEl.innerText = data.deal_discount || 'SPECIAL OFFER';
                    if (tagEl) tagEl.innerText = data.deal_tag || '⚡ DEAL OF THE DAY';
                    if (imgEl && data.deal_image_url) imgEl.src = data.deal_image_url;
                } else {
                    dealBanner.style.display = 'none';
                }
            }

            // 3. Store Notice Bar
            const noticeBanner = document.getElementById('storefront-notice-banner');
            if (noticeBanner) {
                if (data.notice_active && data.notice_text) {
                    noticeBanner.style.display = 'flex';
                    const noticeText = document.getElementById('storefront-notice-text');
                    if (noticeText) noticeText.innerText = data.notice_text;
                } else {
                    noticeBanner.style.display = 'none';
                }
            }
        }
    } catch(err) {
        console.error("Failed to load storefront announcements:", err);
    }
}
window.loadAnnouncementsStorefront = loadAnnouncementsStorefront;

async function loadAnnouncementsIntoForm() {
    try {
        const response = await fetch('/api/announcements?t=' + Date.now());
        const data = await response.json();
        if (response.ok) {
            const setVal = (id, val) => {
                const el = document.getElementById(id);
                if (el) el.value = val !== undefined ? val : '';
            };
            const setChecked = (id, val) => {
                const el = document.getElementById(id);
                if (el) el.checked = Boolean(val);
            };

            setVal('ann-stock-status', data.stock_status || 'Fresh stock of Premium Basmati Rice, Atta & Fortune Oil arrived today!');
            setVal('ann-loyalty-offer', data.loyalty_offer || 'Flash Offer: Flat 20% OFF on all groceries today with code RAMA20!');
            setVal('ann-home-delivery', data.home_delivery || 'Express 45-min Home Delivery across Samaur on orders above ₹499');
            
            setVal('ann-deal-title', data.deal_title || '⚡ MEGA GROCERY DHAMAKA SALE');
            setVal('ann-deal-subtitle', data.deal_subtitle || 'Exclusive Discounts on Daily Household Essentials & Snacks');
            setVal('ann-deal-discount', data.deal_discount || 'UP TO 40% OFF');
            setVal('ann-deal-tag', data.deal_tag || 'DEAL OF THE DAY');
            setVal('ann-deal-image', data.deal_image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80');
            setChecked('ann-deal-active', data.deal_active !== false);

            setVal('ann-notice-text', data.notice_text || '🏪 Rama Store Samaur is open 7 days a week: 7:00 AM – 10:00 PM');
            setChecked('ann-notice-active', Boolean(data.notice_active));

            updateAnnouncementPreview();
        }
    } catch(err) {
        console.error("Failed to load announcements into edit form:", err);
    }
}
window.loadAnnouncementsIntoForm = loadAnnouncementsIntoForm;

function updateAnnouncementPreview() {
    const stock = document.getElementById('ann-stock-status')?.value || '';
    const offer = document.getElementById('ann-loyalty-offer')?.value || '';
    const delivery = document.getElementById('ann-home-delivery')?.value || '';
    
    const dealTitle = document.getElementById('ann-deal-title')?.value || '⚡ MEGA GROCERY DHAMAKA SALE';
    const dealSub = document.getElementById('ann-deal-subtitle')?.value || 'Special Deals & Daily Discounts';
    const dealDisc = document.getElementById('ann-deal-discount')?.value || 'UP TO 40% OFF';
    const dealTag = document.getElementById('ann-deal-tag')?.value || 'DEAL OF THE DAY';
    const dealImg = document.getElementById('ann-deal-image')?.value || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80';
    const dealActive = document.getElementById('ann-deal-active')?.checked ?? true;

    const noticeText = document.getElementById('ann-notice-text')?.value || '';
    const noticeActive = document.getElementById('ann-notice-active')?.checked ?? false;

    // Update Live Preview Mockup
    const prevTicker = document.getElementById('preview-ticker-text');
    if (prevTicker) {
        const parts = [];
        if (stock) parts.push(`📦 ${stock}`);
        if (offer) parts.push(`⚡ ${offer}`);
        if (delivery) parts.push(`🚚 ${delivery}`);
        prevTicker.innerText = parts.length > 0 ? parts.join("   |   ") : "Store announcements will appear here...";
    }

    const prevDeal = document.getElementById('preview-deal-card');
    if (prevDeal) {
        prevDeal.style.display = dealActive ? 'block' : 'none';
        const pTitle = document.getElementById('preview-deal-title');
        const pSub = document.getElementById('preview-deal-sub');
        const pBadge = document.getElementById('preview-deal-badge');
        const pTag = document.getElementById('preview-deal-tag');
        const pImg = document.getElementById('preview-deal-img');
        if (pTitle) pTitle.innerText = dealTitle;
        if (pSub) pSub.innerText = dealSub;
        if (pBadge) pBadge.innerText = dealDisc;
        if (pTag) pTag.innerText = dealTag;
        if (pImg) pImg.src = dealImg;
    }

    const prevNotice = document.getElementById('preview-notice-bar');
    if (prevNotice) {
        prevNotice.style.display = noticeActive && noticeText ? 'flex' : 'none';
        const pNoticeText = document.getElementById('preview-notice-text');
        if (pNoticeText) pNoticeText.innerText = noticeText;
    }
}
window.updateAnnouncementPreview = updateAnnouncementPreview;

function setDealImagePreset(url) {
    const input = document.getElementById('ann-deal-image');
    if (input) {
        input.value = url;
        updateAnnouncementPreview();
    }
}
window.setDealImagePreset = setDealImagePreset;

async function handleAnnouncementSubmit(e) {
    e.preventDefault();
    const stock = (document.getElementById('ann-stock-status')?.value || '').trim();
    const offer = (document.getElementById('ann-loyalty-offer')?.value || '').trim();
    const delivery = (document.getElementById('ann-home-delivery')?.value || '').trim();

    const deal_title = (document.getElementById('ann-deal-title')?.value || '').trim();
    const deal_subtitle = (document.getElementById('ann-deal-subtitle')?.value || '').trim();
    const deal_discount = (document.getElementById('ann-deal-discount')?.value || '').trim();
    const deal_tag = (document.getElementById('ann-deal-tag')?.value || '').trim();
    const deal_image_url = (document.getElementById('ann-deal-image')?.value || '').trim();
    const deal_active = document.getElementById('ann-deal-active')?.checked ?? true;

    const notice_text = (document.getElementById('ann-notice-text')?.value || '').trim();
    const notice_active = document.getElementById('ann-notice-active')?.checked ?? false;
    
    const submitBtn = e.target.querySelector('button[type="submit"]');
    const origText = submitBtn.innerText;
    submitBtn.disabled = true;
    submitBtn.innerText = 'Publishing Live to Storefront...';
    
    try {
        const response = await fetch('/api/announcements', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                stock_status: stock,
                loyalty_offer: offer,
                home_delivery: delivery,
                deal_title,
                deal_subtitle,
                deal_discount,
                deal_tag,
                deal_image_url,
                deal_active,
                notice_text,
                notice_active
            })
        });
        const data = await response.json();
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        
        if (response.ok) {
            showToast("🚀 Announcements & Deals published LIVE to Storefront successfully!", "success");
            loadAnnouncementsStorefront();
            updateAnnouncementPreview();
        } else {
            showToast(data.error || "Failed to publish announcements.", "error");
        }
    } catch(err) {
        submitBtn.disabled = false;
        submitBtn.innerText = origText;
        showToast("Connection failed: " + err.message, "error");
    }
}
window.handleAnnouncementSubmit = handleAnnouncementSubmit;

// Administrative Logout Handler
async function handleAdminLogout() {
    if (!confirm("Are you sure you want to securely log out of the Admin Desk?")) return;
    try {
        const token = localStorage.getItem('adminToken');
        if (token) {
            await fetch('/api/auth/admin-logout', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` }
            });
        }
    } catch (_) {}
    localStorage.removeItem('adminToken');
    localStorage.removeItem('currentUser');
    window.location.replace('/admin/login');
}
window.handleAdminLogout = handleAdminLogout;

// Responsive Mobile Sidebar Toggle
function toggleAdminSidebar() {
    const sidebar = document.querySelector('.admin-sidebar');
    if (sidebar) {
        sidebar.classList.toggle('open');
    }
}
window.toggleAdminSidebar = toggleAdminSidebar;

// ==========================================
// ADMIN COUPONS MANAGEMENT
// ==========================================

async function loadAdminCoupons() {
    const tbody = document.getElementById('admin-coupons-table-body');
    if (!tbody) return;
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 2rem; color: #94a3b8;">Loading coupons...</td></tr>`;
    
    try {
        const res = await fetch('/api/coupons');
        const data = await res.json();
        const coupons = data.coupons || [];
        
        if (coupons.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 2rem; color: #94a3b8;">No coupons created yet. Use the form on the right to add your first coupon!</td></tr>`;
            return;
        }
        
        tbody.innerHTML = '';
        coupons.forEach(c => {
            const tr = document.createElement('tr');
            const discountLabel = c.type === 'percent' ? `${c.value}% OFF` : `₹${c.value} OFF`;
            const minOrderLabel = c.min_order > 0 ? `₹${c.min_order}` : 'No minimum';
            const statusBadge = c.active ? 
                `<span class="badge badge-in-stock">ACTIVE</span>` : 
                `<span class="badge badge-out-of-stock">INACTIVE</span>`;
            
            tr.innerHTML = `
                <td style="font-family: monospace; font-weight: 700; color: var(--gold-accent); font-size: 0.95rem;">🏷️ ${c.code}</td>
                <td style="font-weight: 700; color: #10b981;">${discountLabel}</td>
                <td>${minOrderLabel}</td>
                <td>${statusBadge}</td>
                <td style="text-align: center;">
                    <button type="button" onclick="deleteAdminCoupon('${c.code}')" style="padding: 0.3rem 0.6rem; background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 6px; cursor: pointer; font-size: 0.85rem;" title="Delete Coupon">🗑️</button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 2rem; color: var(--danger);">Failed to load coupons: ${err.message}</td></tr>`;
    }
}
window.loadAdminCoupons = loadAdminCoupons;

async function handleCreateCoupon(e) {
    if (e && e.preventDefault) e.preventDefault();
    const code = (document.getElementById('coupon-code-input')?.value || '').trim().toUpperCase();
    const type = document.getElementById('coupon-type-input')?.value || 'percent';
    const value = parseFloat(document.getElementById('coupon-value-input')?.value || 0);
    const min_order = parseFloat(document.getElementById('coupon-min-order-input')?.value || 0);
    const description = (document.getElementById('coupon-desc-input')?.value || '').trim();
    
    if (!code || value <= 0) {
        showToast("Please enter a valid coupon code and discount value.", "error");
        return;
    }
    
    try {
        const res = await fetch('/api/coupons', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ code, type, value, min_order, description, active: true })
        });
        const data = await res.json();
        if (res.ok && data.success) {
            showToast(`Coupon '${code}' created successfully!`);
            document.getElementById('admin-coupon-form')?.reset();
            loadAdminCoupons();
        } else {
            showToast(data.error || "Failed to create coupon.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}
window.handleCreateCoupon = handleCreateCoupon;

async function deleteAdminCoupon(code) {
    if (!confirm(`Are you sure you want to delete coupon '${code}'?`)) return;
    try {
        const res = await fetch(`/api/coupons/${code}`, { method: 'DELETE' });
        const data = await res.json();
        if (res.ok) {
            showToast(`Coupon '${code}' deleted.`);
            loadAdminCoupons();
        } else {
            showToast(data.error || "Failed to delete coupon.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}
window.deleteAdminCoupon = deleteAdminCoupon;

// ==========================================
// ADMIN DELIVERY & PIN CODES MANAGEMENT
// ==========================================

function togglePincodeInput(show) {
    const wrap = document.getElementById('pincodes-wrapper');
    if (wrap) wrap.style.display = show ? 'block' : 'none';
}
window.togglePincodeInput = togglePincodeInput;

async function loadAdminDeliverySettings() {
    try {
        const res = await fetch('/api/settings/delivery');
        const data = await res.json();
        if (res.ok && data.settings) {
            const s = data.settings;
            const isSpecific = s.mode === 'SPECIFIC';
            const allRadio = document.getElementById('deliv-mode-all');
            const specRadio = document.getElementById('deliv-mode-specific');
            if (allRadio && specRadio) {
                if (isSpecific) specRadio.checked = true;
                else allRadio.checked = true;
                togglePincodeInput(isSpecific);
            }
            const pinTextarea = document.getElementById('deliv-pincodes');
            if (pinTextarea && Array.isArray(s.serviceable_pincodes)) {
                pinTextarea.value = s.serviceable_pincodes.join(', ');
            }
            const minInput = document.getElementById('deliv-free-min');
            if (minInput && s.free_delivery_min !== undefined) minInput.value = s.free_delivery_min;
            const feeInput = document.getElementById('deliv-std-fee');
            if (feeInput && s.standard_shipping_fee !== undefined) feeInput.value = s.standard_shipping_fee;
            const daysInput = document.getElementById('deliv-est-days');
            if (daysInput && s.estimated_days) daysInput.value = s.estimated_days;
        }
    } catch (err) {
        console.error("load delivery settings error:", err);
    }
}
window.loadAdminDeliverySettings = loadAdminDeliverySettings;

async function handleSaveDeliverySettings(e) {
    if (e && e.preventDefault) e.preventDefault();
    const mode = document.querySelector('input[name="delivery-mode"]:checked')?.value || 'ALL';
    const pinsRaw = document.getElementById('deliv-pincodes')?.value || '';
    const freeMin = parseFloat(document.getElementById('deliv-free-min')?.value || 500);
    const stdFee = parseFloat(document.getElementById('deliv-std-fee')?.value || 49);
    const estDays = (document.getElementById('deliv-est-days')?.value || '1-2 Business Days').trim();
    
    try {
        const res = await fetch('/api/settings/delivery', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                mode: mode,
                serviceable_pincodes: pinsRaw,
                free_delivery_min: freeMin,
                standard_shipping_fee: stdFee,
                estimated_days: estDays
            })
        });
        const data = await res.json();
        if (res.ok && data.success) {
            showToast("Delivery settings and serviceable PIN codes saved successfully!");
        } else {
            showToast(data.error || "Failed to save delivery settings.", "error");
        }
    } catch (err) {
        showToast(err.message, "error");
    }
}
window.handleSaveDeliverySettings = handleSaveDeliverySettings;

// ==========================================
// IMAGE UPLOAD & MEDIA GALLERY ENGINE (Cloud Storage)
// ==========================================
const productGalleryState = {
    prod: [],
    edit: []
};

async function handleProductImageFiles(files, prefix = 'prod') {
    if (!files || files.length === 0) return;
    const progressEl = document.getElementById(`${prefix}-upload-progress`);
    if (progressEl) {
        progressEl.style.display = 'block';
        progressEl.innerText = `⏳ Preparing ${files.length} image(s)...`;
    }

    for (let i = 0; i < files.length; i++) {
        const file = files[i];
        if (!file.type.startsWith('image/')) {
            showToast(`Skipped non-image file: ${file.name}`, 'error');
            continue;
        }
        if (file.size > 8 * 1024 * 1024) {
            showToast(`File ${file.name} is larger than 8MB.`, 'error');
            continue;
        }

        try {
            const base64Data = await readFileAndCompress(file, 1200, 0.85);
            if (progressEl) progressEl.innerText = `⏳ Uploading ${file.name} to Cloud Storage...`;

            const res = await fetch('/api/upload/image', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    image: base64Data,
                    filename: file.name,
                    folder: 'products'
                })
            });
            const data = await res.json();
            if (res.ok && data.success && data.url) {
                productGalleryState[prefix].push(data.url);
                showToast(`✅ "${file.name}" uploaded to Cloud Storage!`);
            } else {
                showToast(data.error || `Failed to upload ${file.name}`, 'error');
            }
        } catch (err) {
            showToast(`Upload error for ${file.name}: ` + err.message, 'error');
        }
    }

    if (progressEl) progressEl.style.display = 'none';
    renderImagePreviews(prefix);
}
window.handleProductImageFiles = handleProductImageFiles;

function readFileAndCompress(file, maxWidth = 1200, quality = 0.85) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
                let width = img.width;
                let height = img.height;
                if (width > maxWidth) {
                    height = Math.round((height * maxWidth) / width);
                    width = maxWidth;
                }
                const canvas = document.createElement('canvas');
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, width, height);
                resolve(canvas.toDataURL(file.type || 'image/jpeg', quality));
            };
            img.onerror = () => resolve(e.target.result);
            img.src = e.target.result;
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

function renderImagePreviews(prefix = 'prod') {
    const container = document.getElementById(`${prefix}-image-previews`);
    if (!container) return;
    container.innerHTML = '';

    const list = productGalleryState[prefix] || [];
    list.forEach((url, idx) => {
        const div = document.createElement('div');
        div.style.position = 'relative';
        div.style.display = 'inline-block';
        div.style.margin = '4px';

        div.innerHTML = `
            <img src="${url}" style="width: 70px; height: 70px; object-fit: cover; border-radius: 6px; border: 2px solid ${idx === 0 ? 'var(--gold-accent)' : 'rgba(255,255,255,0.2)'};" alt="Preview">
            ${idx === 0 ? '<span style="position: absolute; bottom: 2px; left: 2px; background: var(--gold-accent); color: #000; font-size: 0.65rem; font-weight: 800; padding: 1px 4px; border-radius: 3px;">MAIN</span>' : ''}
            <button type="button" onclick="removeImagePreview(${idx}, '${prefix}')" style="position: absolute; top: -6px; right: -6px; background: #ef4444; color: #fff; border: none; border-radius: 50%; width: 20px; height: 20px; font-size: 0.75rem; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 4px rgba(0,0,0,0.4);" title="Remove image">×</button>
        `;
        container.appendChild(div);
    });

    const urlInput = document.getElementById(`${prefix}-image-url`);
    if (urlInput && list.length > 0) {
        urlInput.value = list[0];
    }
}
window.renderImagePreviews = renderImagePreviews;

function removeImagePreview(index, prefix = 'prod') {
    if (productGalleryState[prefix] && productGalleryState[prefix][index]) {
        productGalleryState[prefix].splice(index, 1);
        renderImagePreviews(prefix);
    }
}
window.removeImagePreview = removeImagePreview;

function syncDirectImageUrl(val, prefix = 'prod') {
    val = (val || '').trim();
    if (val && !productGalleryState[prefix].includes(val)) {
        productGalleryState[prefix] = [val];
        renderImagePreviews(prefix);
    }
}
window.syncDirectImageUrl = syncDirectImageUrl;

// ==========================================
// CUSTOMER MANAGEMENT (Admin Console)
// ==========================================
async function loadAdminCustomers() {
    const tbody = document.getElementById('admin-customers-table-body');
    if (!tbody) return;
    tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 2.5rem;">Loading registered customers...</td></tr>`;

    try {
        const res = await fetch('/api/admin/customers');
        const data = await res.json();
        const customers = data.customers || [];

        if (customers.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #94a3b8; padding: 3rem;">No customers registered yet.</td></tr>`;
            return;
        }

        tbody.innerHTML = '';
        customers.forEach(c => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td style="font-weight: 700; color: #f8fafc;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <span style="background: var(--gold-accent); color: #000; width: 30px; height: 30px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-weight: 800; font-size: 0.82rem;">${(c.fullname || 'C').charAt(0).toUpperCase()}</span>
                        <span>${c.fullname}</span>
                    </div>
                </td>
                <td style="font-family: monospace; color: #38bdf8;">${c.phone}</td>
                <td style="color: #cbd5e1;">${c.email}</td>
                <td style="color: #94a3b8; font-size: 0.85rem; max-width: 250px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${c.address}">${c.address}</td>
                <td style="text-align: center; font-weight: 700; color: #10b981;">${c.total_orders}</td>
                <td style="text-align: right; font-weight: 800; color: var(--gold-accent);">${formatINR(c.total_spend)}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: #ef4444; padding: 2rem;">Error: ${err.message}</td></tr>`;
    }
}
window.loadAdminCustomers = loadAdminCustomers;

// ==========================================
// REPORTS & ACCOUNTING (Admin Console)
// ==========================================
async function loadAdminReports() {
    try {
        const res = await fetch('/api/admin/reports');
        const data = await res.json();
        if (!res.ok || !data.success) return;

        const inv = data.inventory || {};
        const ord = data.orders || {};

        const setTxt = (id, val) => {
            const el = document.getElementById(id);
            if (el) el.innerText = val;
        };

        setTxt('report-total-val', formatINR(inv.selling_valuation || 0));
        setTxt('report-cost-val', formatINR(inv.cost_valuation || 0));
        setTxt('report-margin', formatINR(inv.potential_profit || 0));
        setTxt('report-published-cnt', inv.published || 0);
        setTxt('report-draft-cnt', inv.draft || 0);
        setTxt('report-low-cnt', inv.low_stock || 0);
        setTxt('report-outofstock-cnt', inv.out_of_stock || 0);

        setTxt('report-tot-rev', formatINR(ord.total_revenue || 0));
        setTxt('report-today-rev', formatINR(ord.today_revenue || 0));
        setTxt('report-tot-orders', ord.total_orders || 0);
        setTxt('report-today-orders', ord.today_orders || 0);

        const stContainer = document.getElementById('report-status-breakdown');
        if (stContainer && ord.by_status) {
            stContainer.innerHTML = Object.entries(ord.by_status).map(([k, v]) => `
                <div style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); padding: 0.6rem 1rem; border-radius: 8px; text-align: center;">
                    <div style="font-size: 0.75rem; color: #94a3b8; text-transform: uppercase;">${k}</div>
                    <div style="font-size: 1.25rem; font-weight: 800; color: #f8fafc; margin-top: 2px;">${v}</div>
                </div>
            `).join('');
        }
    } catch (err) {
        console.error("Failed to load reports:", err);
    }
}
window.loadAdminReports = loadAdminReports;

function downloadCatalogCsv() {
    window.open('/api/products/export-csv', '_blank');
}
window.downloadCatalogCsv = downloadCatalogCsv;

function downloadOrdersCsv() {
    window.open('/api/orders/export-csv', '_blank');
}
window.downloadOrdersCsv = downloadOrdersCsv;

// ==========================================
// BULK CSV PRODUCT IMPORT
// ==========================================
function openCsvImportModal() {
    const modal = document.getElementById('csv-import-modal');
    if (modal) modal.classList.add('active');
}
window.openCsvImportModal = openCsvImportModal;

function closeCsvImportModal() {
    const modal = document.getElementById('csv-import-modal');
    if (modal) modal.classList.remove('active');
}
window.closeCsvImportModal = closeCsvImportModal;

function downloadCsvTemplate() {
    const headers = "SKU,Product Name,Category,MRP,Selling Price,Cost Price,Stock,Unit,Status,Description,Image URL\r\n";
    const sample = "RAMA-EX-001,Sample Grocery Item (1 kg),Staples & Grains,120,99,85,50,1 kg,published,Fresh retail essentials,https://images.unsplash.com/photo-1542838132-92c53300491e\r\n";
    const blob = new Blob([headers + sample], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = "rama_store_import_template.csv";
    link.click();
}
window.downloadCsvTemplate = downloadCsvTemplate;

async function handleCsvImportSubmit(e) {
    if (e && e.preventDefault) e.preventDefault();
    const fileInput = document.getElementById('csv-file-input');
    if (!fileInput || !fileInput.files.length) {
        showToast("Please choose a CSV file to import.", "error");
        return;
    }

    const file = fileInput.files[0];
    const reader = new FileReader();
    reader.onload = async (evt) => {
        try {
            const text = evt.target.result;
            const lines = text.split(/\r\n|\n/).filter(l => l.trim().length > 0);
            if (lines.length <= 1) {
                showToast("CSV file is empty or contains only headers.", "error");
                return;
            }

            const products = [];

            for (let i = 1; i < lines.length; i++) {
                const cols = [];
                let inQuotes = false;
                let currentStr = '';
                for (let ch of lines[i]) {
                    if (ch === '"') inQuotes = !inQuotes;
                    else if (ch === ',' && !inQuotes) {
                        cols.push(currentStr.trim());
                        currentStr = '';
                    } else currentStr += ch;
                }
                cols.push(currentStr.trim());

                if (cols.length >= 5 && cols[1]) {
                    products.push({
                        sku: cols[0] || '',
                        name: cols[1],
                        category: cols[2] || 'General',
                        original_price: parseFloat(cols[3] || cols[4] || 0),
                        selling_price: parseFloat(cols[4] || 0),
                        purchase_price: parseFloat(cols[5] || 0),
                        stock: parseInt(cols[6] || 0, 10),
                        unit: cols[7] || 'unit',
                        status: (cols[8] || '').toLowerCase() === 'draft' ? 'draft' : 'published',
                        description: cols[9] || '',
                        image_url: cols[10] || ''
                    });
                }
            }

            if (products.length === 0) {
                showToast("No valid product rows parsed from CSV.", "error");
                return;
            }

            showToast(`Importing ${products.length} products to database...`);
            const res = await fetch('/api/products/bulk-import', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ products })
            });
            const data = await res.json();
            if (res.ok && data.success) {
                showToast(`✅ Successfully imported ${data.imported} products!`);
                closeCsvImportModal();
                loadCatalog();
                loadDashboardMetrics();
            } else {
                showToast(data.error || "Bulk import failed", "error");
            }
        } catch (err) {
            showToast("Failed to parse CSV: " + err.message, "error");
        }
    };
    reader.readAsText(file);
}
window.handleCsvImportSubmit = handleCsvImportSubmit;

// ==========================================
// SESSION INACTIVITY MONITOR & AUTO-LOGOUT
// ==========================================
class SessionInactivityMonitor {
    constructor(warningMinutes = 15, timeoutMinutes = 20) {
        this.warningMs = warningMinutes * 60 * 1000;
        this.timeoutMs = timeoutMinutes * 60 * 1000;
        this.lastActivity = Date.now();
        this.warningShown = false;
        this.timer = null;
        this.countdownInterval = null;
    }

    start() {
        const resetActivity = () => {
            if (!this.warningShown) {
                this.lastActivity = Date.now();
            }
        };

        ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll'].forEach(evt => {
            window.addEventListener(evt, resetActivity, { passive: true });
        });

        this.timer = setInterval(() => this.check(), 15000);
    }

    check() {
        const token = localStorage.getItem('adminToken');
        if (!token) return;

        const idle = Date.now() - this.lastActivity;
        if (idle >= this.timeoutMs) {
            this.logout("Session expired due to 20 minutes of inactivity.");
        } else if (idle >= this.warningMs && !this.warningShown) {
            this.showWarning();
        }
    }

    showWarning() {
        this.warningShown = true;
        let warningModal = document.getElementById('session-timeout-modal');
        if (!warningModal) {
            warningModal = document.createElement('div');
            warningModal.id = 'session-timeout-modal';
            warningModal.className = 'modal-overlay active';
            warningModal.innerHTML = `
                <div class="modal-container" style="max-width: 420px; text-align: center; border: 1.5px solid #f59e0b; background: #0f172a; border-radius: 12px; padding: 1.5rem;">
                    <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🛡️</div>
                    <h3 style="color: #f59e0b; margin: 0; font-size: 1.25rem; font-weight: 800;">Inactivity Security Notice</h3>
                    <p style="color: #cbd5e1; font-size: 0.9rem; margin: 0.75rem 0 1.25rem 0; line-height: 1.5;">
                        You have been inactive for 15 minutes. For safety and fraud protection, your session will automatically terminate in:
                    </p>
                    <div id="session-countdown-display" style="font-size: 2.5rem; font-weight: 800; color: #f59e0b; font-family: monospace; letter-spacing: 0.1em; margin-bottom: 1.5rem;">
                        05:00
                    </div>
                    <div style="display: flex; gap: 0.75rem; justify-content: center;">
                        <button type="button" class="btn btn-primary" onclick="sessionMonitor.stayLoggedIn()" style="font-weight: 700; padding: 0.65rem 1.5rem; border-radius: 6px;">
                            Stay Signed In
                        </button>
                        <button type="button" class="btn btn-secondary" onclick="sessionMonitor.logout('Logged out voluntarily.')" style="padding: 0.65rem 1.25rem; border-radius: 6px;">
                            Log Out
                        </button>
                    </div>
                </div>
            `;
            document.body.appendChild(warningModal);
        } else {
            warningModal.classList.add('active');
        }

        let secondsRemaining = Math.max(0, Math.floor((this.timeoutMs - (Date.now() - this.lastActivity)) / 1000));
        if (this.countdownInterval) clearInterval(this.countdownInterval);
        this.countdownInterval = setInterval(() => {
            secondsRemaining--;
            const countEl = document.getElementById('session-countdown-display');
            if (countEl) {
                const mins = String(Math.floor(secondsRemaining / 60)).padStart(2, '0');
                const secs = String(secondsRemaining % 60).padStart(2, '0');
                countEl.innerText = `${mins}:${secs}`;
            }
            if (secondsRemaining <= 0) {
                clearInterval(this.countdownInterval);
                this.logout("Session expired due to inactivity.");
            }
        }, 1000);
    }

    stayLoggedIn() {
        this.lastActivity = Date.now();
        this.warningShown = false;
        if (this.countdownInterval) clearInterval(this.countdownInterval);
        const warningModal = document.getElementById('session-timeout-modal');
        if (warningModal) warningModal.classList.remove('active');
        showToast("Session extended. Active working session resumed.");
    }

    logout(reason) {
        localStorage.removeItem('adminToken');
        localStorage.removeItem('currentUser');
        window.location.replace('/admin/login?reason=inactivity');
    }
}
const sessionMonitor = new SessionInactivityMonitor(15, 20);
if (window.location.pathname.startsWith('/admin')) {
    sessionMonitor.start();
}

// Call on boot
document.addEventListener("DOMContentLoaded", () => {
    loadAnnouncementsStorefront();
});


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
