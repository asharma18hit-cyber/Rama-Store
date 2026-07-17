const CATEGORIES = [
  "Foods & Restaurants",
  "Bakery",
  "Grocery",
  "Medicine", // Crucial: Fixed lowercase bug from "medicine" to "Medicine"
  "Books",
  "Copies",
  "Stationary",
  "Gift Store",
  "Sports"
];

const ADMIN_LOGIN_ID = "admin";
const ADMIN_SECURITY_KEY = "summit2026";
const MOCK_OTP = "489230";

const placeholderImage =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120' viewBox='0 0 120 120'%3E%3Crect width='120' height='120' rx='14' fill='%23EEF6FF'/%3E%3Cpath d='M31 76h58L72 53 58 68l-9-10-18 18Z' fill='%231B84FF' opacity='.8'/%3E%3Ccircle cx='44' cy='42' r='8' fill='%231B84FF' opacity='.8'/%3E%3C/svg%3E";

const state = {
  adminAuthenticated: false,
  activeFilter: "",
  uploadedImage: "",
  user: {
    name: "Rahul Sharma",
    identifier: "rahul@example.com"
  },
  inventory: [
    {
      id: makeId(),
      title: "Family Restaurant Thali",
      description: "Balanced lunch plate with dal, seasonal vegetables, rice, roti, salad, and dessert.",
      category: "Foods & Restaurants",
      price: 179,
      stock: 42,
      image: placeholderImage
    },
    {
      id: makeId(),
      title: "Fresh Cream Pineapple Cake",
      description: "One pound bakery cake with fresh cream, pineapple layers, and same-day pickup.",
      category: "Bakery",
      price: 520,
      stock: 8,
      image: placeholderImage
    },
    {
      id: makeId(),
      title: "A4 Copy Bundle",
      description: "High quality white A4 copy paper bundle for school, office, and shop usage.",
      category: "Copies",
      price: 310,
      stock: 64,
      image: placeholderImage
    },
    {
      id: makeId(),
      title: "Daily Wellness Kit",
      description: "Basic over-the-counter wellness kit with sanitizer, masks, and first-aid essentials.",
      category: "Medicine",
      price: 260,
      stock: 18,
      image: placeholderImage
    }
  ]
};

document.addEventListener("DOMContentLoaded", () => {
  populateCategorySelect();
  renderCategoryNavigation();
  renderAll();
  bindAuth();
  bindOtpMatrix();
  bindDashboard();
  bindAdminGate();
  bindPublisher();
  bindImageDropZone();
  syncRoute();
});

window.addEventListener("hashchange", syncRoute);

function qs(selector, root = document) {
  return root.querySelector(selector);
}

function qsa(selector, root = document) {
  return Array.from(root.querySelectorAll(selector));
}

function showView(viewId) {
  qsa(".view").forEach((view) => view.classList.add("hidden"));
  qs(`#${viewId}`).classList.remove("hidden");
}

function syncRoute() {
  if (location.hash === "#/admin") {
    if (state.adminAuthenticated) {
      showView("admin-view");
      renderAll();
    } else {
      openAdminGate();
    }
    return;
  }

  if (location.hash === "#/dashboard" || location.hash === "#/feed") {
    showView("dashboard-view");
    return;
  }

  showView("auth-view");
}

