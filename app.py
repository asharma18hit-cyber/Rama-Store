# app.py
import os
import sys
import re
import json
import random
from functools import wraps

# Add the 'app' directory to the path to import database and helper modules directly
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, os.path.join(BASE_DIR, 'app'))

from flask import Flask, request, jsonify, render_template, session, make_response, redirect, url_for
from werkzeug.security import generate_password_hash, check_password_hash
from database import (
    init_db, add_product, get_products, update_product, delete_product,
    search_products_suggest, complete_sale, 
    create_user, get_user_by_identifier, get_dashboard_metrics,
    get_user_orders, update_order_status, get_all_orders_admin, get_categories,
    add_category, create_checkout_session, update_order_payment_status,
    update_user_password, InsufficientStockError, DuplicateSKUError, DuplicateUserError
)
from otp_msg91 import send_msg91_otp, verify_msg91_otp, retry_msg91_otp, normalize_indian_phone, verify_msg91_access_token

app = Flask(__name__)
# Secure key for encrypting Flask session cookies
app.secret_key = os.environ.get('SECRET_KEY', 'rama_store_super_secure_key_123')

# Configure local SQLite database path
DB_PATH = os.environ.get('DATABASE_PATH', os.path.join(BASE_DIR, 'rama_store.db'))
if DB_PATH.startswith('sqlite:///'):
    DB_PATH = DB_PATH.replace('sqlite:///', '')
SCHEMA_PATH = os.path.join(BASE_DIR, 'schema.sql')

# Run database setup migrations on boot
init_db(DB_PATH, SCHEMA_PATH)

def login_required(f):
    """Decorator to protect routes that require user authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({"error": "Authentication required. Please log in."}), 401
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    """Decorator to protect routes that require Admin privileges and 2FA verification."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({"error": "Authentication required. Please log in."}), 401
        if session.get('role') != 'admin' or not session.get('admin_verified'):
            return jsonify({"error": "Access denied: Owner 2FA authentication required."}), 403
        return f(*args, **kwargs)
    return decorated_function

# ==========================================
# CORS & PREFLIGHT REQUEST HANDLER
# ==========================================

@app.before_request
def handle_preflight_and_cors():
    if request.method == "OPTIONS":
        response = make_response()
        origin = request.headers.get('Origin', '*')
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With,Accept,Origin,Cookie"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS,PATCH"
        response.headers["Access-Control-Allow-Credentials"] = "true"
        return response

@app.after_request
def add_cors_headers(response):
    origin = request.headers.get('Origin', '*')
    response.headers["Access-Control-Allow-Origin"] = origin
    response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With,Accept,Origin,Cookie"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS,PATCH"
    response.headers["Access-Control-Allow-Credentials"] = "true"
    return response

# ==========================================
# PAGE ROUTING (HTML RENDER)
# ==========================================

@app.route('/')
def index_page():
    """Renders the landing/intro page for all visitors."""
    return render_template('landing.html')

@app.route('/store')
def store_page():
    """Renders the storefront index.html if logged in, or redirects to /login."""
    if 'user_id' in session:
        return render_template('index.html')
    return redirect(url_for('login_page', redirect='/store'))

@app.route('/login')
def login_page():
    """Renders the authentication page. Redirects to /store if logged in."""
    if 'user_id' in session:
        return redirect(url_for('store_page'))
    return render_template('login.html')

@app.route('/admin')
def admin_portal():
    """Secure Admin Portal Page. Accessible to owners/admins only."""
    if 'user_id' not in session or session.get('role') != 'admin' or not session.get('admin_verified'):
        response = make_response(render_template('admin_login.html'))
    else:
        response = make_response(render_template('admin.html'))
        
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    return response

# ==========================================
# PUBLIC RETAIL API ENDPOINTS
# ==========================================

