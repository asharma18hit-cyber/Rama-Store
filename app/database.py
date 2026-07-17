# app/database.py
import sqlite3
import os
import random
import re
from contextlib import contextmanager

class InsufficientStockError(Exception):
    """Raised when there is not enough stock for a product."""
    pass

class DuplicateSKUError(Exception):
    """Raised when trying to add a product with an existing SKU."""
    pass

class DuplicateUserError(Exception):
    """Raised when trying to register a username/email that already exists."""
    pass

@contextmanager
def get_db_connection(db_path):
    """Context manager for SQLite database connection."""
    conn = sqlite3.connect(db_path, timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def init_db(db_path, schema_path):
    """Initializes SQLite database and executes Phase 6 table/column migrations automatically."""
    db_exists = os.path.exists(db_path)
    
    # 1. Run migrations first if database exists, protecting against data loss
    if db_exists:
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            
            # Check users table structure
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='users'")
            if cursor.fetchone():
                cursor.execute("PRAGMA table_info(users)")
                cols = [col[1] for col in cursor.fetchall()]
                if 'username' not in cols:
                    print("Migrating users table to support username & email...")
                    conn.execute("ALTER TABLE users RENAME TO users_backup;")
            
            # Check products table structure
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='products'")
            if cursor.fetchone():
                cursor.execute("PRAGMA table_info(products)")
                cols = [col[1] for col in cursor.fetchall()]
                if 'category_id' not in cols or 'status' not in cols:
                    print("Migrating products table to support category_id & status VISIBILITY...")
                    conn.execute("ALTER TABLE products RENAME TO products_backup;")
            
            # Check categories table structure
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='categories'")
            if cursor.fetchone():
                cursor.execute("PRAGMA table_info(categories)")
                cols = [col[1] for col in cursor.fetchall()]
                if 'slug' not in cols:
                    print("Migrating categories table to support slug...")
                    conn.execute("ALTER TABLE categories RENAME TO categories_backup;")

    # 2. Execute schema scripts (create missing tables & indexes)
    with open(schema_path, 'r', encoding='utf-8') as f:
        schema_sql = f.read()
    
    with get_db_connection(db_path) as conn:
        conn.executescript(schema_sql)

    # 3. Perform data transfer migrations
    if db_exists:
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            
            # Migrate Users Data
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='users_backup'")
            if cursor.fetchone():
                print("Transferring users account database...")
                cursor.execute("SELECT id, email_or_phone, password_hash, fullname, role, created_at FROM users_backup")
                old_users = cursor.fetchall()
                for row in old_users:
                    val = row['email_or_phone']
                    username = val.split('@')[0] if '@' in val else val
                    # Normalize role to lowercase matching Phase 6 check constraint
                    role_normalized = 'admin' if row['role'].lower() == 'admin' else 'customer'
                    email = val if '@' in val else f"{val}@ramastore.com"
                    
                    cursor.execute(
                        """
                        INSERT OR IGNORE INTO users (id, username, email, password_hash, role, created_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        (row['id'], username, email, row['password_hash'], role_normalized, row['created_at'])
                    )
                conn.execute("DROP TABLE users_backup;")
            
            # Migrate Categories & Products
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='products_backup'")
            if cursor.fetchone():
                print("Transferring catalog products and categories database...")
                
                # Check for categories_backup
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='categories_backup'")
                has_old_cats = cursor.fetchone()
                
                if has_old_cats:
                    cursor.execute("SELECT id, name FROM categories_backup")
                    for cat in cursor.fetchall():
                        slug = cat['name'].lower().replace(' ', '-')
                        cursor.execute("INSERT OR IGNORE INTO categories (id, name, slug) VALUES (?, ?, ?)", (cat['id'], cat['name'], slug))
                    conn.execute("DROP TABLE categories_backup;")
                
                # Retrieve unique flat categories from backup products if categories table is empty
                cursor.execute("SELECT COUNT(*) FROM categories")
                if cursor.fetchone()[0] == 0:
                    cursor.execute("SELECT DISTINCT category FROM products_backup WHERE category IS NOT NULL")
                    for row in cursor.fetchall():
                        cat_name = row['category']
                        slug = cat_name.lower().replace(' ', '-')
                        cursor.execute("INSERT OR IGNORE INTO categories (name, slug) VALUES (?, ?)", (cat_name, slug))
                
                # Copy products, translating category text to category_id
                cursor.execute("SELECT id, sku, name, category, purchase_price, selling_price, stock, image_url, created_at FROM products_backup")
                for row in cursor.fetchall():
                    # Lookup category id
                    cursor.execute("SELECT id FROM categories WHERE name = ?", (row['category'],))
                    cat_row = cursor.fetchone()
                    cat_id = cat_row[0] if cat_row else None
                    
                    cursor.execute(
                        """
                        INSERT OR IGNORE INTO products (id, sku, name, category_id, purchase_price, selling_price, stock, status, image_url, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (row['id'], row['sku'], row['name'], cat_id, row['purchase_price'], row['selling_price'], row['stock'], 'published', row['image_url'], row['created_at'])
                    )
                conn.execute("DROP TABLE products_backup;")
                
    # Populate default categories if missing
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM categories")
        if cursor.fetchone()[0] == 0:
            default_categories = [
                "Foods & Restaurants",
                "Bakery",
                "Grocery",
                "Medicine",
                "Books",
                "Copies",
                "Stationary",
                "Gift Store",
                "Sports"
            ]
            for cat in default_categories:
                slug = cat.lower().replace(' ', '-').replace('&', 'and')
                cursor.execute("INSERT OR IGNORE INTO categories (name, slug) VALUES (?, ?)", (cat, slug))
                
    print("Database initialization and schema validation complete.")

def add_category(db_path, name, slug=None, parent_id=None):
    """Creates a new hierarchical category node."""
    if not name or not name.strip():
        raise ValueError("Category name cannot be empty.")
    if not slug:
        slug = name.strip().lower().replace(' ', '-')
        # Strip special characters
        slug = re.sub(r'[^a-z0-9\-]', '', slug)
        
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        
        # Verify parent exists if set
        if parent_id:
            cursor.execute("SELECT id FROM categories WHERE id = ?", (parent_id,))
            if not cursor.fetchone():
                raise ValueError("Parent category ID not found.")
                
        try:
            cursor.execute(
                "INSERT INTO categories (name, slug, parent_id) VALUES (?, ?, ?)",
                (name.strip(), slug, parent_id)
            )
            return cursor.lastrowid
        except sqlite3.IntegrityError:
            # Slug duplicate check
            cursor.execute("SELECT id FROM categories WHERE slug = ?", (slug,))
            row = cursor.fetchone()
            if row:
                return row[0] # Return existing ID
            raise

def get_categories(db_path):
    """Retrieves all category nodes."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, slug, parent_id FROM categories ORDER BY name ASC")
        return [dict(row) for row in cursor.fetchall()]

def add_product(db_path, sku, name, category_id, purchase_price, selling_price, stock, status='published', image_url=None):
    """Adds a new product to the catalog (Admin only)."""
    if not sku or not sku.strip():
        raise ValueError("SKU cannot be empty.")
    if not name or not name.strip():
        raise ValueError("Product name cannot be empty.")
    if purchase_price < 0 or selling_price < 0:
        raise ValueError("Prices cannot be negative.")
    if stock < 0:
        raise ValueError("Stock quantity cannot be negative.")
    if status not in ['draft', 'published']:
        raise ValueError("Status must be either 'draft' or 'published'.")

    try:
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            
            # Verify category_id exists
            if category_id:
                cursor.execute("SELECT id FROM categories WHERE id = ?", (category_id,))
                if not cursor.fetchone():
                    raise ValueError("Category ID not found.")
            
            cursor.execute(
                """
                INSERT INTO products (sku, name, category_id, purchase_price, selling_price, stock, status, image_url)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (sku.strip(), name.strip(), category_id, purchase_price, selling_price, stock, status, image_url)
            )
            return cursor.lastrowid
    except sqlite3.IntegrityError as e:
        if "UNIQUE constraint failed: products.sku" in str(e):
            raise DuplicateSKUError(f"A product with SKU '{sku}' already exists.")
        raise e

def get_products(db_path, page=1, per_page=10, search_query="", category_id=None, max_price=None, status_filter=None):
    """Fetches filtered catalog products. Public storefront only views 'published' items."""
    offset = (page - 1) * per_page
    where_clauses = []
    params = []
    
    if search_query:
        where_clauses.append("(p.name LIKE ? OR p.sku LIKE ?)")
        q = f"%{search_query}%"
        params.extend([q, q])
        
    if category_id is not None:
        # Include products matching this category OR any of its nested children!
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, parent_id FROM categories")
            all_cats = [dict(r) for r in cursor.fetchall()]
            
            # Recursive check to find all children IDs
            target_ids = [category_id]
            added = True
            while added:
                added = False
                for cat in all_cats:
                    if cat['parent_id'] in target_ids and cat['id'] not in target_ids:
                        target_ids.append(cat['id'])
                        added = True
                        
            placeholders = ",".join(["?"] * len(target_ids))
            where_clauses.append(f"p.category_id IN ({placeholders})")
            params.extend(target_ids)
        
    if max_price is not None:
        where_clauses.append("p.selling_price <= ?")
        params.append(max_price)
        
    if status_filter:
        where_clauses.append("p.status = ?")
        params.append(status_filter)
        
    where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
    
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        
        # Get count
        count_query = f"SELECT COUNT(*) FROM products p {where_sql}"
        cursor.execute(count_query, params)
        total_count = cursor.fetchone()[0]
        
        # Get data with category name mapping
        data_params = params.copy()
        data_params.extend([per_page, offset])
        data_query = f"""
            SELECT p.id, p.sku, p.name, p.category_id, c.name AS category, p.purchase_price, p.selling_price, p.stock, p.status, p.image_url, p.created_at
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            {where_sql}
            ORDER BY p.name ASC
            LIMIT ? OFFSET ?
        """
        cursor.execute(data_query, data_params)
        products = [dict(row) for row in cursor.fetchall()]
        
    return {
        "products": products,
        "total_count": total_count,
        "page": page,
        "per_page": per_page,
        "total_pages": (total_count + per_page - 1) // per_page if total_count > 0 else 1
    }

def update_product(db_path, product_id, sku, name, category_id, purchase_price, selling_price, stock, status='published', image_url=None):
    """Updates product catalog records (Admin only)."""
    if purchase_price < 0 or selling_price < 0:
        raise ValueError("Prices cannot be negative.")
    if stock < 0:
        raise ValueError("Stock quantity cannot be negative.")
    if not name or not name.strip():
        raise ValueError("Product name cannot be empty.")
    if not sku or not sku.strip():
        raise ValueError("SKU cannot be empty.")
    if status not in ['draft', 'published']:
        raise ValueError("Status must be either 'draft' or 'published'.")

    try:
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            
            # Verify category_id exists
            if category_id:
                cursor.execute("SELECT id FROM categories WHERE id = ?", (category_id,))
                if not cursor.fetchone():
                    raise ValueError("Category ID not found.")
            
            cursor.execute(
                """
                UPDATE products 
                SET sku = ?, name = ?, category_id = ?, purchase_price = ?, selling_price = ?, stock = ?, status = ?, image_url = ?
                WHERE id = ?
                """,
                (sku.strip(), name.strip(), category_id, purchase_price, selling_price, stock, status, image_url, product_id)
            )
            return cursor.rowcount > 0
    except sqlite3.IntegrityError as e:
        if "UNIQUE constraint failed: products.sku" in str(e):
            raise DuplicateSKUError(f"A product with SKU '{sku}' already exists.")
        raise e

def delete_product(db_path, product_id):
    """Deletes product records."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM products WHERE id = ?", (product_id,))
        return cursor.rowcount > 0

def search_products_suggest(db_path, query, limit=5):
    """POS Autocomplete search query lookup."""
    if not query or not query.strip():
        return []
    
    q = f"%{query.strip()}%"
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT p.id, p.sku, p.name, p.selling_price, p.stock, p.image_url, c.name AS category
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.name LIKE ? OR p.sku LIKE ?
            ORDER BY p.name ASC
            LIMIT ?
            """,
            (q, q, limit)
        )
        return [dict(row) for row in cursor.fetchall()]

