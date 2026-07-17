# Rama Store - Simple Retail Management System

Rama Store is a lightweight, highly optimized single-user desktop or local web application designed to allow shop owners to manage product inventory and process quick customer sales.

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

## How to Use

### 1. Inventory Catalog Management
- Navigate to the **Inventory Catalog** tab in the top header.
- Add products by filling in details: Product Name, unique SKU/Barcode ID, Category, Purchase Price, Selling Price, and current stock quantity.
- Keep track of inventory items in the paginated catalog table.
- **Low Stock Indicator**: Products with less than 5 units in stock will automatically render with a red low stock warning badge.
- Click the edit button (✏️) next to any product to quickly change price, name, SKU, category, or add more stock units.

### 2. POS Terminal (Billing Screen)
- Navigate to the **POS Terminal** tab in the header.
- Start typing a product's name or SKU code into the search box. An instant suggestion dropdown will search results.
- Use the **Arrow Keys (Up/Down)** and **Enter** to quickly select and add an item to the billing cart.
- Inside the cart, adjust quantity counts using the `-` or `+` buttons or type directly in the input field.
- **Real-Time Billing Math**: Tax rate (%) is editable on the screen (defaults to 10%). Subtotal, Tax Amount, and Grand Total update automatically as items or quantities change.
- Click **Complete Sale** or press **F8** on your keyboard to save.
- **Transaction Receipt**: A receipt modal pop-up is shown instantly, ready to print (thermal format) or close to clear the cart for the next customer sale.
- **Stock Depletion**: If checkout quantity exceeds inventory levels, transaction is aborted and a warning toast alert is displayed.
