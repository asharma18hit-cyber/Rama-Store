# Rama Store Mobile Application - API Contract Specification

This document details all REST API endpoints discovered from reverse-engineering the live backend at `https://rama-store-3u49.onrender.com` (Flask + SQLite).

> [!IMPORTANT]
> **Single Source of Truth Architecture**:
> Both the live website and the Flutter mobile app communicate with the exact same live backend instance and SQLite database.
> - **Same Accounts**: Credentials registered on web work instantly on mobile and vice versa.
> - **Same Catalog & Stock**: Both read real-time inventory from `products` and `categories` tables.
> - **Same Orders**: Purchases on either web or mobile app write to the shared `orders` table.
> - **Same Loyalty Points**: Points (10% cash-back) are computed from the shared order history.

---

## Authentication & Session Architecture

- **Session Handling**: Cookie-based authentication (`session` cookie set by Flask).
- **Header**: Standard HTTP request with `Cookie` header containing `session=<flask_session_token>`.
- **Content-Type**: `application/json` for all POST/PUT requests.
- **Base URL**: Default `https://rama-store-3u49.onrender.com`, configurable via `--dart-define=BASE_URL=<url>`.

---

## 1. Authentication Endpoints

### 1.1 Login with Password
- **Endpoint**: `POST /api/auth/login`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
```json
{
  "email_or_phone": "customer@ramastore.com",
  "password": "Password123"
}
```
- **Response Success (200 OK)**:
```json
{
  "message": "Login successful.",
  "user": {
    "email_or_phone": "customer@ramastore.com",
    "fullname": "Customer Name",
    "role": "customer"
  }
}
```

---

### 1.2 Registration (Triggers OTP)
- **Endpoint**: `POST /api/auth/register`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "Password123"
}
```
- **Response Success (200 OK)**:
```json
{
  "message": "Verification code has been sent successfully.",
  "otp_sent": true,
  "debug_otp": "482910"
}
```

---

### 1.3 OTP Verification (Completes Registration & Logs In)
- **Endpoint**: `POST /api/auth/verify_otp`
- **Request Body**:
```json
{
  "otp": "482910"
}
```

---

### 1.4 Passwordless Login OTP Request
- **Endpoint**: `POST /api/auth/login-otp-request`
- **Request Body**:
```json
{
  "email_or_phone": "john@example.com"
}
```

---

### 1.5 Passwordless Login OTP Verify
- **Endpoint**: `POST /api/auth/login-otp-verify`
- **Request Body**:
```json
{
  "otp": "654321"
}
```

---

### 1.6 Check Session Status
- **Endpoint**: `GET /api/auth/status`
- **Response (200 OK)**:
```json
{
  "authenticated": true,
  "user": {
    "email_or_phone": "john@example.com",
    "fullname": "johndoe",
    "role": "customer"
  }
}
```

---

### 1.7 Logout
- **Endpoint**: `POST /api/auth/logout`

---

## 2. Catalog & Products Endpoints

### 2.1 Fetch Store Products (Public Catalog)
- **Endpoint**: `GET /api/store/products`
- **Query Parameters**: `page`, `per_page`, `search`, `category_id`, `max_price`

---

### 2.2 Fetch Categories Tree
- **Endpoint**: `GET /api/categories`

---

### 2.3 Store Announcements & Offers
- **Endpoint**: `GET /api/announcements`

---

## 3. Checkout & Orders Endpoints

### 3.1 Create Checkout Session
- **Endpoint**: `POST /api/checkout` (Auth required)
- **Request Body**:
```json
{
  "cart": [
    { "id": 1, "qty": 2 },
    { "id": 4, "qty": 1 }
  ],
  "shipping_address": "123 Main Street, Sector 5, City"
}
```

---

### 3.2 Process Payment Sandbox
- **Endpoint**: `POST /api/payment/process` (Auth required)
- **Request Body**:
```json
{
  "tracking_number": "RAMA-8F92A0",
  "card_number": "4532111122223333",
  "cvv": "123",
  "expiry": "12/28"
}
```

---

### 3.3 Customer Order History
- **Endpoint**: `GET /api/orders/history` (Auth required)

---

## 4. Shared Live Backend Loyalty Points Policy

Points (10% cashback) are derived directly from completed customer order totals in table `orders` for the logged-in user, guaranteeing zero divergence between the website and the mobile app.