def complete_sale(db_path, cart_items, tax_rate_percent=18.0, user_id=None, shipping_address=None):
    """POS Direct Walk-in cashier sale completed directly."""
    if not cart_items:
        raise ValueError("Cart is empty.")
        
    subtotal = 0.0
    items_to_process = []
    
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        
        for item in cart_items:
            product_id = item.get("product_id")
            qty = int(item.get("quantity", 0))
            
            cursor.execute("SELECT id, sku, name, selling_price, stock FROM products WHERE id = ?", (product_id,))
            prod = cursor.fetchone()
            if not prod:
                raise ValueError(f"Product ID {product_id} not found.")
                
            prod = dict(prod)
            if prod['stock'] < qty:
                raise InsufficientStockError(f"Insufficient stock for '{prod['name']}'.")
                
            # Deduct stock
            cursor.execute("UPDATE products SET stock = stock - ? WHERE id = ?", (qty, product_id))
            
            price = prod["selling_price"]
            item_total = price * qty
            subtotal += item_total
            
            items_to_process.append({
                "product_id": product_id,
                "name": prod["name"],
                "sku": prod["sku"],
                "quantity": qty,
                "price": price,
                "total": item_total
            })
            
        tax_amount = round(subtotal * (tax_rate_percent / 100.0), 2)
        total_amount = round(subtotal + tax_amount, 2)
        tracking_number = f"TRK-{random.randint(10000000, 99999999)}"
        
        cursor.execute(
            """
            INSERT INTO orders (tracking_number, customer_id, total_amount, tax_amount, shipping_address, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (tracking_number, user_id, total_amount, tax_amount, shipping_address, 'Delivered')
        )
        order_id = cursor.lastrowid
        
        for item in items_to_process:
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES (?, ?, ?, ?)",
                (order_id, item["product_id"], item["quantity"], item["price"])
            )
            
        cursor.execute("SELECT created_at FROM orders WHERE id = ?", (order_id,))
        created_at = cursor.fetchone()[0]
        
    return {
        "sale_id": order_id,
        "sale_date": created_at,
        "subtotal": round(subtotal, 2),
        "tax_amount": tax_amount,
        "tax_rate": tax_rate_percent,
        "total_amount": total_amount,
        "items": items_to_process,
        "status": 'Delivered',
        "shipping_address": shipping_address,
        "tracking_number": tracking_number
    }

def create_checkout_session(db_path, cart_items, tax_rate_percent=18.0, user_id=None, shipping_address=None):
    """Locks product inventory and registers order in Pending payment state."""
    if not cart_items:
        raise ValueError("Cart is empty.")
        
    subtotal = 0.0
    items_to_process = []
    tracking_number = f"TRK-{random.randint(10000000, 99999999)}"
    
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        
        for item in cart_items:
            product_id = item.get("product_id")
            qty = int(item.get("quantity", 0))
            
            cursor.execute("SELECT id, sku, name, selling_price, stock FROM products WHERE id = ?", (product_id,))
            prod = cursor.fetchone()
            if not prod:
                raise ValueError(f"Product ID {product_id} not found.")
                
            prod = dict(prod)
            if prod['stock'] < qty:
                raise InsufficientStockError(f"Insufficient stock for '{prod['name']}'.")
                
            # Lock stock
            cursor.execute("UPDATE products SET stock = stock - ? WHERE id = ?", (qty, product_id))
            
            price = prod["selling_price"]
            item_total = price * qty
            subtotal += item_total
            
            items_to_process.append({
                "product_id": product_id,
                "name": prod["name"],
                "sku": prod["sku"],
                "quantity": qty,
                "price": price,
                "total": item_total
            })
            
        tax_amount = round(subtotal * (tax_rate_percent / 100.0), 2)
        total_amount = round(subtotal + tax_amount, 2)
        
        cursor.execute(
            """
            INSERT INTO orders (tracking_number, customer_id, total_amount, tax_amount, shipping_address, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (tracking_number, user_id, total_amount, tax_amount, shipping_address, 'Pending')
        )
        order_id = cursor.lastrowid
        
        for item in items_to_process:
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES (?, ?, ?, ?)",
                (order_id, item["product_id"], item["quantity"], item["price"])
            )
            
        cursor.execute("SELECT created_at FROM orders WHERE id = ?", (order_id,))
        created_at = cursor.fetchone()[0]
        
    return {
        "sale_id": order_id,
        "sale_date": created_at,
        "subtotal": round(subtotal, 2),
        "tax_amount": tax_amount,
        "tax_rate": tax_rate_percent,
        "total_amount": total_amount,
        "items": items_to_process,
        "status": 'Pending',
        "shipping_address": shipping_address,
        "tracking_number": tracking_number
    }