function bindAuth() {
  const loginTab = qs("#login-tab");
  const signupTab = qs("#signup-tab");
  const loginForm = qs("#login-form");
  const signupForm = qs("#signup-form");

  loginTab.addEventListener("click", () => {
    loginTab.classList.add("active");
    signupTab.classList.remove("active");
    loginTab.setAttribute("aria-selected", "true");
    signupTab.setAttribute("aria-selected", "false");
    loginForm.classList.remove("hidden");
    signupForm.classList.add("hidden");
    clearErrors();
  });

  signupTab.addEventListener("click", () => {
    signupTab.classList.add("active");
    loginTab.classList.remove("active");
    signupTab.setAttribute("aria-selected", "true");
    loginTab.setAttribute("aria-selected", "false");
    signupForm.classList.remove("hidden");
    loginForm.classList.add("hidden");
    resetSignupPhase();
    clearErrors();
  });

  loginForm.addEventListener("submit", (event) => {
    event.preventDefault();
    clearErrors();

    const identifier = qs("#login-identifier").value.trim();
    const password = qs("#login-password").value.trim();
    let valid = true;

    if (!isEmailOrPhone(identifier)) {
      setFieldError("#login-identifier", "Enter a valid email or phone number.");
      valid = false;
    }

    if (!password) {
      setFieldError("#login-password", "Password is required.");
      valid = false;
    }

    if (!valid) return;

    state.user = {
      name: identifier.includes("@") ? identifier.split("@")[0] : "Store User",
      identifier
    };
    updateProfile();
    location.hash = "#/dashboard";
    toast("Logged in successfully.");
  });

  qs("#send-otp-button").addEventListener("click", () => {
    clearErrors();
    const name = qs("#signup-name").value.trim();
    const identifier = qs("#signup-identifier").value.trim();
    const acceptedTerms = qs("#signup-terms").checked;
    let valid = true;

    if (!name) {
      setFieldError("#signup-name", "Full name is required.");
      valid = false;
    }

    if (!isEmailOrPhone(identifier)) {
      setFieldError("#signup-identifier", "Enter a valid email or phone number.");
      valid = false;
    }

    if (!acceptedTerms) {
      toast("Accept the terms to continue.", "error");
      valid = false;
    }

    if (!valid) return;

    qs("#signup-phase-one").classList.add("hidden");
    qs("#signup-phase-two").classList.remove("hidden");
    qs(".otp-input").focus();
    toast(`Verification code sent. Demo code: ${MOCK_OTP}`);
  });

  qs("#back-to-signup").addEventListener("click", resetSignupPhase);

  signupForm.addEventListener("submit", (event) => {
    event.preventDefault();
    clearErrors();

    const code = qsa(".otp-input").map((input) => input.value).join("");
    if (code !== MOCK_OTP) {
      qs("#otp-matrix").classList.add("error");
      qs("#otp-error").textContent = "Enter the 6-digit demo code 489230.";
      return;
    }

    state.user = {
      name: qs("#signup-name").value.trim(),
      identifier: qs("#signup-identifier").value.trim()
    };
    updateProfile();
    location.hash = "#/dashboard";
    toast("Account verified and created.");
  });

  qs("#google-auth-button").addEventListener("click", () => {
    state.user = {
      name: "Google Store User",
      identifier: "google-user@example.com"
    };
    updateProfile();
    location.hash = "#/dashboard";
    toast("Google authentication connected.");
  });
}

function resetSignupPhase() {
  qs("#signup-phase-one").classList.remove("hidden");
  qs("#signup-phase-two").classList.add("hidden");
  qsa(".otp-input").forEach((input) => {
    input.value = "";
  });
  qs("#otp-matrix").classList.remove("error");
  qs("#otp-error").textContent = "";
}

function bindOtpMatrix() {
  const inputs = qsa(".otp-input");

  inputs.forEach((input, index) => {
    input.addEventListener("input", () => {
      input.value = input.value.replace(/\D/g, "").slice(0, 1);
      if (input.value && index < inputs.length - 1) {
        inputs[index + 1].focus();
      }
    });

    input.addEventListener("keydown", (event) => {
      if (event.key === "Backspace" && !input.value && index > 0) {
        inputs[index - 1].focus();
      }
    });

    input.addEventListener("paste", (event) => {
      event.preventDefault();
      const pasted = event.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
      pasted.split("").forEach((digit, pastedIndex) => {
        if (inputs[pastedIndex]) inputs[pastedIndex].value = digit;
      });
      const focusIndex = Math.min(pasted.length, inputs.length) - 1;
      if (focusIndex >= 0) inputs[focusIndex].focus();
    });
  });
}

function bindDashboard() {
  const profileTrigger = qs("#profile-trigger");
  const dropdown = qs("#profile-dropdown");

  profileTrigger.addEventListener("click", (event) => {
    event.stopPropagation();
    const isOpen = dropdown.classList.toggle("open");
    profileTrigger.setAttribute("aria-expanded", String(isOpen));
  });

  document.addEventListener("click", (event) => {
    if (!dropdown.contains(event.target) && !profileTrigger.contains(event.target)) {
      dropdown.classList.remove("open");
      profileTrigger.setAttribute("aria-expanded", "false");
    }
  });

  qs("#dashboard-search").addEventListener("input", (event) => {
    state.activeFilter = event.target.value.trim();
    setActiveNav();
    renderProductFeed();
  });

  qs("#clear-filter-button").addEventListener("click", () => {
    state.activeFilter = "";
    qs("#dashboard-search").value = "";
    setActiveNav();
    renderProductFeed();
  });

  qs("#create-shortcut").addEventListener("click", () => {
    location.hash = "#/admin";
  });

  qs("#profile-admin-link").addEventListener("click", () => {
    dropdown.classList.remove("open");
    location.hash = "#/admin";
  });

  qs("#sidebar-admin-link").addEventListener("click", () => {
    location.hash = "#/admin";
  });

  qs("#logout-button").addEventListener("click", () => {
    dropdown.classList.remove("open");
    location.hash = "";
    toast("Signed out.");
  });
}

