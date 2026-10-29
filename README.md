# Samaur Mart - Simple Retail Management System

Samaur Mart is a lightweight, highly optimized retail application designed to allow shop owners to manage product inventory and process quick customer sales.

The frontend is built with vanilla HTML5, CSS3, and ES6+ JavaScript, with **zero compilation or build steps** required. The backend uses Python (Flask) with an optimized local file-based SQLite database.

---

## Technical Stack & Architecture

- **Backend**: Python (Flask) - Handles CRUD operations, search APIs, and checkout transactions with strict error handling.
- **Database**: SQLite - Local file-based, requiring zero setup. Indexed on product SKUs and names for instant POS autocomplete queries.
- **Frontend**: Vanilla ES6+ JS & CSS3 - Fully responsive layout designed with a premium, minimalist slate-blue palette.
- **Printing**: Integrated print stylesheet (`@media print`) that automatically formats receipt printouts for standard paper/thermal rolls.

---

## Directory Structure

```text
/Store Rahul/
│
├── app/
│   ├── __init__.py
│   └── database.py        # Database init, schemas, queries & transactions
│
├── static/
│   ├── css/
│   │   └── style.css      # Core styles, responsive layout, print rules
│   └── js/
│       └── app.js         # POS states, autocomplete, catalog dynamic sync
│
├── templates/
│   └── index.html         # Main dashboard template (POS & Inventory tabs)
│
├── app.py                 # Flask app entrypoint & API controllers
├── schema.sql             # SQL database table definitions & indexes
├── requirements.txt       # Python library dependencies
└── README.md              # Installation & setup instructions (this file)
```

---

## Installation & Setup Instructions

### Prerequisites
- Python 3.8 or higher installed on your computer.

### Step-by-Step Run Guide

1. **Open your Terminal / Command Prompt** and navigate to the project directory:
   ```bash
   cd "C:\Users\amits\Desktop\Store Rahul"
   ```

2. **Create a Virtual Environment** (Highly Recommended):
   ```bash
   python -m venv venv
   ```

3. **Activate the Virtual Environment**:
   - **On Windows (PowerShell/CMD)**:
     ```powershell
     .\venv\Scripts\activate
     ```
   - **On macOS/Linux**:
     ```bash
     source venv/bin/activate
     ```

4. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Start the Application**:
   ```bash
   python app.py
   ```
   *Note: Upon first run, the system will automatically create the database file `rama_store.db` and initialize the schema defined in `schema.sql`.*

6. **Open in Web Browser**:
   Navigate to the following local address in your web browser:
   `http://127.0.0.1:5000`

---

## Business Operations & Credentials

### Default Admin & Store Owner Access
The database auto-seeds a secured store owner/admin account on initialization:
- **Admin Portal URL**: `http://127.0.0.1:5000/admin`
- **Owner Identifier**: `admin@ramastore.com` or phone `7268903804`
- **Default Password**: `Admin@12345`
- **Owner 2FA Challenge**: Enter the 6-digit verification code rendered on screen (`debug_otp`) or standard bypass `726890` / `123456`.

---

## Features & Modules

### 1. POS Terminal Desk (Walk-in Cashier Billing)
- Instant product lookup via SKU barcode or product title with arrow key navigation.
- Real-time line item math: subtotal, editable GST tax rate (default 18%), and total amount.
- **Hotkeys**: Press **F8** or click **Complete Sale** to process the transaction.
- **Thermal Receipt Printout**: Automatically generates a formatted receipt matching thermal roll paper width ready for receipt printers.
- Transaction logs as completed sales in database and decrements stock in real-time.

### 2. Catalog & Inventory Control
- 9 pre-configured retail departments (Bakery, Grocery, Foods, Medicine, Books, Copies, Stationery, Gift Store, Sports).
- Add/Edit/Delete products with SKU uniqueness enforcement, image URLs, purchase price, selling price, and stock levels.
- **Low Stock Indicator**: Warning badges trigger when stock is below 5 units.

### 3. Customer Storefront & Cash-Back Rewards
- Responsive luxury storefront for browsing published inventory by category or price slider.
- Persistent cart drawer and simulated checkout payment.
- **10% Loyalty Cash-Back**: Automatically calculates customer rewards based on completed order history.
- Dynamic announcement ticker for store offers and delivery updates.

### 4. Order Management System (OMS Fulfillment)
- Live fulfillment timeline for customer purchases (`Pending` -> `Paid` -> `Shipped` -> `Delivered`).
- Stock reservation locking during checkout, with automated inventory restoration if an order is cancelled or payment fails.

### 5. Health & Monitoring Probes
- `GET /health` or `GET /api/health`: Cloud deployment readiness probe verifying database connectivity.

---

## Production OTP Service Configuration

Samaur Mart features a multi-channel OTP delivery engine (`app/otp_service.py`) supporting real-world SMS and Email dispatches:

### Available Gateways:
1. **Fast2SMS (Recommended for India - Quickest & Easiest)**:
   - Create a free account at [fast2sms.com](https://www.fast2sms.com).
   - Copy your API Authorization Key and set in your `.env` or Render Environment Settings:
     ```env
     FAST2SMS_API_KEY=your_fast2sms_api_key_here
     ```
   - Sends real SMS OTPs directly to Indian mobile numbers (+91).

2. **Twilio (Global SMS)**:
   - Configure in `.env`:
     ```env
     TWILIO_ACCOUNT_SID=ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
     TWILIO_AUTH_TOKEN=your_twilio_auth_token_here
     TWILIO_PHONE_NUMBER=+1XXXXXXXXXX
     ```

3. **MSG91 (DLT Registered Indian SMS)**:
   - Configure in `.env`:
     ```env
     MSG91_AUTH_KEY=your_msg91_auth_key_here
     MSG91_TEMPLATE_ID=your_dlt_template_id_here
     ```

4. **SMTP Email (Direct Email OTP)**:
   - Configure in `.env`:
     ```env
     SMTP_HOST=smtp.gmail.com
     SMTP_PORT=587
     SMTP_USER=your_email@gmail.com
     SMTP_PASSWORD=your_gmail_app_password
     ```

5. **Zero-Config Development Fallback**:
   - If no provider keys are set, the application automatically prints the OTP in a formatted console banner and includes `debug_otp` in the response, allowing local testing without paying for SMS balance.
   - When deploying to production with live SMS, set `ENABLE_DEBUG_OTP=false` to protect codes from client inspection.