def update_order_payment_status(db_path, tracking_number, payment_success):
    """Confirms payment intent and switches status to Paid, or fails and rolls back stock levels."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, status FROM orders WHERE tracking_number = ?", (tracking_number,))
        order_row = cursor.fetchone()
        if not order_row:
            return False
            
        order = dict(order_row)
        if order['status'] != 'Pending':
            return True
            
        if payment_success:
            cursor.execute("UPDATE orders SET status = 'Paid' WHERE id = ?", (order['id'],))
        else:
            # Rollback stock level
            cursor.execute("SELECT product_id, quantity FROM order_items WHERE order_id = ?", (order['id'],))
            for item in cursor.fetchall():
                cursor.execute("UPDATE products SET stock = stock + ? WHERE id = ?", (item['quantity'], item['product_id']))
                
            cursor.execute("UPDATE orders SET status = 'Cancelled' WHERE id = ?", (order['id'],))
            
    return True

def get_user_orders(db_path, user_id):
    """Retrieves customer purchase orders timeline history."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, total_amount, tax_amount, shipping_address, status, created_at, tracking_number FROM orders WHERE customer_id = ? ORDER BY created_at DESC, id DESC",
            (user_id,)
        )
        orders = [dict(row) for row in cursor.fetchall()]
        
        for order in orders:
            cursor.execute(
                """
                SELECT oi.product_id, oi.quantity, oi.price_at_purchase AS price, p.name, p.sku
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                WHERE oi.order_id = ?
                """,
                (order["id"],)
            )
            order["items"] = [dict(row) for row in cursor.fetchall()]
    return orders

