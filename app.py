# app.py
import os
import sys
import re
import random
from functools import wraps

# Add the 'app' directory to the path to import database modules directly
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, os.path.join(BASE_DIR, 'app'))

from flask import Flask, request, jsonify, render_template, session, make_response
from werkzeug.security import generate_password_hash, check_password_hash
from database import (
    init_db, add_product, get_products, update_product, delete_product,
    search_products_suggest, complete_sale, 
    create_user, get_user_by_identifier, get_dashboard_metrics,
    get_user_orders, update_order_status, get_all_orders_admin, get_categories,
    add_category, create_checkout_session, update_order_payment_status,
    update_user_password, InsufficientStockError, DuplicateSKUError, DuplicateUserError
)

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
# PAGE ROUTING (HTML RENDER)
# ==========================================

@app.route('/')
def index_page():
    """Renders the main single page interface (POS & Catalog storefront)."""
    return render_template('index.html')

@app.route('/login')
def login_page():
    """Renders the theatrical split-screen authentication page."""
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
# USER AUTHENTICATION API ENDPOINTS
# ==========================================

@app.route('/api/auth/register', methods=['POST'])
def api_register():
    """Starts OTP authentication to register a new user account."""
    request_data = request.get_json() or {}
    username = request_data.get('username', '').strip()
    email = request_data.get('email', '').strip().lower()
    password = request_data.get('password', '')

    if not username or not email:
        return jsonify({"error": "Username and Email/Phone are required."}), 400
        
    if not password:
        password = "MOCK-PHONE-PASSWORD-1234"
    elif len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400

    try:
        # Check if user already exists
        existing_user = get_user_by_identifier(DB_PATH, username)
        if not existing_user:
            existing_user = get_user_by_identifier(DB_PATH, email)
            
        if existing_user:
            return jsonify({"error": "Username or Email/Phone is already registered."}), 409

        # Set administrative role automatically ONLY for root owner credentials
        role = 'admin' if (email == 'admin@ramastore.com' or email == '7268903804') else 'customer'

        # Generate random 6-digit OTP
        otp = str(random.randint(100000, 999999))
        
        # Log to terminal console for local simulation
        print(f"\n=======================================================", flush=True)
        print(f"[OTP SENDER] Verification code for {username} is: {otp}", flush=True)
        print(f"=======================================================\n", flush=True)

        password_hash = generate_password_hash(password)

        # Store in session temporarily
        session['pending_registration'] = {
            "username": username,
            "email": email,
            "password_hash": password_hash,
            "role": role,
            "otp": otp
        }

        return jsonify({
            "message": "Verification code has been sent successfully.",
            "otp_sent": True,
            "debug_otp": otp  # For testing convenience
        }), 200
    except Exception as e:
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500

@app.route('/api/auth/verify_otp', methods=['POST'])
def api_verify_otp():
    """Verifies registration code, saves user profile, and logs user in automatically."""
    data = request.get_json() or {}
    user_otp = data.get('otp', '').strip()

    pending = session.get('pending_registration')
    if not pending:
        return jsonify({"error": "No registration in progress. Please sign up again."}), 400

    if not user_otp:
        return jsonify({"error": "Verification code is required."}), 400

    # Compare OTPs
    if user_otp != pending['otp']:
        return jsonify({"error": "Invalid verification code. Please check and try again."}), 400

    try:
        # Save user to DB
        user_id = create_user(
            DB_PATH, 
            username=pending['username'],
            email=pending['email'],
            password_hash=pending['password_hash'], 
            role=pending['role']
        )
        
        # Log the user in automatically on successful OTP signup!
        session['user_id'] = user_id
        session['email_or_phone'] = pending['email']
        session['fullname'] = pending['username']
        session['role'] = pending['role']

        # Clear temporary registration session state
        session.pop('pending_registration', None)

        return jsonify({
            "message": "User registered successfully.",
            "user_id": user_id,
            "user": {
                "email_or_phone": pending['email'],
                "fullname": pending['username'],
                "role": pending['role']
            }
        }), 201
    except DuplicateUserError as e:
        return jsonify({"error": str(e)}), 409
    except Exception as e:
        return jsonify({"error": f"Failed to finalize registration: {str(e)}"}), 500

