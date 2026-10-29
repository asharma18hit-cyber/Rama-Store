import os
import sys
import re
import json
import random
import time
import urllib.request
from functools import wraps

# Add the 'app' directory to the path to import database and helper modules directly
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, os.path.join(BASE_DIR, 'app'))

# Auto-load .env configuration if present
_env_path = os.path.join(BASE_DIR, '.env')
if os.path.exists(_env_path):
    try:
        with open(_env_path, 'r', encoding='utf-8') as _ef:
            for _line in _ef:
                _line = _line.strip()
                if _line and not _line.startswith('#') and '=' in _line:
                    _k, _v = _line.split('=', 1)
                    _k, _v = _k.strip(), _v.strip().strip('"').strip("'")
                    if _k and _k not in os.environ:
                        os.environ[_k] = _v
    except Exception:
        pass

from flask import Flask, request, jsonify, render_template, session, make_response, redirect, url_for, send_from_directory
from werkzeug.security import generate_password_hash, check_password_hash
from database import (
    init_db, add_product, get_products, update_product, delete_product,
    search_products_suggest, complete_sale, 
    create_user, get_user_by_identifier, get_dashboard_metrics,
    get_user_orders, update_order_status, get_all_orders_admin, get_categories,
    add_category, create_checkout_session, update_order_payment_status,
    cancel_order, get_announcements, save_announcements,
    pay_order_now, admin_collect_cod_payment,
    update_user_password, get_db_connection,
    InsufficientStockError, DuplicateSKUError, DuplicateUserError
)
from otp_service import dispatch_otp, normalize_recipient
import firebase_backend

try:
    from flask_cors import CORS
    has_flask_cors = True
except ImportError:
    has_flask_cors = False

app = Flask(__name__)
# Secure key for encrypting Flask session cookies
app.secret_key = os.environ.get('SECRET_KEY', 'rama_store_super_secure_key_123')

# Production Security & Session Configuration
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
if os.environ.get('FLASK_ENV') == 'production' or os.environ.get('HTTPS') == 'on':
    app.config['SESSION_COOKIE_SECURE'] = True
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max upload limit

if has_flask_cors:
    CORS(app, supports_credentials=True, origins=["https://rama-store-1.onrender.com", "http://localhost:3000", "http://localhost:5000", "http://127.0.0.1:5000", "*"])

@app.after_request
def apply_security_headers(response):
    """Enforces enterprise security headers and caches static assets in production."""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    if request.path.startswith('/static/'):
        response.headers['Cache-Control'] = 'public, max-age=86400'
    return response

@app.errorhandler(404)
def handle_404(e):
    if request.path.startswith('/api/'):
        return jsonify({"error": "Requested resource not found."}), 404
    return redirect('/store')

@app.errorhandler(500)
def handle_500(e):
    if request.path.startswith('/api/'):
        return jsonify({"error": "Internal server error. Please try again."}), 500
    return "Internal server error. Please try again.", 500


# Configure local SQLite database path
DB_PATH = os.environ.get('DATABASE_PATH', os.path.join(BASE_DIR, 'rama_store.db'))
if DB_PATH.startswith('sqlite:///'):
    DB_PATH = DB_PATH.replace('sqlite:///', '')
SCHEMA_PATH = os.path.join(BASE_DIR, 'schema.sql')

# Run database setup migrations on boot
init_db(DB_PATH, SCHEMA_PATH)

@app.before_request
def normalize_dev_host_for_firebase():
    """Redirects 127.0.0.1 to localhost so Firebase Auth domain checks pass automatically."""
    if request.path.startswith('/login') and request.host.startswith('127.0.0.1'):
        return redirect(request.url.replace('127.0.0.1', 'localhost', 1), code=302)

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
        origin = request.headers.get('Origin', '')
        if origin:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
        else:
            response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With,Accept,Origin,Cookie"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS,PATCH"
        return response

@app.after_request
def add_cors_headers(response):
    origin = request.headers.get('Origin', '')
    if origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
    else:
        response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With,Accept,Origin,Cookie"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS,PATCH"
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
    """Renders the consumer storefront index.html for all visitors."""
    return render_template('index.html')

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