def update_order_status(db_path, order_id, new_status):
    """Transitions orders through OMS fulfillment checkpoints."""
    valid_statuses = ['Pending', 'Paid', 'Shipped', 'Delivered', 'Cancelled']
    if new_status not in valid_statuses:
        raise ValueError(f"Invalid order status '{new_status}'")
        
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE orders SET status = ? WHERE id = ?", (new_status, order_id))
        return cursor.rowcount > 0

def get_all_orders_admin(db_path):
    """Admin OMS list fetcher."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT o.id, o.total_amount, o.tax_amount, o.shipping_address, o.status, o.created_at, o.tracking_number, u.username, u.email
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            ORDER BY o.created_at DESC, o.id DESC
            """
        )
        orders = [dict(row) for row in cursor.fetchall()]
        
        for order in orders:
            cursor.execute(
                """
                SELECT oi.quantity, oi.price_at_purchase AS price, p.name
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                WHERE oi.order_id = ?
                """,
                (order["id"],)
            )
            order["items"] = [dict(row) for row in cursor.fetchall()]
    return orders

def create_user(db_path, username, email, password_hash, role="customer"):
    """Registers user checking constraints."""
    if not username or not username.strip():
        raise ValueError("Username is required.")
    if not email or not email.strip():
        raise ValueError("Email is required.")
    if role not in ['admin', 'customer']:
        raise ValueError("Role must be 'admin' or 'customer'.")
        
    try:
        with get_db_connection(db_path) as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)",
                (username.strip(), email.strip().lower(), password_hash, role)
            )
            return cursor.lastrowid
    except sqlite3.IntegrityError as e:
        if "UNIQUE constraint failed: users.username" in str(e):
            raise DuplicateUserError("Username is already taken.")
        if "UNIQUE constraint failed: users.email" in str(e):
            raise DuplicateUserError("Email address is already registered.")
        raise e