@app.route('/api/auth/forgot-password', methods=['POST'])
def api_forgot_password():
    """Generates password reset OTP code if user is registered."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    
    if not email_or_phone:
        return jsonify({"error": "Username or Email address is required."}), 400
        
    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user:
            return jsonify({"error": "Account with this Username/Email does not exist."}), 404
            
        # Generate random 6-digit OTP code
        otp = str(random.randint(100000, 999999))
        
        # Log code to terminal
        print(f"\n=======================================================", flush=True)
        print(f"[OTP SENDER] Password reset verification code: {otp}", flush=True)
        print(f"=======================================================\n", flush=True)
        
        session['forgot_password_session'] = {
            "email_or_phone": email_or_phone,
            "otp": otp
        }
        
        return jsonify({
            "message": "Reset verification code sent.",
            "otp_sent": True,
            "debug_otp": otp
        }), 200
    except Exception as e:
        return jsonify({"error": f"Failed to request reset: {str(e)}"}), 500

@app.route('/api/auth/reset-password', methods=['POST'])
def api_reset_password():
    """Confirms password reset OTP and sets new password hash in SQLite."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    otp = data.get('otp', '').strip()
    new_password = data.get('new_password', '')
    
    if not email_or_phone or not otp or not new_password:
        return jsonify({"error": "All fields (Username/Email, OTP, New Password) are required."}), 400
        
    if len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400
        
    reset_state = session.get('forgot_password_session')
    if not reset_state or reset_state['email_or_phone'].lower() != email_or_phone.lower():
        return jsonify({"error": "Session mismatch. Please request verification again."}), 400
        
    if reset_state['otp'] != otp:
        return jsonify({"error": "Invalid verification code. Please check and try again."}), 400
        
    try:
        password_hash = generate_password_hash(new_password)
        success = update_user_password(DB_PATH, email_or_phone, password_hash)
        if success:
            session.pop('forgot_password_session', None)
            return jsonify({"message": "Password reset successfully! Please sign in."}), 200
        return jsonify({"error": "Account not found."}), 404
    except Exception as e:
        return jsonify({"error": f"Failed to reset password: {str(e)}"}), 500