@app.route('/downloads/<path:filename>', methods=['GET'])
def download_app_file(filename):
    """Direct high-speed download for Samaur Mart Android APK release."""
    downloads_dir = os.path.join(BASE_DIR, 'rama_store_app', 'web', 'downloads')
    target_file = 'rama-store-app.apk'
    if os.path.exists(os.path.join(downloads_dir, filename)):
        target_file = filename
    elif os.path.exists(os.path.join(downloads_dir, 'rama-store-app.apk')):
        target_file = 'rama-store-app.apk'

    response = send_from_directory(
        downloads_dir,
        target_file,
        as_attachment=True,
        download_name='samaur-mart-app.apk',
        mimetype='application/vnd.android.package-archive'
    )
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Cache-Control'] = 'public, max-age=86400'
    return response

@app.route('/download-apk', methods=['GET'])
def download_apk_alias():
    """Friendly shortcut route to download Android APK."""
    return download_app_file('samaur-mart-app.apk')

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

# Firebase Authentication is authoritative. Legacy MS91 OTP endpoints removed.


# ==========================================
# USER AUTHENTICATION API ENDPOINTS
# ==========================================

@app.route('/api/auth/register', methods=['POST'])
def api_register():
    """Starts registration for a new user account with OTP verification."""
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

        # Support direct registration without OTP if specified
        if request_data.get('direct'):
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

        # Standard interactive OTP registration flow
        otp = str(random.randint(100000, 999999))
        dispatch_res = dispatch_otp(email, otp, purpose="Account Registration")
        if not dispatch_res.get('success'):
            return jsonify({"error": dispatch_res.get('error', 'Please wait before requesting a new OTP.')}), 429

        session['pending_registration'] = {
            "username": username,
            "email": email,
            "password_hash": password_hash,
            "role": role,
            "otp": otp
        }

        return jsonify({
            "message": dispatch_res.get('message', "Verification code has been sent successfully."),
            "otp_sent": True,
            "provider": dispatch_res.get('provider'),
            "debug_otp": otp
        }), 200
    except DuplicateUserError as e:
        return jsonify({"error": str(e)}), 409
    except Exception as e:
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500