function bindAdminGate() {
  qs("#admin-gate-form").addEventListener("submit", (event) => {
    event.preventDefault();
    clearErrors(qs("#admin-gate-form"));

    const loginId = qs("#admin-login-id").value.trim();
    const securityKey = qs("#admin-security-key").value.trim();
    let valid = true;

    if (!loginId) {
      setFieldError("#admin-login-id", "Admin Login ID is required.");
      valid = false;
    }

    if (!securityKey) {
      setFieldError("#admin-security-key", "Admin Security Key is required.");
      valid = false;
    }

    if (!valid) return;

    if (loginId !== ADMIN_LOGIN_ID || securityKey !== ADMIN_SECURITY_KEY) {
      setFieldError("#admin-security-key", "Invalid admin credentials.");
      toast("Admin authentication failed.", "error");
      return;
    }

    state.adminAuthenticated = true;
    closeAdminGate();
    location.hash = "#/admin";
    showView("admin-view");
    toast("Admin access granted.");
  });

  qs("#cancel-gate-button").addEventListener("click", () => {
    closeAdminGate();
    if (location.hash === "#/admin") location.hash = "#/dashboard";
  });

  qs("#return-dashboard-button").addEventListener("click", () => {
    location.hash = "#/dashboard";
  });
}

function openAdminGate() {
  qs("#admin-gate").classList.remove("hidden");
  qs("#admin-login-id").value = "";
  qs("#admin-security-key").value = "";
  clearErrors(qs("#admin-gate-form"));
  setTimeout(() => qs("#admin-login-id").focus(), 0);
}

function closeAdminGate() {
  qs("#admin-gate").classList.add("hidden");
}

function bindPublisher() {
  qs("#publish-form").addEventListener("submit", (event) => {
    event.preventDefault();
    clearErrors(qs("#publish-form"));

    const title = qs("#product-title").value.trim();
    const description = qs("#product-description").value.trim();
    const category = qs("#product-category").value;
    const price = Number(qs("#product-price").value);
    const stock = Number.parseInt(qs("#product-stock").value, 10);
    let valid = true;

    if (!title) {
      setFieldError("#product-title", "Product title is required.");
      valid = false;
    }

    if (!description) {
      setFieldError("#product-description", "Product description is required.");
      valid = false;
    }

    if (!CATEGORIES.includes(category)) {
      setFieldError("#product-category", "Choose a valid system category.");
      valid = false;
    }

    if (!Number.isFinite(price) || price <= 0) {
      setFieldError("#product-price", "Enter a valid currency value.");
      valid = false;
    }

    if (!Number.isInteger(stock) || stock < 0) {
      setFieldError("#product-stock", "Enter a valid stock level.");
      valid = false;
    }

    if (!valid) return;

    state.inventory.unshift({
      id: makeId(),
      title,
      description,
      category,
      price,
      stock,
      image: state.uploadedImage || placeholderImage
    });

    qs("#publish-form").reset();
    resetImageDropZone();
    renderAll();
    toast(`Published "${title}" to the store.`);
  });
}

function bindImageDropZone() {
  const dropZone = qs("#drop-zone");
  const fileInput = qs("#product-image");

  ["dragenter", "dragover"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.add("dragging");
    });
  });

  ["dragleave", "drop"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.remove("dragging");
    });
  });

  dropZone.addEventListener("drop", (event) => {
    const [file] = event.dataTransfer.files;
    if (file) readImageFile(file);
  });

  fileInput.addEventListener("change", () => {
    const [file] = fileInput.files;
    if (file) readImageFile(file);
  });
}

function readImageFile(file) {
  if (!file.type.startsWith("image/")) {
    toast("Please upload an image file.", "error");
    return;
  }

  const reader = new FileReader();
  reader.addEventListener("load", () => {
    state.uploadedImage = reader.result;
    qs("#image-preview").src = state.uploadedImage;
    qs("#image-preview").classList.remove("hidden");
    qs("#drop-copy").classList.add("hidden");
  });
  reader.readAsDataURL(file);
}

function resetImageDropZone() {
  state.uploadedImage = "";
  qs("#product-image").value = "";
  qs("#image-preview").removeAttribute("src");
  qs("#image-preview").classList.add("hidden");
  qs("#drop-copy").classList.remove("hidden");
}

function populateCategorySelect() {
  const select = qs("#product-category");
  select.innerHTML = '<option value="">Select category</option>';
  CATEGORIES.forEach((category) => {
    const option = document.createElement("option");
    option.value = category;
    option.textContent = category;
    select.append(option);
  });
}