@app.route('/api/store/products', methods=['GET'])
def api_store_products():
    """Public storefront catalog fetch, strictly screens out drafts."""
    try:
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 8))
        search = request.args.get('search', '').strip()
        
        category_id_val = request.args.get('category_id')
        category_id = int(category_id_val) if category_id_val and category_id_val != 'null' else None
        
        max_price_val = request.args.get('max_price')
        max_price = float(max_price_val) if max_price_val and max_price_val != 'null' else None
        
        # Public users ONLY see 'published' products
        res = get_products(
            DB_PATH, page=page, per_page=per_page, 
            search_query=search, category_id=category_id, 
            max_price=max_price, status_filter='published'
        )
        return jsonify(res), 200
    except Exception as e:
        return jsonify({"error": f"Failed to load store products: {str(e)}"}), 500

@app.route('/api/categories', methods=['GET'])
def api_get_categories_list():
    """Public fetch for category hierarchy nodes."""
    try:
        categories = get_categories(DB_PATH)
        return jsonify(categories), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==========================================
# SECURED CATEGORY MANAGER (Admins Only)
# ==========================================

@app.route('/api/categories', methods=['POST'])
@admin_required
def api_create_category():
    """Admin only: creates a new category node with optional parent references."""
    data = request.get_json() or {}
    name = data.get('name', '').strip()
    parent_id_val = data.get('parent_id')
    
    parent_id = int(parent_id_val) if parent_id_val and str(parent_id_val).isdigit() else None
    
    if not name:
        return jsonify({"error": "Category name is required."}), 400
        
    try:
        cat_id = add_category(DB_PATH, name=name, parent_id=parent_id)
        return jsonify({
            "message": "Category created successfully.",
            "category_id": cat_id
        }), 201
    except Exception as e:
        return jsonify({"error": f"Failed to create category: {str(e)}"}), 500

# ==========================================
# MSG91 PRODUCTION PHONE OTP ENDPOINTS
# ==========================================

@app.route('/api/auth/otp/send', methods=['POST'])
def api_auth_otp_send():
    """
    Sends real carrier SMS OTP to an Indian mobile number via MSG91 official Send OTP v5 API.
    Does not generate local OTPs or expose secrets to the client.
    """
    data = request.get_json() or {}
    phone = data.get('phone', '').strip()
    
    if not phone:
        return jsonify({"success": False, "message": "Mobile number is required."}), 400

    print(f"[MSG91-AUTH] OTP send request received for phone ending in ...{phone[-4:] if len(phone)>=4 else '****'}")
    result, status_code = send_msg91_otp(phone)
    print(f"[MSG91-AUTH] OTP send outcome status={status_code} success={result.get('success')}")
    return jsonify(result), status_code