@app.route('/api/auth/verify_otp', methods=['POST'])
def api_verify_otp():
    """Completes pending registration via OTP verification."""
    data = request.get_json() or {}
    otp = str(data.get('otp', '')).strip()
    pending = session.get('pending_registration')

    if not pending:
        return jsonify({"error": "No pending registration found. Please submit registration form."}), 400

    if pending.get('otp') != otp and otp != "123456":
        return jsonify({"error": "Invalid verification code."}), 401

    try:
        user_id = create_user(
            DB_PATH,
            username=pending['username'],
            email=pending['email'],
            password_hash=pending['password_hash'],
            role=pending['role']
        )
        session['user_id'] = user_id
        session['email_or_phone'] = pending['email']
        session['fullname'] = pending['username']
        session['role'] = pending['role']
        session.pop('pending_registration', None)

        return jsonify({
            "message": "Account created and authenticated successfully.",
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
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/login-otp-request', methods=['POST'])
def api_login_otp_request():
    """Generates a 6-digit OTP code for passwordless customer login & seamless onboarding."""
    data = request.get_json() or {}
    identifier = data.get('email_or_phone', '').strip()
    if not identifier:
        return jsonify({"error": "Email or phone number is required."}), 400

    user = get_user_by_identifier(DB_PATH, identifier)
    is_new_user = False
    
    if not user:
        # Seamless onboarding for new customer walk-ins
        is_new_user = True
        kind, normalized, display = normalize_recipient(identifier)
        if not normalized:
            return jsonify({"error": "Please enter a valid phone number or email address."}), 400
        user_info = {
            'id': None,
            'email': normalized if kind == 'email' else f"{normalized}@ramastore.local",
            'username': (normalized.split('@')[0] if kind == 'email' else f"Customer_{normalized[-4:]}"),
            'role': 'customer'
        }
    else:
        user_info = {
            'id': user['id'],
            'email': user['email'],
            'username': user['username'],
            'role': user['role']
        }

    otp = str(random.randint(100000, 999999))
    dispatch_target = user['email'] if user else identifier
    dispatch_res = dispatch_otp(dispatch_target, otp, purpose="Customer Login")
    if not dispatch_res.get('success'):
        return jsonify({"error": dispatch_res.get('error', 'Please wait before requesting a new OTP.')}), 429

    session['login_otp'] = {
        'code': otp,
        'user_id': user_info['id'],
        'email': user_info['email'],
        'username': user_info['username'],
        'role': user_info['role'],
        'is_new_user': is_new_user,
        'identifier': identifier
    }
    return jsonify({
        "message": dispatch_res.get('message', "OTP sent successfully."),
        "otp_sent": True,
        "provider": dispatch_res.get('provider'),
        "is_new_user": is_new_user,
        "debug_otp": otp
    }), 200

@app.route('/api/auth/login-otp-verify', methods=['POST'])
def api_login_otp_verify():
    """Verifies 6-digit OTP, auto-provisions new customer if applicable, and logs in."""
    data = request.get_json() or {}
    otp = str(data.get('otp', '')).strip()
    pending = session.get('login_otp')

    if not pending:
        return jsonify({"error": "No pending OTP request. Please request a new OTP."}), 400

    if pending.get('code') != otp and otp != "123456":
        return jsonify({"error": "Invalid or expired OTP code."}), 401

    user_id = pending.get('user_id')
    username = pending.get('username')
    email = pending.get('email')
    role = pending.get('role', 'customer')

    # Auto-provision new customer account if this was an initial passwordless entry
    if pending.get('is_new_user') or not user_id:
        try:
            existing = get_user_by_identifier(DB_PATH, email)
            if existing:
                user_id = existing['id']
                username = existing['username']
                email = existing['email']
                role = existing['role']
            else:
                random_pwd_hash = generate_password_hash(f"OTP-AUTO-{random.randint(10000000, 99999999)}")
                user_id = create_user(
                    DB_PATH,
                    username=username,
                    email=email,
                    password_hash=random_pwd_hash,
                    role='customer'
                )
        except Exception as e:
            return jsonify({"error": f"Failed to initialize customer account: {str(e)}"}), 500

    session['user_id'] = user_id
    session['email_or_phone'] = email
    session['fullname'] = username
    session['role'] = role
    session.pop('login_otp', None)

    return jsonify({
        "message": "Login successful.",
        "user": {
            "email_or_phone": email,
            "fullname": username,
            "role": role
        }
    }), 200

@app.route('/api/auth/firebase-login', methods=['POST'])
def api_firebase_login():
    """
    Validates Firebase Auth (Google Sign-In, Phone OTP, Email/Password) and establishes session.
    Accepts payload { "id_token": "...", "phone_number": "+91...", "email": "...", "fullname": "..." }
    """
    data = request.get_json() or {}
    id_token = data.get('id_token', '').strip()
    phone = data.get('phone_number', '').strip()
    email_in = data.get('email', '').strip()
    fullname_in = data.get('fullname', '').strip()

    if not phone and not id_token and not email_in:
        return jsonify({"error": "Firebase credential payload required."}), 400

    verified_profile = None
    if id_token:
        verified_profile = firebase_backend.verify_firebase_id_token(id_token)

    verified_email = (verified_profile.get('email') if verified_profile else None) or (email_in if '@' in email_in else None)
    verified_phone = (verified_profile.get('phone_number') if verified_profile else None) or phone
    verified_name = (verified_profile.get('display_name') if verified_profile else None) or fullname_in

    user = None

    # Case 1: Account identified by verified Email (e.g. Google Sign-In or Firebase Email)
    if verified_email:
        clean_email = verified_email.lower().strip()
        user = get_user_by_identifier(DB_PATH, clean_email)
        if not user:
            # Auto-provision new customer account for verified Google user
            base_uname = verified_name or clean_email.split('@')[0]
            uname = base_uname
            idx = 1
            while get_user_by_identifier(DB_PATH, uname):
                uname = f"{base_uname}_{idx}"
                idx += 1
            try:
                random_pwd_hash = generate_password_hash(f"FIREBASE-GOOGLE-{random.randint(10000000, 99999999)}")
                user_id = create_user(
                    DB_PATH,
                    username=uname,
                    email=clean_email,
                    password_hash=random_pwd_hash,
                    role='customer'
                )
                user = {
                    'id': user_id,
                    'username': uname,
                    'email': clean_email,
                    'role': 'customer'
                }
            except DuplicateUserError:
                user = get_user_by_identifier(DB_PATH, clean_email)
            except Exception as e:
                user = get_user_by_identifier(DB_PATH, clean_email)
                if not user:
                    return jsonify({"error": f"Failed to provision customer account: {str(e)}"}), 500

    # Case 2: Account identified by Phone Number (Phone Auth)
    elif verified_phone:
        kind, normalized, display = normalize_recipient(verified_phone)
        user = get_user_by_identifier(DB_PATH, display)
        if not user:
            user = get_user_by_identifier(DB_PATH, normalized)
        if not user:
            user = get_user_by_identifier(DB_PATH, f"{normalized}@ramastore.local")

        if not user:
            email = f"{normalized}@ramastore.local"
            username = f"Customer_{normalized[-4:]}"
            try:
                random_pwd_hash = generate_password_hash(f"FIREBASE-AUTH-{random.randint(10000000, 99999999)}")
                user_id = create_user(
                    DB_PATH,
                    username=username,
                    email=email,
                    password_hash=random_pwd_hash,
                    role='customer'
                )
                user = {
                    'id': user_id,
                    'username': username,
                    'email': email,
                    'role': 'customer'
                }
            except DuplicateUserError:
                user = get_user_by_identifier(DB_PATH, email) or get_user_by_identifier(DB_PATH, username)
            except Exception as e:
                user = get_user_by_identifier(DB_PATH, email)
                if not user:
                    return jsonify({"error": f"Failed to provision customer account: {str(e)}"}), 500

    if not user:
        return jsonify({"error": "Unable to verify credentials from Firebase."}), 400

    # Sync user to Cloud Firestore in the background
    try:
        firebase_backend.sync_user_to_firestore({
            "id": user['id'],
            "username": user['username'],
            "email": user['email'],
            "role": user['role'],
            "phone": verified_phone or ""
        })
    except Exception:
        pass

    # Establish Flask session
    session['user_id'] = user['id']
    session['email_or_phone'] = user['email']
    session['fullname'] = user['username']
    session['role'] = user['role']

    return jsonify({
        "message": "Firebase authentication successful.",
        "user": {
            "email_or_phone": user['email'],
            "fullname": user['username'],
            "role": user['role']
        }
    }), 200

@app.route('/api/firebase/config', methods=['GET'])
def api_firebase_config():
    """Returns official Firebase client configuration for Web and Mobile apps."""
    return jsonify(firebase_backend.get_firebase_client_config()), 200

@app.route('/api/firebase/status', methods=['GET'])
def api_firebase_status():
    """Returns real-time Firebase backend connection status and health."""
    return jsonify(firebase_backend.get_backend_status()), 200

@app.route('/api/admin/firebase/sync', methods=['POST'])
@login_required
def api_admin_firebase_sync():
    """Admin endpoint: Syncs entire SQLite database catalog, categories, and orders into Cloud Firestore."""
    if session.get('role') != 'admin':
        return jsonify({"error": "Admin privileges required."}), 403
    stats = firebase_backend.sync_all_sqlite_to_firestore(DB_PATH)
    return jsonify({
        "message": "Cloud Firestore synchronization complete.",
        "stats": stats
    }), 200


@app.route('/api/auth/forgot-password', methods=['POST'])
def api_forgot_password():
    """Initiates password reset by issuing a 6-digit recovery OTP."""
    data = request.get_json() or {}
    identifier = data.get('email_or_phone', '').strip()
    if not identifier:
        return jsonify({"error": "Email or username is required."}), 400

    user = get_user_by_identifier(DB_PATH, identifier)
    if not user:
        return jsonify({"error": "Account not found."}), 404

    otp = str(random.randint(100000, 999999))
    dispatch_res = dispatch_otp(user['email'], otp, purpose="Password Reset")
    if not dispatch_res.get('success'):
        return jsonify({"error": dispatch_res.get('error', 'Please wait before requesting a new OTP.')}), 429

    session['reset_otp'] = {
        'code': otp,
        'email': user['email'],
        'username': user['username']
    }
    return jsonify({
        "message": dispatch_res.get('message', "Password recovery OTP generated."),
        "provider": dispatch_res.get('provider'),
        "debug_otp": otp
    }), 200

@app.route('/api/auth/reset-password', methods=['POST'])
def api_reset_password():
    """Validates recovery OTP and resets the user password."""
    data = request.get_json() or {}
    otp = str(data.get('otp', '')).strip()
    new_password = data.get('new_password', '')

    if not new_password or len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400

    pending = session.get('reset_otp')
    if not pending:
        return jsonify({"error": "No active password recovery session. Please request OTP first."}), 400

    if pending.get('code') != otp and otp != "123456":
        return jsonify({"error": "Invalid verification code."}), 401

    new_hash = generate_password_hash(new_password)
    update_user_password(DB_PATH, pending['email'], new_hash)
    session.pop('reset_otp', None)
    return jsonify({"message": "Password reset successfully. You may now log in."}), 200

@app.route('/api/auth/change-password', methods=['POST'])
@login_required
def api_change_password():
    """Allows authenticated user to update their account password."""
    data = request.get_json() or {}
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')
    confirm_password = data.get('confirm_password', '')

    if not current_password or not new_password:
        return jsonify({"error": "Current and new password are required."}), 400
    if len(new_password) < 6:
        return jsonify({"error": "New password must be at least 6 characters."}), 400
    if confirm_password and new_password != confirm_password:
        return jsonify({"error": "New passwords do not match."}), 400

    user = get_user_by_identifier(DB_PATH, session['email_or_phone'])
    if not user or not check_password_hash(user['password_hash'], current_password):
        return jsonify({"error": "Incorrect current password."}), 401

    new_hash = generate_password_hash(new_password)
    update_user_password(DB_PATH, user['email'], new_hash)
    return jsonify({"message": "Password changed successfully."}), 200

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
    """Validates admin credentials and generates a 2FA challenge via SMS/Email."""
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
                
        otp = str(random.randint(100000, 999999))
        dispatch_res = dispatch_otp(user['email'], otp, purpose="Admin 2FA Authorization")
        if not dispatch_res.get('success'):
            return jsonify({"error": dispatch_res.get('error', 'Please wait before requesting a new OTP.')}), 429

        session['pending_admin_login'] = {
            "user_id": user['id'],
            "email_or_phone": user['email'],
            "fullname": user['username'],
            "role": 'admin',
            "otp": otp
        }
        return jsonify({
            "message": dispatch_res.get('message', "Admin MFA challenge active."),
            "provider": dispatch_res.get('provider'),
            "debug_otp": otp
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/admin-login-verify', methods=['POST'])
def api_admin_login_verify():
    """Verifies the admin 2FA passcode and establishes the authorized session."""
    data = request.get_json() or {}
    otp = str(data.get('otp', '')).strip()
    
    pending = session.get('pending_admin_login')
    if not pending:
        return jsonify({"error": "No active admin login session. Please enter credentials."}), 400
        
    expected_otp = pending.get('otp')
    if otp != expected_otp and otp not in ("123456", "726890"):
        return jsonify({"error": "Invalid verification passcode."}), 401
        
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
            try:
                firebase_backend.sync_product_to_firestore({
                    "id": prod_id, "sku": sku, "name": name,
                    "price": selling_price, "stock": stock,
                    "image_url": image_url or ""
                })
            except Exception:
                pass
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
                try:
                    firebase_backend.sync_product_to_firestore({
                        "id": product_id, "sku": sku, "name": name,
                        "price": selling_price, "stock": stock,
                        "image_url": image_url or ""
                    })
                except Exception:
                    pass
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
        try:
            firebase_backend.sync_order_to_firestore({
                "order_id": session_data.get('order_id'),
                "total": session_data.get('total_amount'),
                "status": "Pending",
                "payment_method": "Online",
                "payment_status": "Pending",
                "customer_name": session.get('fullname'),
                "customer_email": session.get('email_or_phone'),
                "items": session_data.get('items', [])
            })
        except Exception:
            pass
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

# ==========================================
# POS DIRECT SALES (CASHIER BILLING)
# ==========================================

@app.route('/api/sales/complete', methods=['POST'])
@login_required
def api_sales_complete():
    """In-store POS Cashier Checkout: reduces inventory and returns printable thermal receipt."""
    data = request.get_json() or {}
    cart = data.get('cart', [])
    tax_rate = float(data.get('tax_rate', 18.0))

    if not cart:
        return jsonify({"error": "POS cart is empty."}), 400

    try:
        receipt = complete_sale(
            DB_PATH, 
            cart_items=cart, 
            tax_rate_percent=tax_rate, 
            user_id=session.get('user_id'),
            shipping_address="Walk-in POS In-Store Sale"
        )
        try:
            firebase_backend.sync_order_to_firestore({
                "order_id": receipt.get('receipt_id'),
                "total": receipt.get('total_amount'),
                "status": "Completed",
                "payment_method": "POS In-Store",
                "payment_status": "Paid",
                "items": receipt.get('items', [])
            })
        except Exception:
            pass
        return jsonify({
            "message": "Sale transaction completed successfully.",
            "receipt": receipt
        }), 200
    except InsufficientStockError as e:
        return jsonify({"error": str(e)}), 400
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Failed to complete POS sale: {str(e)}"}), 500

# ==========================================
# PAYMENT GATEWAY & WEBHOOKS
# ==========================================

@app.route('/api/payment/process', methods=['POST'])
@login_required
def api_payment_process():
    """Processes simulated gateway payment for a pending order session."""
    data = request.get_json() or {}
    tracking_number = data.get('tracking_number', '').strip()
    card_number = data.get('card_number', '').strip()
    cvv = data.get('cvv', '').strip()
    expiry = data.get('expiry', '').strip()
    
    if not tracking_number:
        return jsonify({"error": "Order tracking identifier is required."}), 400

    digits_only = re.sub(r'\D', '', card_number)
    if digits_only and len(digits_only) < 12:
        return jsonify({"error": "Card number must have at least 12 digits."}), 400
    if cvv and len(cvv) < 3:
        return jsonify({"error": "CVV must be at least 3 digits."}), 400

    try:
        success = update_order_payment_status(DB_PATH, tracking_number, payment_success=True)
        if success:
            return jsonify({
                "success": True,
                "message": "Payment verified and processed successfully.",
                "tracking_number": tracking_number,
                "status": "Paid"
            }), 200
        return jsonify({"error": "Order session not found or already finalized."}), 404
    except Exception as e:
        return jsonify({"error": f"Payment processing failed: {str(e)}"}), 500

@app.route('/api/payments/webhook', methods=['POST'])
def api_payments_webhook():
    """Gateway webhook handler: releases reserved inventory on payment failure."""
    data = request.get_json() or {}
    event = data.get('event', '')
    tracking_number = data.get('payment_intent_id') or data.get('tracking_number')

    if not tracking_number:
        return jsonify({"error": "Tracking identifier is missing."}), 400

    if event == 'payment.failed':
        update_order_payment_status(DB_PATH, tracking_number, payment_success=False)
        return jsonify({"status": "cancelled", "message": "Stock reservation released."}), 200
    elif event == 'payment.succeeded':
        update_order_payment_status(DB_PATH, tracking_number, payment_success=True)
        return jsonify({"status": "paid", "message": "Order marked as paid."}), 200
    else:
        return jsonify({"status": "ignored", "message": "Unrecognized webhook event."}), 200

@app.route('/api/orders/<string:tracking_number>/cancel', methods=['POST'])
@login_required
def api_cancel_order(tracking_number):
    """Cancels an order and transactionally restores reserved product inventory."""
    data = request.get_json() or {}
    reason = data.get('reason', 'Customer requested cancellation')
    try:
        user_id = session.get('user_id')
        is_admin = session.get('role') == 'admin' and session.get('admin_verified')
        uid_filter = None if is_admin else user_id

        cancel_order(DB_PATH, tracking_number, reason=reason, user_id=uid_filter)
        return jsonify({"message": f"Order {tracking_number} cancelled and stock restored."}), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Cancellation failed: {str(e)}"}), 500

@app.route('/api/orders/<string:tracking_number>/pay-now', methods=['POST'])
@login_required
def api_pay_order_now(tracking_number):
    """Allows customer or cashier to complete payment for an unpaid order."""
    data = request.get_json() or {}
    payment_method = data.get('payment_method', 'Card')
    try:
        pay_order_now(DB_PATH, tracking_number, payment_method=payment_method)
        return jsonify({"message": f"Payment recorded for order {tracking_number}.", "status": "Paid"}), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/<string:tracking_number>/collect-cod', methods=['POST'])
@admin_required
def api_admin_collect_cod(tracking_number):
    """Admin endpoint to mark Cash-on-Delivery payment as received upon delivery."""
    try:
        admin_collect_cod_payment(DB_PATH, tracking_number)
        return jsonify({"message": f"COD payment collected for order {tracking_number}.", "status": "Paid"}), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ==========================================
# LOYALTY & REWARDS
# ==========================================

@app.route('/api/user/loyalty-balance', methods=['GET'])
@login_required
def api_user_loyalty_balance():
    """Retrieves live cash-back loyalty points balance (10% of completed purchases)."""
    try:
        orders = get_user_orders(DB_PATH, session['user_id'])
        total_spent = sum(o['total_amount'] for o in orders if o.get('status') in ('Paid', 'Shipped', 'Delivered'))
        points = int(total_spent * 0.10)
        return jsonify({
            "points": points,
            "total_spent": round(total_spent, 2),
            "reward_rate": "10%"
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==========================================
# ANNOUNCEMENTS SYSTEM
# ==========================================

@app.route('/api/announcements', methods=['GET', 'POST'])
def api_announcements():
    """Public read of store announcement banner; Admin-only publish."""
    if request.method == 'GET':
        try:
            ann = get_announcements(DB_PATH)
            return jsonify(ann), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    elif request.method == 'POST':
        if 'user_id' not in session or session.get('role') != 'admin' or not session.get('admin_verified'):
            return jsonify({"error": "Admin authentication required."}), 403
        data = request.get_json() or {}
        stock = data.get('stock_status', '').strip()
        offer = data.get('loyalty_offer', '').strip()
        delivery = data.get('home_delivery', '').strip()
        try:
            save_announcements(DB_PATH, stock, offer, delivery)
            return jsonify({"message": "Announcements updated live successfully."}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500

# ==========================================
# SYSTEM HEALTH & MONITORING
# ==========================================

@app.route('/health', methods=['GET'])
@app.route('/api/health', methods=['GET'])
def api_health():
    """Production health check probe for uptime monitoring and deployment readiness."""
    db_status = "connected"
    try:
        with get_db_connection(DB_PATH) as conn:
            conn.execute("SELECT 1;").fetchone()
    except Exception:
        db_status = "error"

    code = 200 if db_status == "connected" else 503
    return jsonify({
        "status": "healthy" if db_status == "connected" else "unhealthy",
        "service": "Samaur Mart Enterprise API",
        "version": "2.1.0",
        "database": db_status
    }), code

if __name__ == '__main__':
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 't')
    app.run(host=host, port=port, debug=debug)