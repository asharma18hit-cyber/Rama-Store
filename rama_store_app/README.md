# Rama Store Native Mobile Application (Android + iOS)

A production-quality, high-performance Flutter mobile application for **Rama Store** (bakery, groceries, medicine, books, stationery, sports gear). It operates as an independent companion frontend communicating with the live backend at `https://rama-store-3u49.onrender.com`.

---

## Shared Live Backend Architecture Confirmation

> [!IMPORTANT]
> **Single Source of Truth (Amazon-Style Web + Mobile Synchronization)**:
> The existing web storefront and this Flutter mobile app are two native windows into the **exact same live store and database**. Neither frontend is a separate silo.
> The website and backend codebase (`app.py`, SQLite schema, Jinja templates) remain **100% untouched and unchanged**. Both web and mobile app hit the same backend endpoints and read/write to the same live database tables in real time.

### 1. Same User Accounts & Credentials
- Accounts created on the website can log in immediately on the Flutter mobile app using the same Email/Phone and Password or OTP verification, and vice versa.
- User accounts, passwords (bcrypt hashes), roles (`customer` / `admin`), and session authorizations are unified in SQLite table `users`.

### 2. Same Product Catalog & Inventory Stock
- Both the web application and the mobile application consume `GET /api/store/products` and `GET /api/categories`.
- Stock quantities are managed centrally: when a purchase is completed on the mobile app or website, inventory stock decreases live in the SQLite `products` table for both platforms.

### 3. Same Orders & Purchase History
- Orders placed from the Flutter app (`POST /api/checkout` -> `POST /api/payment/process`) generate real transactions with tracking numbers in table `orders`.
- The customer's order history (`GET /api/orders/history`) displays all past purchases regardless of whether they were placed via the website or the mobile app.

### 4. Same Loyalty Points Balance & Cash-Back
- Purchases made on either the website or mobile app earn **10% cash-back loyalty rewards**.
- The loyalty points balance is derived from completed purchase order totals (`total_amount`) in table `orders` for the logged-in account, guaranteeing instant synchronization without platform divergence.

### 5. Shared Cart & Offline Cache Strategy
- Local storage (`shared_preferences`/cache) in the mobile app is strictly a **temporary performance/offline fallback buffer** so users can view products when disconnected.
- When connected, cart checkouts sync directly to the Flask backend's `/api/checkout` engine, generating real order sessions and stock locking.

---

## Setup & Run Instructions

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Android Studio / Xcode for mobile emulation or physical device deployment

### Installation
```bash
cd rama_store_app
flutter pub get
```

### Running the Mobile App
#### Connecting to Live Production Backend (Default)
```bash
flutter run
```

#### Pointing to Staging Backend URL
```bash
flutter run --dart-define=BASE_URL=https://staging.ramastore.com
```

#### Offline Development / Mock Fallback Mode
```bash
flutter run --dart-define=USE_MOCKS=true
```

### Running Test Suite
```bash
flutter test
```

---

## Discovered API Contract Summary

| Endpoint | Method | Purpose | Session Auth Required |
|---|---|---|---|
| `/api/auth/login` | `POST` | Password authentication | No |
| `/api/auth/register` | `POST` | Initiate OTP account signup | No |
| `/api/auth/verify_otp` | `POST` | Complete signup & establish session | No |
| `/api/auth/login-otp-request` | `POST` | Request passwordless OTP code | No |
| `/api/auth/login-otp-verify` | `POST` | Complete OTP login | No |
| `/api/auth/forgot-password` | `POST` | Password reset OTP request | No |
| `/api/auth/reset-password` | `POST` | Set new password with OTP | No |
| `/api/auth/status` | `GET` | Validate current session cookie | Yes |
| `/api/auth/logout` | `POST` | Clear session cookie | Yes |
| `/api/store/products` | `GET` | Fetch published product catalog | No |
| `/api/categories` | `GET` | Fetch store category tree | No |
| `/api/announcements` | `GET` | Store offer & delivery banners | No |
| `/api/checkout` | `POST` | Create pending checkout order | Yes |
| `/api/payment/process` | `POST` | Gateway simulation & stock rollback | Yes |
| `/api/orders/history` | `GET` | Customer purchase history | Yes |

---

## Backend Gaps & Recommendations

1. **Dedicated Loyalty Balance Endpoint**:
   - *Current State*: The mobile app calculates loyalty points directly from `/api/orders/history` completed totals (10%).
   - *Recommendation*: Add a dedicated `GET /api/user/loyalty-balance` endpoint returning `{ "points": 250 }`.

2. **Server-Side Cart Storage Table**:
   - *Current State*: The web frontend stores draft carts in browser storage before checkout. Upon checkout, `/api/checkout` receives the full cart array and creates the order session.
   - *Recommendation*: Add a `user_carts` table to Flask if persistent draft cart syncing across device switches prior to checkout is required.