def get_user_by_identifier(db_path, identifier):
    """Retrieves user row matching username or email address."""
    if not identifier or not identifier.strip():
        return None
    val = identifier.strip().lower()
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, username, email, password_hash, role, created_at FROM users WHERE LOWER(username) = ? OR LOWER(email) = ?",
            (val, val)
        )
        row = cursor.fetchone()
        return dict(row) if row else None

def update_user_password(db_path, identifier, new_password_hash):
    """Resets user password hash via identity confirmation matches."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE users SET password_hash = ? WHERE LOWER(username) = ? OR LOWER(email) = ?",
            (new_password_hash, identifier.strip().lower(), identifier.strip().lower())
        )
        return cursor.rowcount > 0

def get_dashboard_metrics(db_path):
    """Retrieves store metrics."""
    with get_db_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM products")
        total_products = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM products WHERE stock < 5")
        low_stock_count = cursor.fetchone()[0]
        
        cursor.execute(
            """
            SELECT SUM(total_amount) 
            FROM orders 
            WHERE status != 'Pending' AND status != 'Cancelled' AND date(created_at) = date('now', 'localtime')
            """
        )
        row = cursor.fetchone()
        today_revenue = row[0] if row and row[0] is not None else 0.0
        
    return {
        "total_products": total_products,
        "low_stock_count": low_stock_count,
        "today_revenue": round(today_revenue, 2)
    }