function renderCategoryNavigation() {
  const nav = qs("#category-nav");
  nav.innerHTML = "";

  CATEGORIES.forEach((category) => {
    const button = document.createElement("button");
    button.className = "nav-item nav-button";
    button.type = "button";
    button.dataset.filter = category;
    button.textContent = category;
    button.addEventListener("click", () => {
      state.activeFilter = category;
      qs("#dashboard-search").value = "";
      setActiveNav();
      renderProductFeed();
    });
    nav.append(button);
  });
}

function renderAll() {
  renderProductFeed();
  renderInventoryTable();
  renderDepartmentList();
  updateMetrics();
  updateProfile();
  setActiveNav();
}

function renderProductFeed() {
  const feed = qs("#product-feed");
  const products = getFilteredInventory();

  feed.innerHTML = "";

  if (!products.length) {
    const empty = document.createElement("article");
    empty.className = "product-card";
    empty.textContent = "No products match the current filter.";
    feed.append(empty);
    return;
  }

  products.forEach((product) => {
    const card = document.createElement("article");
    card.className = "product-card";
    card.innerHTML = `
      <header>
        <div class="product-identity">
          <img class="product-thumb" src="${product.image}" alt="">
          <div>
            <span class="product-title">${escapeHtml(product.title)}</span>
            <span class="product-subtitle">Published inventory item</span>
          </div>
        </div>
        <span class="tag">${escapeHtml(product.category)}</span>
      </header>
      <p>${escapeHtml(product.description)}</p>
      <div class="product-meta">
        <strong>${formatCurrency(product.price)}</strong>
        <strong>${product.stock} in stock</strong>
      </div>
      <div class="social-actions">
        <button type="button">Like</button>
        <button type="button">Comment</button>
        <button type="button">Share</button>
      </div>
    `;
    feed.append(card);
  });
}

function renderInventoryTable() {
  const tbody = qs("#inventory-table-body");
  tbody.innerHTML = "";

  state.inventory.forEach((product) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>
        <div class="table-product">
          <img src="${product.image}" alt="">
          <span>${escapeHtml(product.title)}</span>
        </div>
      </td>
      <td>${escapeHtml(product.category)}</td>
      <td>${formatCurrency(product.price)}</td>
      <td>${product.stock}</td>
    `;
    tbody.append(row);
  });
}

function renderDepartmentList() {
  const list = qs("#department-list");
  list.innerHTML = "";

  CATEGORIES.forEach((category) => {
    const count = state.inventory.filter((product) => product.category === category).length;
    const row = document.createElement("div");
    row.className = "department-row";
    row.innerHTML = `<span>${category}</span><span>${count}</span>`;
    list.append(row);
  });
}

function updateMetrics() {
  qs("#metric-products").textContent = String(state.inventory.length);
  qs("#metric-stock").textContent = String(
    state.inventory.reduce((total, product) => total + product.stock, 0)
  );
}

function updateProfile() {
  const initials = getInitials(state.user.name);
  qsa(".avatar").forEach((avatar) => {
    avatar.textContent = initials;
  });
  qs("#profile-name").textContent = state.user.name;
}

function setActiveNav() {
  qsa(".nav-item").forEach((item) => {
    item.classList.toggle("active", item.dataset.filter === state.activeFilter);
  });
}

function getFilteredInventory() {
  const filter = state.activeFilter.trim();
  if (!filter) return state.inventory;

  const normalized = filter.toLowerCase();
  return state.inventory.filter((product) => {
    if (CATEGORIES.includes(filter)) return product.category === filter;
    return (
      product.title.toLowerCase().includes(normalized) ||
      product.description.toLowerCase().includes(normalized) ||
      product.category.toLowerCase().includes(normalized)
    );
  });
}

function isEmailOrPhone(value) {
  const email = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const phone = /^\+?[0-9]{10,14}$/;
  return email.test(value) || phone.test(value);
}

function clearErrors(root = document) {
  qsa(".field", root).forEach((field) => field.classList.remove("error"));
  qsa(".field-error", root).forEach((error) => {
    error.textContent = "";
  });
  qs("#otp-matrix")?.classList.remove("error");
}

function setFieldError(selector, message) {
  const input = qs(selector);
  const field = input.closest(".field");
  field.classList.add("error");
  field.querySelector(".field-error").textContent = message;
}

function toast(message, type = "success") {
  const toastElement = document.createElement("div");
  toastElement.className = `toast ${type}`;
  toastElement.textContent = message;
  qs("#toast-region").append(toastElement);
  setTimeout(() => toastElement.remove(), 3200);
}

function formatCurrency(value) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2
  }).format(value);
}

function getInitials(name) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function makeId() {
  return `item-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