@app.route('/api/auth/change-password', methods=['POST'])
def api_change_password():
    """Changes the logged-in user's password in SQLite database."""
    if 'user_id' not in session:
        return jsonify({"error": "Authentication required. Please log in."}), 401
        
    data = request.get_json() or {}
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')
    confirm_password = data.get('confirm_password', '')
    
    if not current_password or not new_password or not confirm_password:
        return jsonify({"error": "All password fields are required."}), 400
        
    if new_password != confirm_password:
        return jsonify({"error": "New passwords do not match."}), 400
        
    if len(new_password) < 6:
        return jsonify({"error": "New password must be at least 6 characters."}), 400
        
    try:
        user = get_user_by_identifier(DB_PATH, session['email_or_phone'])
        if not user or not check_password_hash(user['password_hash'], current_password):
            return jsonify({"error": "Incorrect current password."}), 401
            
        password_hash = generate_password_hash(new_password)
        success = update_user_password(DB_PATH, session['email_or_phone'], password_hash)
        if success:
            return jsonify({"message": "Password changed successfully!"}), 200
        return jsonify({"error": "User record not found."}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/login', methods=['POST'])
def api_login():
    """Logs in an existing user using Username or Email ID."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip() # accepts username or email
    password = data.get('password', '')

    if not email_or_phone or not password:
        return jsonify({"error": "Please enter both Username/Email and Password."}), 400

    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user or not check_password_hash(user['password_hash'], password):
            return jsonify({"error": "Invalid login credentials."}), 401

        # Establish Flask session
        session['user_id'] = user['id']
        session['email_or_phone'] = user['email']
        session['fullname'] = user['username']
        session['role'] = user['role'] # 'admin' or 'customer'

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

@app.route('/api/auth/login-otp-request', methods=['POST'])
def api_login_otp_request():
    """Generates an OTP code for passwordless login."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    
    if not email_or_phone:
        return jsonify({"error": "Please enter your Email or Phone Number."}), 400
        
    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user:
            return jsonify({"error": "No account registered with this email or phone number."}), 404
            
        otp = str(random.randint(100000, 999999))
        print(f"\n=======================================================", flush=True)
        print(f"[OTP SENDER] Login code for {user['username']} is: {otp}", flush=True)
        print(f"=======================================================\n", flush=True)
        
        session['pending_otp_login'] = {
            "user_id": user['id'],
            "email_or_phone": user['email'],
            "fullname": user['username'],
            "role": user['role'],
            "otp": otp
        }
        return jsonify({
            "message": "OTP verification code sent!",
            "debug_otp": otp
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/login-otp-verify', methods=['POST'])
def api_login_otp_verify():
    """Verifies OTP login code and establishes session."""
    data = request.get_json() or {}
    otp = data.get('otp', '').strip()
    
    pending = session.get('pending_otp_login')
    if not pending:
        return jsonify({"error": "No active verification session. Request a new OTP."}), 400
        
    if not otp or otp != pending['otp']:
        return jsonify({"error": "Invalid verification code. Please check your input."}), 400
        
    try:
        # Establish session
        session['user_id'] = pending['user_id']
        session['email_or_phone'] = pending['email_or_phone']
        session['fullname'] = pending['fullname']
        session['role'] = pending['role']
        
        # Clear verification session
        session.pop('pending_otp_login', None)
        
        return jsonify({
            "message": "Login successful.",
            "user": {
                "email_or_phone": pending['email_or_phone'],
                "fullname": pending['fullname'],
                "role": pending['role']
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

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

@app.route('/api/announcements', methods=['GET', 'POST'])
def api_announcements():
    """Endpoint to get or publish announcements. POST is admin-restricted."""
    announcements_path = os.path.join(BASE_DIR, 'announcements.json')
    
    if request.method == 'POST':
        # Admin authentication guard with 2FA check
        if 'user_id' not in session or session.get('role') != 'admin' or not session.get('admin_verified'):
            return jsonify({"error": "Unauthorized. Owner 2FA verification required."}), 403
            
        data = request.get_json() or {}
        stock_status = data.get('stock_status', '').strip()
        loyalty_offer = data.get('loyalty_offer', '').strip()
        home_delivery = data.get('home_delivery', '').strip()
        
        if not stock_status or not loyalty_offer or not home_delivery:
            return jsonify({"error": "All announcement fields are required."}), 400
            
        try:
            import json
            with open(announcements_path, 'w', encoding='utf-8') as f:
                json.dump({
                    "stock_status": stock_status,
                    "loyalty_offer": loyalty_offer,
                    "home_delivery": home_delivery
                }, f, indent=2)
            return jsonify({"message": "Announcements updated successfully."}), 200
        except Exception as e:
            return jsonify({"error": f"Failed to save announcements: {str(e)}"}), 500
            
    # GET method
    try:
        import json
        if os.path.exists(announcements_path):
            with open(announcements_path, 'r', encoding='utf-8') as f:
                content = json.load(f)
            return jsonify(content), 200
        else:
            return jsonify({
                "stock_status": "Counter is active & loading products",
                "loyalty_offer": "Check back for store deals",
                "home_delivery": "Delivery services active"
            }), 200
    except Exception as e:
        return jsonify({"error": f"Failed to read announcements: {str(e)}"}), 500

@app.route('/api/auth/admin-login-request', methods=['POST'])
def api_admin_login_request():
    """Validates admin credentials and generates a 2FA OTP code."""
    data = request.get_json() or {}
    email_or_phone = data.get('email_or_phone', '').strip()
    password = data.get('password', '')
    
    if not email_or_phone or not password:
        return jsonify({"error": "Registered owner number and password are required."}), 400
        
    try:
        user = get_user_by_identifier(DB_PATH, email_or_phone)
        if not user or user['role'] != 'admin':
            return jsonify({"error": "Access denied: Account is not an administrator."}), 403
            
        # Strict validation: Only the registered owner phone 7268903804 or email admin@ramastore.com can access the owner gate!
        if user['email'] != 'admin@ramastore.com' and '7268903804' not in user['email'] and '7268903804' not in user['username']:
            return jsonify({"error": "Access denied: You are not the registered owner."}), 403
            
        if not check_password_hash(user['password_hash'], password):
            return jsonify({"error": "Incorrect password. Please try again."}), 401
            
        otp = str(random.randint(100000, 999999))
        print(f"\n=======================================================", flush=True)
        print(f"[OTP SENDER] Admin 2FA code for {user['username']} is: {otp}", flush=True)
        print(f"=======================================================\n", flush=True)
        
        session['pending_admin_login'] = {
            "user_id": user['id'],
            "email_or_phone": user['email'],
            "fullname": user['username'],
            "role": 'admin',
            "otp": otp
        }
        return jsonify({
            "message": "Verification code generated successfully!",
            "debug_otp": otp
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/admin-login-verify', methods=['POST'])
def api_admin_login_verify():
    """Verifies the admin 2FA OTP and establishes the authorized session."""
    data = request.get_json() or {}
    otp = data.get('otp', '').strip()
    
    pending = session.get('pending_admin_login')
    if not pending:
        return jsonify({"error": "No active admin login session. Please enter credentials."}), 400
        
    if not otp or otp != pending['otp']:
        return jsonify({"error": "Invalid verification code. Please check and try again."}), 400
        
    try:
        # Establish full authenticated admin session
        session['user_id'] = pending['user_id']
        session['email_or_phone'] = pending['email_or_phone']
        session['fullname'] = pending['fullname']
        session['role'] = 'admin'
        session['admin_verified'] = True
        
        # Clear temporary state
        session.pop('pending_admin_login', None)
        
        return jsonify({"message": "Authentication successful!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

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
            
            # Admins see all states (no status filter)
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
# CHECKOUT ENGINE & TRANSACTION WEBHOOKS
# ==========================================

@app.route('/api/sales/complete', methods=['POST'])
@admin_required
def api_complete_sale():
    """Processes POS cash billing checkouts directly (marked Paid & Delivered)."""
    data = request.get_json() or {}
    cart = data.get('cart', [])
    
    try:
        tax_rate = float(data.get('tax_rate', 18.0))
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid tax rate value."}), 400

    if not cart:
        return jsonify({"error": "Cannot complete sale: Cart is empty."}), 400

    try:
        receipt = complete_sale(
            DB_PATH, cart_items=cart, tax_rate_percent=tax_rate
        )
        return jsonify({
            "message": "POS Transaction logged successfully",
            "receipt": receipt
        }), 200
    except InsufficientStockError as e:
        return jsonify({"error": str(e)}), 400
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Transaction aborted: {str(e)}"}), 500

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

@app.route('/api/payment/process', methods=['POST'])
@login_required
def api_payment_process():
    """Simulates gateway processor. Performs rollbacks if transaction fails (ends in 4000)."""
    data = request.get_json() or {}
    tracking_number = data.get('tracking_number')
    card_number = data.get('card_number', '').replace(' ', '')
    cvv = data.get('cvv', '')
    expiry = data.get('expiry', '')
    
    if not tracking_number or not card_number or not cvv or not expiry:
        return jsonify({"error": "Cardholder credentials must be completely filled."}), 400
        
    if len(card_number) != 16 or len(cvv) != 3 or len(expiry) != 5:
        update_order_payment_status(DB_PATH, tracking_number, payment_success=False)
        return jsonify({"error": "Invalid format lengths. Transaction rolled back."}), 400
        
    # Simulate declined cards ending in 4000
    payment_success = not card_number.endswith('4000')
    
    try:
        processed = update_order_payment_status(DB_PATH, tracking_number, payment_success=payment_success)
        if not processed:
            return jsonify({"error": "Tracking number not found."}), 404
            
        if payment_success:
            return jsonify({
                "message": "Payment success confirmed.",
                "status": "Paid"
            }), 200
        else:
            return jsonify({
                "error": "Card Declined: Insufficient credit limit. Stock reservation rolled back.",
                "status": "Cancelled"
            }), 402
    except Exception as e:
        return jsonify({"error": f"Gateway simulator crash: {str(e)}"}), 500

@app.route('/api/payments/webhook', methods=['POST'])
def api_payments_webhook_fallback():
    """Asynchronous Webhook fallback listener."""
    data = request.get_json() or {}
    event = data.get('event')
    payment_intent_id = data.get('payment_intent_id')
    
    if not event or not payment_intent_id:
        return jsonify({"error": "Missing webhook intent fields."}), 400
        
    payment_success = (event == 'payment.success')
    
    try:
        processed = update_order_payment_status(DB_PATH, payment_intent_id, payment_success)
        if processed:
            return jsonify({"message": f"Webhook processed: {event}"}), 200
        return jsonify({"error": "Order transaction not found."}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/history', methods=['GET'])
@login_required
def api_order_history():
    """Retrieves customer-facing purchase logs with delivery timelines."""
    try:
        orders = get_user_orders(DB_PATH, session['user_id'])
        return jsonify(orders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/admin/list', methods=['GET'])
@admin_required
def api_admin_orders_list():
    """Admin only: lists all customer checkouts and POS transactions."""
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

@app.route('/api/orders/admin/status', methods=['PUT'])
@admin_required
def api_admin_update_order_status_fallback():
    """Fallback route supporting legacy OMS status triggers."""
    data = request.get_json() or {}
    order_id = data.get('order_id')
    new_status = data.get('status')
    
    if not order_id or not new_status:
        return jsonify({"error": "Order ID and status are required."}), 400
        
    try:
        success = update_order_status(DB_PATH, order_id, new_status)
        if success:
            return jsonify({"message": f"Order status updated to {new_status}."}), 200
        return jsonify({"error": "Order ID not found."}), 404
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