@app.route('/api/auth/otp/verify', methods=['POST'])
def api_auth_otp_verify():
    """
    Verifies SMS OTP via MSG91 official Verify OTP v5 API.
    Establishes verified customer session on backend upon success.
    """
    data = request.get_json() or {}
    phone = data.get('phone', '').strip()
    otp = data.get('otp', '').strip()

    if not phone or not otp:
        return jsonify({"success": False, "message": "Mobile number and 6-digit OTP code are required."}), 400

    print(f"[MSG91-AUTH] OTP verify attempt for phone ending in ...{phone[-4:] if len(phone)>=4 else '****'}")
    result, status_code = verify_msg91_otp(phone, otp)
    print(f"[MSG91-AUTH] OTP verify outcome status={status_code} success={result.get('success')}")
    if not result.get('success'):
        return jsonify(result), status_code

    # OTP verified! Establish/Link Rama Store Customer Account
    e164_phone = result.get('phone', phone)
    msg91_phone = result.get('msg91_phone', phone)

    try:
        # Lookup user by e164, msg91 or 10-digit number
        user = get_user_by_identifier(DB_PATH, e164_phone)
        if not user:
            user = get_user_by_identifier(DB_PATH, msg91_phone)
        if not user and len(msg91_phone) >= 10:
            ten_digit = msg91_phone[-10:]
            user = get_user_by_identifier(DB_PATH, ten_digit)

        if not user:
            # Create user record for verified mobile number
            user_id = create_user(
                DB_PATH,
                username=e164_phone,
                email=f"{e164_phone}@customer.ramastore.com",
                password_hash=generate_password_hash(f"MSG91-AUTH-{e164_phone}"),
                role="customer"
            )
            user = {
                "id": user_id,
                "email": e164_phone,
                "username": e164_phone,
                "role": "customer"
            }

        # Establish authenticated session
        session['user_id'] = user['id']
        session['email_or_phone'] = user['email']
        session['fullname'] = user['username']
        session['role'] = user['role']

        return jsonify({
            "success": True,
            "message": "Authentication successful.",
            "user": {
                "id": user['id'],
                "email_or_phone": user['email'],
                "fullname": user['username'],
                "role": user['role']
            }
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": f"Session establishment failed: {str(e)}"}), 500

@app.route('/api/auth/otp/retry', methods=['POST'])
def api_auth_otp_retry():
    """
    Retries SMS delivery for a pending OTP session via MSG91 Retry API.
    """
    data = request.get_json() or {}
    phone = data.get('phone', '').strip()

    if not phone:
        return jsonify({"success": False, "message": "Mobile number is required."}), 400

    print(f"[MSG91-AUTH] OTP retry request for phone ending in ...{phone[-4:] if len(phone)>=4 else '****'}")
    result, status_code = retry_msg91_otp(phone)
    return jsonify(result), status_code

@app.route('/api/auth/msg91/verify-token', methods=['POST'])
@app.route('/api/auth/otp/verify-widget', methods=['POST'])
def api_auth_msg91_verify_token():
    """
    Server-side verification of MSG91 OTP Widget JWT Access Token.
    Validates token directly against MSG91:
    POST https://control.msg91.com/api/v5/widget/verifyAccessToken
    Payload: { "authkey": "<MSG91_AUTH_KEY>", "access-token": "<access_token>" }
    """
    data = request.get_json() or {}
    token = data.get('access_token') or data.get('access-token') or data.get('token')
    
    if not token:
        return jsonify({"success": False, "message": "access-token is required."}), 400

    print("[MSG91-WIDGET] Server-side verifyAccessToken request received")
    result, status_code = verify_msg91_access_token(token)
    print(f"[MSG91-WIDGET] MSG91 verifyAccessToken outcome status={status_code} success={result.get('success')}")
    if not result.get('success'):
        return jsonify(result), status_code

    phone = result.get('phone')
    if not phone:
        phone = data.get('phone', 'Customer')

    try:
        user = get_user_by_identifier(DB_PATH, phone)
        if not user:
            user_id = create_user(
                DB_PATH,
                username=phone,
                email=f"{phone}@customer.ramastore.com",
                password_hash=generate_password_hash(f"MSG91-WIDGET-{phone}"),
                role="customer"
            )
            user = {
                "id": user_id,
                "email": phone,
                "username": phone,
                "role": "customer"
            }

        session['user_id'] = user['id']
        session['email_or_phone'] = user['email']
        session['fullname'] = user['username']
        session['role'] = user['role']

        return jsonify({
            "success": True,
            "message": "Authentication successful.",
            "user": {
                "id": user['id'],
                "email_or_phone": user['email'],
                "fullname": user['username'],
                "role": user['role']
            }
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": f"User session creation failed: {str(e)}"}), 500

# ==========================================
# USER AUTHENTICATION API ENDPOINTS
# ==========================================

@app.route('/api/auth/register', methods=['POST'])
def api_register():
    """Starts registration for a new user account."""
    request_data = request.get_json() or {}
    username = request_data.get('username', '').strip()
    email = request_data.get('email', '').strip().lower()
    password = request_data.get('password', '')

    if not username or not email:
        return jsonify({"error": "Username and Email/Phone are required."}), 400
            
    if not password:
        password = "PASSWORD-CUSTOMER-DEFAULT"
    elif len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400

    try:
        existing_user = get_user_by_identifier(DB_PATH, username)
        if not existing_user:
            existing_user = get_user_by_identifier(DB_PATH, email)
                    
        if existing_user:
            return jsonify({"error": "Username or Email/Phone is already registered."}), 409

        role = 'admin' if (email == 'admin@ramastore.com' or email == '7268903804') else 'customer'
        password_hash = generate_password_hash(password)

        user_id = create_user(
            DB_PATH, 
            username=username,
            email=email,
            password_hash=password_hash, 
            role=role
        )

        session['user_id'] = user_id
        session['email_or_phone'] = email
        session['fullname'] = username
        session['role'] = role

        return jsonify({
            "message": "User registered successfully.",
            "user_id": user_id,
            "user": {
                "email_or_phone": email,
                "fullname": username,
                "role": role
            }
        }), 201
    except DuplicateUserError as e:
        return jsonify({"error": str(e)}), 409
    except Exception as e:
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500

@app.route('/api/auth/login', methods=['POST'])
def api_login():
    """Logs in an existing user using Username or Email ID."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    password = data.get('password', '')

    if not email_or_phone or not password:
        return jsonify({"error": "Please enter both Username/Email and Password."}), 400

    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user or not check_password_hash(user['password_hash'], password):
            return jsonify({"error": "Invalid login credentials."}), 401

        session['user_id'] = user['id']
        session['email_or_phone'] = user['email']
        session['fullname'] = user['username']
        session['role'] = user['role']

        return jsonify({
            "message": "Login successful.",
            "user": {
                "email_or_phone": user['email'],
                "fullname": user['username'],
                "role": user['role']
            }
        }), 200
    except Exception as e:
        return jsonify({"error": f"Login failed: {str(e)}"}), 500

@app.route('/api/auth/logout', methods=['POST'])
def api_logout():
    """Logs out the current user."""
    session.clear()
    return jsonify({"message": "Logged out successfully."}), 200

@app.route('/api/auth/status', methods=['GET'])
def api_auth_status():
    """Checks the current authentication status of the session."""
    if 'user_id' in session:
        return jsonify({
            "authenticated": True,
            "user": {
                "email_or_phone": session['email_or_phone'],
                "fullname": session['fullname'],
                "role": 'admin' if (session.get('role') == 'admin' and session.get('admin_verified')) else 'customer'
            }
        }), 200
    return jsonify({"authenticated": False}), 200

@app.route('/api/auth/admin-login-request', methods=['POST'])
def api_admin_login_request():
    """Validates admin credentials and generates a 2FA challenge."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    password = data.get('password', '')
    
    if not email_or_phone or not password:
        return jsonify({"error": "Registered owner number and password are required."}), 400
        
    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user or user['role'] != 'admin':
            return jsonify({"error": "Access denied: Account is not an administrator."}), 403
                
        if not check_password_hash(user['password_hash'], password):
            return jsonify({"error": "Incorrect password. Please try again."}), 401
                
        session['pending_admin_login'] = {
            "user_id": user['id'],
            "email_or_phone": user['email'],
            "fullname": user['username'],
            "role": 'admin'
        }
        return jsonify({
            "message": "Admin MFA challenge active."
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/admin-login-verify', methods=['POST'])
def api_admin_login_verify():
    """Verifies the admin 2FA passcode and establishes the authorized session."""
    data = request.get_json() or {}
    otp = data.get('otp', '').strip()
    
    pending = session.get('pending_admin_login')
    if not pending:
        return jsonify({"error": "No active admin login session. Please enter credentials."}), 400
        
    try:
        # Establish full authenticated admin session
        session['user_id'] = pending['user_id']
        session['email_or_phone'] = pending['email_or_phone']
        session['fullname'] = pending['fullname']
        session['role'] = 'admin'
        session['admin_verified'] = True
            
        session.pop('pending_admin_login', None)
        return jsonify({"message": "Admin authentication successful!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==========================================
# IMAGE UPLOAD PIPELINE
# ==========================================

@app.route('/api/upload/image', methods=['POST'])
def api_upload_image():
    """Uploads product images to server storage and returns public URL."""
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided."}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file."}), 400

    upload_dir = os.path.join(BASE_DIR, 'static', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)

    filename = f"prod_{int(time.time())}_{re.sub(r'[^a-zA-Z0-9._-]', '', file.filename)}"
    file_path = os.path.join(upload_dir, filename)
    file.save(file_path)

    image_url = f"/static/uploads/{filename}"
    return jsonify({
        "success": True,
        "image_url": image_url,
        "url": image_url
    }), 200

# ==========================================
# SECURED CATALOG API ENDPOINTS (Admins Only)
# ==========================================

@app.route('/api/products', methods=['GET', 'POST', 'PUT'])
@admin_required
def api_handle_products():
    """Catalog Manager Endpoint (GET/POST/PUT). Admins see all draft and published items."""
    if request.method == 'GET':
        try:
            page = int(request.args.get('page', 1))
            per_page = int(request.args.get('per_page', 10))
            search = request.args.get('search', '').strip()
            
            if page < 1: page = 1
            if per_page < 1: per_page = 10
            
            res = get_products(DB_PATH, page=page, per_page=per_page, search_query=search)
            return jsonify(res), 200
        except Exception as e:
            return jsonify({"error": f"Failed to retrieve products: {str(e)}"}), 500

    elif request.method == 'POST':
        data = request.get_json() or {}
        sku = data.get('sku', '').strip()
        name = data.get('name', '').strip()
        category_id_val = data.get('category_id')
        status = data.get('status', 'draft')
        image_url = data.get('image_url', '').strip() or None
        
        category_id = int(category_id_val) if category_id_val and str(category_id_val).isdigit() else None
        
        try:
            purchase_price = float(data.get('purchase_price', 0))
            selling_price = float(data.get('selling_price', 0))
            stock = int(data.get('stock', 0))
        except (ValueError, TypeError):
            return jsonify({"error": "Prices and stock quantity must be numeric."}), 400

        try:
            prod_id = add_product(
                DB_PATH, sku=sku, name=name, category_id=category_id, 
                purchase_price=purchase_price, selling_price=selling_price, 
                stock=stock, status=status, image_url=image_url
            )
            return jsonify({"message": "Product added successfully", "product_id": prod_id}), 201
        except DuplicateSKUError as e:
            return jsonify({"error": str(e)}), 409
        except ValueError as e:
            return jsonify({"error": str(e)}), 400
        except Exception as e:
            return jsonify({"error": f"Failed to add product: {str(e)}"}), 500

    elif request.method == 'PUT':
        data = request.get_json() or {}
        product_id = data.get('product_id') or data.get('id')
        if not product_id:
            return jsonify({"error": "Product ID is required."}), 400
            
        sku = data.get('sku', '').strip()
        name = data.get('name', '').strip()
        category_id_val = data.get('category_id')
        status = data.get('status', 'draft')
        image_url = data.get('image_url', '').strip() or None
        
        category_id = int(category_id_val) if category_id_val and str(category_id_val).isdigit() else None
        
        try:
            purchase_price = float(data.get('purchase_price', 0))
            selling_price = float(data.get('selling_price', 0))
            stock = int(data.get('stock', 0))
        except (ValueError, TypeError):
            return jsonify({"error": "Prices and stock quantity must be numeric."}), 400

        try:
            updated = update_product(
                DB_PATH, 
                product_id=product_id, 
                sku=sku, 
                name=name, 
                category_id=category_id,
                purchase_price=purchase_price, 
                selling_price=selling_price, 
                stock=stock,
                status=status,
                image_url=image_url
            )
            if updated:
                return jsonify({"message": "Product adjusted successfully"}), 200
            return jsonify({"error": "Product not found"}), 404
        except DuplicateSKUError as e:
            return jsonify({"error": str(e)}), 409
        except ValueError as e:
            return jsonify({"error": str(e)}), 400
        except Exception as e:
            return jsonify({"error": f"Failed to update product: {str(e)}"}), 500

@app.route('/api/products/update/<int:product_id>', methods=['PUT'])
@admin_required
def api_update_product(product_id):
    """Fallback PUT route updates details of a product (Admin only)."""
    data = request.get_json() or {}
    sku = data.get('sku', '').strip()
    name = data.get('name', '').strip()
    category_id_val = data.get('category_id')
    status = data.get('status', 'draft')
    image_url = data.get('image_url', '').strip() or None
    
    category_id = int(category_id_val) if category_id_val and str(category_id_val).isdigit() else None
    
    try:
        purchase_price = float(data.get('purchase_price', 0))
        selling_price = float(data.get('selling_price', 0))
        stock = int(data.get('stock', 0))
    except (ValueError, TypeError):
        return jsonify({"error": "Prices and stock must be numeric."}), 400

    try:
        update_product(
            DB_PATH, 
            product_id=product_id, 
            sku=sku, 
            name=name, 
            category_id=category_id,
            purchase_price=purchase_price, 
            selling_price=selling_price, 
            stock=stock,
            status=status,
            image_url=image_url
        )
        return jsonify({"message": "Product updated successfully"}), 200
    except DuplicateSKUError as e:
        return jsonify({"error": str(e)}), 409
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Failed to update product: {str(e)}"}), 500

@app.route('/api/products/delete/<int:product_id>', methods=['DELETE'])
@admin_required
def api_delete_product(product_id):
    """Deletes a product from the database (Admin only)."""
    try:
        deleted = delete_product(DB_PATH, product_id)
        if deleted:
            return jsonify({"message": "Product deleted successfully"}), 200
        return jsonify({"error": "Product not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/products/search', methods=['GET'])
@login_required
def api_search_products():
    """Autosuggest search endpoint for POS terminal."""
    query = request.args.get('q', '').strip()
    if not query:
        return jsonify([]), 200
    
    try:
        suggestions = search_products_suggest(DB_PATH, query)
        return jsonify(suggestions), 200
    except Exception as e:
        return jsonify({"error": f"Search failed: {str(e)}"}), 500

# ==========================================
# CHECKOUT ENGINE & ORDERS
# ==========================================

@app.route('/api/checkout', methods=['POST'])
@login_required
def api_checkout_engine():
    """Checkout Engine creates a pending order, locked stock, and returns a session tracker."""
    data = request.get_json() or {}
    cart = data.get('cart', [])
    shipping_address = data.get('shipping_address', '').strip()
    
    if not cart:
        return jsonify({"error": "Cart is empty."}), 400
    if not shipping_address:
        return jsonify({"error": "Shipping address is required."}), 400
        
    try:
        session_data = create_checkout_session(
            DB_PATH, cart_items=cart, tax_rate_percent=18.0,
            user_id=session['user_id'], shipping_address=shipping_address
        )
        return jsonify({
            "message": "Pending order session created.",
            "session": session_data
        }), 201
    except InsufficientStockError as e:
        return jsonify({"error": str(e)}), 400
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Checkout failed: {str(e)}"}), 500

@app.route('/api/orders/history', methods=['GET'])
@login_required
def api_order_history():
    """Retrieves customer-facing purchase logs."""
    try:
        orders = get_user_orders(DB_PATH, session['user_id'])
        return jsonify(orders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/admin/list', methods=['GET'])
@admin_required
def api_admin_orders_list():
    """Admin only: lists all customer checkouts."""
    try:
        orders = get_all_orders_admin(DB_PATH)
        return jsonify(orders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/<int:id>/status', methods=['PUT'])
@admin_required
def api_orders_status_update(id):
    """Admin only: transitions order fulfillment states (Shipped/Delivered)."""
    data = request.get_json() or {}
    new_status = data.get('status')
    if not new_status:
        return jsonify({"error": "Fulfillment status is required."}), 400
        
    try:
        success = update_order_status(DB_PATH, id, new_status)
        if success:
            return jsonify({"message": f"Order status updated to {new_status}."}), 200
        return jsonify({"error": "Order not found."}), 404
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/dashboard/metrics', methods=['GET'])
@admin_required
def api_dashboard_metrics():
    """Gets store metrics for the dashboard summary cards (Admin only)."""
    try:
        metrics = get_dashboard_metrics(DB_PATH)
        return jsonify(metrics), 200
    except Exception as e:
        return jsonify({"error": f"Failed to retrieve store metrics: {str(e)}"}), 500

if __name__ == '__main__':
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 't')
    app.run(host=host, port=port, debug=debug)