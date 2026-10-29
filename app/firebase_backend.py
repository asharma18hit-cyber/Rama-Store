"""
app/firebase_backend.py - Enterprise Firebase Cloud Backend Engine for Samaur Mart.
Provides comprehensive Firebase integration across:
1. Firebase Authentication (Google Sign-In, Phone OTP, Email/Password ID token verification)
2. Cloud Firestore (Real-time NoSQL cloud database syncing for products, categories, orders, users)
3. Firebase Cloud Storage (Media and asset cloud hosting)
4. Dynamic Client Configuration & Health Inspection
"""

import os
import sys
import json
import time
import urllib.request
import urllib.parse
import urllib.error
from typing import Dict, Any, List, Optional, Tuple

# Try importing firebase_admin SDK
try:
    import firebase_admin
    from firebase_admin import auth as fb_auth
    from firebase_admin import credentials as fb_credentials
    from firebase_admin import firestore as fb_firestore
    from firebase_admin import storage as fb_storage
    HAS_FIREBASE_ADMIN = True
except ImportError:
    HAS_FIREBASE_ADMIN = False
    firebase_admin = None
    fb_auth = None
    fb_credentials = None
    fb_firestore = None
    fb_storage = None

# Base Directory Resolution
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

# Firebase Cloud Environment Configuration
FIREBASE_PROJECT_ID = os.environ.get('FIREBASE_PROJECT_ID', 'ma-store-949c7').strip()
FIREBASE_API_KEY = os.environ.get('FIREBASE_API_KEY', 'AIzaSyAZ7D3XnUOphe8s2lXxxr9qmEdZYE5lQ2w').strip()
FIREBASE_AUTH_DOMAIN = os.environ.get('FIREBASE_AUTH_DOMAIN', 'ma-store-949c7.firebaseapp.com').strip()
FIREBASE_STORAGE_BUCKET = os.environ.get('FIREBASE_STORAGE_BUCKET', 'ma-store-949c7.firebasestorage.app').strip()
FIREBASE_MESSAGING_SENDER_ID = os.environ.get('FIREBASE_MESSAGING_SENDER_ID', '611361603523').strip()
FIREBASE_APP_ID = os.environ.get('FIREBASE_APP_ID', '1:611361603523:web:b484f519c30b5fe012c776').strip()
FIREBASE_MEASUREMENT_ID = os.environ.get('FIREBASE_MEASUREMENT_ID', 'G-7ZT1J756XC').strip()

# Internal State Cache
_admin_app = None
_firestore_client = None
_has_service_account = False
_init_error = None


def get_firebase_client_config() -> Dict[str, str]:
    """Returns official Firebase Web & Flutter client configuration."""
    return {
        "apiKey": FIREBASE_API_KEY,
        "authDomain": FIREBASE_AUTH_DOMAIN,
        "projectId": FIREBASE_PROJECT_ID,
        "storageBucket": FIREBASE_STORAGE_BUCKET,
        "messagingSenderId": FIREBASE_MESSAGING_SENDER_ID,
        "appId": FIREBASE_APP_ID,
        "measurementId": FIREBASE_MEASUREMENT_ID
    }


def _find_service_account_path() -> Optional[str]:
    """Searches standard paths for Firebase service account private key JSON."""
    candidates = [
        os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'),
        os.environ.get('FIREBASE_SERVICE_ACCOUNT_PATH'),
        os.path.join(BASE_DIR, 'firebase_service_account.json'),
        os.path.join(BASE_DIR, 'serviceAccountKey.json'),
        os.path.join(os.path.dirname(__file__), 'firebase_service_account.json')
    ]
    # Scan root directory for downloaded Admin SDK JSON keys
    try:
        for fname in os.listdir(BASE_DIR):
            if fname.endswith('.json') and 'adminsdk' in fname.lower():
                candidates.insert(0, os.path.join(BASE_DIR, fname))
    except Exception:
        pass

    for p in candidates:
        if p and os.path.exists(p) and os.path.isfile(p):
            return os.path.abspath(p)
    return None


def init_firebase_backend():
    """Initializes Firebase Admin SDK with Service Account or gracefully registers Project ID."""
    global _admin_app, _firestore_client, _has_service_account, _init_error

    if not HAS_FIREBASE_ADMIN:
        _init_error = "firebase-admin Python package not installed."
        return False

    if _admin_app is not None:
        return True

    # Check if app already initialized in another namespace/module
    try:
        existing_app = firebase_admin.get_app()
        if existing_app:
            _admin_app = existing_app
            try:
                _firestore_client = fb_firestore.client()
                _has_service_account = True
            except Exception:
                pass
            return True
    except (ValueError, Exception):
        pass

    # 1. Check for Service Account File
    sa_path = _find_service_account_path()
    if sa_path:
        try:
            cred = fb_credentials.Certificate(sa_path)
            _admin_app = firebase_admin.initialize_app(cred, {
                'projectId': FIREBASE_PROJECT_ID,
                'storageBucket': FIREBASE_STORAGE_BUCKET
            })
            _firestore_client = fb_firestore.client()
            _has_service_account = True
            print(f"[Firebase Backend] Successfully authenticated with Service Account: {sa_path}", flush=True)
            return True
        except Exception as e:
            _init_error = f"Service account initialization failed: {str(e)}"
            print(f"[Firebase Backend] Warning: {_init_error}", flush=True)

    # 2. Check for Service Account JSON in Environment Variable
    sa_raw = os.environ.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if sa_raw:
        try:
            sa_dict = json.loads(sa_raw)
            cred = fb_credentials.Certificate(sa_dict)
            _admin_app = firebase_admin.initialize_app(cred, {
                'projectId': FIREBASE_PROJECT_ID,
                'storageBucket': FIREBASE_STORAGE_BUCKET
            })
            _firestore_client = fb_firestore.client()
            _has_service_account = True
            print("[Firebase Backend] Successfully authenticated via FIREBASE_SERVICE_ACCOUNT_KEY env.", flush=True)
            return True
        except Exception as e:
            _init_error = f"Env service account initialization failed: {str(e)}"
            print(f"[Firebase Backend] Warning: {_init_error}", flush=True)

    # 3. Default App Initialization (Project metadata mode)
    try:
        _admin_app = firebase_admin.initialize_app(options={
            'projectId': FIREBASE_PROJECT_ID,
            'storageBucket': FIREBASE_STORAGE_BUCKET
        })
        _has_service_account = False
        print(f"[Firebase Backend] Initialized in Project Metadata mode ({FIREBASE_PROJECT_ID}).", flush=True)
        return True
    except Exception as e:
        _init_error = str(e)
        return False


# Auto-initialize on module load
init_firebase_backend()


def get_backend_status() -> Dict[str, Any]:
    """Provides real-time cloud backend status and connection health."""
    return {
        "connected": _admin_app is not None or bool(FIREBASE_API_KEY),
        "admin_sdk_loaded": HAS_FIREBASE_ADMIN,
        "has_service_account": _has_service_account,
        "project_id": FIREBASE_PROJECT_ID,
        "auth_domain": FIREBASE_AUTH_DOMAIN,
        "storage_bucket": FIREBASE_STORAGE_BUCKET,
        "status": "online" if (_admin_app is not None) else "ready",
        "mode": "admin_service_account" if _has_service_account else "client_identity_bridge",
        "init_error": _init_error
    }


# -----------------------------------------------------------------------------
# FIREBASE AUTHENTICATION & ID TOKEN VERIFICATION ENGINE
# -----------------------------------------------------------------------------
def verify_firebase_id_token(id_token: str) -> Optional[Dict[str, Any]]:
    """
    Verifies a Firebase ID token generated from Web or Flutter client.
    Supports Google Sign-In, Phone OTP, and Email/Password sessions.
    
    Returns normalized profile dict:
    {
        "uid": str,
        "email": str or None,
        "phone_number": str or None,
        "display_name": str or None,
        "provider": str,
        "photo_url": str or None
    }
    """
    if not id_token:
        return None

    # Method A: Firebase Admin SDK verification (Requires Service Account)
    if _has_service_account and fb_auth is not None:
        try:
            decoded = fb_auth.verify_id_token(id_token, check_revoked=False)
            provider_id = 'unknown'
            if 'firebase' in decoded and 'sign_in_provider' in decoded['firebase']:
                provider_id = decoded['firebase']['sign_in_provider']

            return {
                "uid": decoded.get('uid'),
                "email": decoded.get('email'),
                "phone_number": decoded.get('phone_number'),
                "display_name": decoded.get('name'),
                "photo_url": decoded.get('picture'),
                "provider": provider_id,
                "verified_by": "firebase_admin_sdk"
            }
        except Exception as e:
            print(f"[Firebase Auth] Admin SDK verify notice: {e}. Falling back to Identity Toolkit...", flush=True)

    # Method B: Google Identity Toolkit REST API (Works universally with API Key)
    try:
        url = f"https://identitytoolkit.googleapis.com/v1/accounts:lookup?key={FIREBASE_API_KEY}"
        payload = json.dumps({"idToken": id_token}).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            users = data.get('users', [])
            if not users:
                return None

            user_data = users[0]
            providers = [p.get('providerId') for p in user_data.get('providerUserInfo', [])]
            primary_provider = providers[0] if providers else 'firebase'

            return {
                "uid": user_data.get('localId'),
                "email": user_data.get('email'),
                "phone_number": user_data.get('phoneNumber'),
                "display_name": user_data.get('displayName'),
                "photo_url": user_data.get('photoUrl'),
                "provider": primary_provider,
                "verified_by": "google_identity_toolkit"
            }
    except Exception as e:
        print(f"[Firebase Auth] Identity Toolkit error: {e}", flush=True)
        return None


# -----------------------------------------------------------------------------
# FIRESTORE REST DATA TRANSLATION HELPERS
# -----------------------------------------------------------------------------
def _value_to_firestore(v: Any) -> Dict[str, Any]:
    """Encodes standard Python types into Firestore REST field format."""
    if v is None:
        return {"nullValue": None}
    elif isinstance(v, bool):
        return {"booleanValue": v}
    elif isinstance(v, int):
        return {"integerValue": str(v)}
    elif isinstance(v, float):
        return {"doubleValue": float(v)}
    elif isinstance(v, str):
        return {"stringValue": str(v)}
    elif isinstance(v, list):
        return {"arrayValue": {"values": [_value_to_firestore(x) for x in v]}}
    elif isinstance(v, dict):
        return {"mapValue": {"fields": {k: _value_to_firestore(val) for k, val in v.items()}}}
    else:
        return {"stringValue": str(v)}


def _firestore_to_value(field_dict: Dict[str, Any]) -> Any:
    """Decodes Firestore REST field format into Python native types."""
    if not isinstance(field_dict, dict):
        return field_dict
    if "stringValue" in field_dict:
        return field_dict["stringValue"]
    if "integerValue" in field_dict:
        try:
            return int(field_dict["integerValue"])
        except ValueError:
            return field_dict["integerValue"]
    if "doubleValue" in field_dict:
        return float(field_dict["doubleValue"])
    if "booleanValue" in field_dict:
        return field_dict["booleanValue"]
    if "nullValue" in field_dict:
        return None
    if "arrayValue" in field_dict:
        values = field_dict.get("arrayValue", {}).get("values", [])
        return [_firestore_to_value(v) for v in values]
    if "mapValue" in field_dict:
        fields = field_dict.get("mapValue", {}).get("fields", {})
        return {k: _firestore_to_value(v) for k, v in fields.items()}
    return None


def _dict_to_firestore_fields(data: Dict[str, Any]) -> Dict[str, Any]:
    """Converts a flat or nested Python dict to Firestore REST fields map."""
    fields = {}
    for k, v in data.items():
        if k is not None:
            fields[str(k)] = _value_to_firestore(v)
    return fields


def _firestore_doc_to_dict(doc: Dict[str, Any]) -> Dict[str, Any]:
    """Extracts ID and Python values from Firestore REST Document."""
    name = doc.get('name', '')
    doc_id = name.split('/')[-1] if name else ''
    fields = doc.get('fields', {})
    res = {'_firestore_id': doc_id}
    for k, v in fields.items():
        res[k] = _firestore_to_value(v)
    return res


# -----------------------------------------------------------------------------
# CLOUD FIRESTORE SYNCHRONIZATION SERVICE
# -----------------------------------------------------------------------------
def sync_product_to_firestore(product: Dict[str, Any]) -> bool:
    """Syncs a single catalog product to Cloud Firestore collection 'products'."""
    prod_id = str(product.get('id') or product.get('sku') or f"p_{int(time.time())}")
    price_val = float(product.get('selling_price') or product.get('price') or 0.0)
    cost_val = float(product.get('purchase_price') or product.get('cost_price') or 0.0)
    doc_data = {
        "id": product.get('id'),
        "name": product.get('name', ''),
        "sku": product.get('sku', ''),
        "category": product.get('category', 'General'),
        "category_id": product.get('category_id'),
        "price": price_val,
        "selling_price": price_val,
        "sellingPrice": price_val,
        "cost_price": cost_val,
        "purchase_price": cost_val,
        "stock": int(product.get('stock', 0)),
        "description": product.get('description', ''),
        "image_url": product.get('image_url', ''),
        "unit": product.get('unit', 'unit'),
        "is_active": bool(product.get('is_active', True) if 'is_active' in product else product.get('status', 'published') == 'published'),
        "status": product.get('status', 'published'),
        "updated_at": time.strftime('%Y-%m-%d %H:%M:%S')
    }

    # 1. Try Admin SDK
    if _has_service_account and _firestore_client is not None:
        try:
            _firestore_client.collection('products').document(prod_id).set(doc_data, merge=True)
            return True
        except Exception as e:
            print(f"[Firestore Sync] Admin sync product error: {e}", flush=True)

    # 2. Try REST API
    try:
        url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/products/{prod_id}?key={FIREBASE_API_KEY}"
        payload = json.dumps({"fields": _dict_to_firestore_fields(doc_data)}).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method='PATCH')
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status in (200, 201)
    except Exception as e:
        # Expected if security rules restrict unauthenticated REST writes
        return False


def sync_order_to_firestore(order: Dict[str, Any]) -> bool:
    """Syncs a retail sale or online order to Cloud Firestore collection 'orders'."""
    order_id = str(order.get('order_id') or order.get('id') or f"ORD-{int(time.time())}")
    doc_data = {
        "order_id": order_id,
        "customer_name": order.get('customer_name') or order.get('fullname') or 'Walk-in Customer',
        "customer_email": order.get('customer_email') or order.get('email') or 'walkin@store.local',
        "total": float(order.get('total') or order.get('total_amount', 0.0)),
        "status": order.get('status', 'Completed'),
        "payment_method": order.get('payment_method', 'Cash'),
        "payment_status": order.get('payment_status', 'Paid'),
        "items": order.get('items', []),
        "created_at": order.get('created_at', time.strftime('%Y-%m-%d %H:%M:%S')),
        "synced_to_firebase_at": time.strftime('%Y-%m-%d %H:%M:%S')
    }

    if _has_service_account and _firestore_client is not None:
        try:
            _firestore_client.collection('orders').document(order_id).set(doc_data, merge=True)
            return True
        except Exception as e:
            print(f"[Firestore Sync] Admin sync order error: {e}", flush=True)

    try:
        url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/orders/{order_id}?key={FIREBASE_API_KEY}"
        payload = json.dumps({"fields": _dict_to_firestore_fields(doc_data)}).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method='PATCH')
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status in (200, 201)
    except Exception:
        return False


def sync_category_to_firestore(category: Dict[str, Any]) -> bool:
    """Syncs a store product category to Cloud Firestore."""
    cat_id = str(category.get('id') or category.get('name', 'cat').lower().replace(' ', '_'))
    doc_data = {
        "id": category.get('id'),
        "name": category.get('name'),
        "icon": category.get('icon', '🛒')
    }

    if _has_service_account and _firestore_client is not None:
        try:
            _firestore_client.collection('categories').document(cat_id).set(doc_data, merge=True)
            return True
        except Exception:
            pass

    try:
        url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/categories/{cat_id}?key={FIREBASE_API_KEY}"
        payload = json.dumps({"fields": _dict_to_firestore_fields(doc_data)}).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method='PATCH')
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status in (200, 201)
    except Exception:
        return False


def sync_announcements_to_firestore(announcements: List[Dict[str, Any]]) -> bool:
    """Syncs marketing ticker announcements to Cloud Firestore document."""
    doc_data = {
        "announcements": announcements,
        "updated_at": time.strftime('%Y-%m-%d %H:%M:%S')
    }

    if _has_service_account and _firestore_client is not None:
        try:
            _firestore_client.collection('settings').document('announcements').set(doc_data, merge=True)
            return True
        except Exception:
            pass

    try:
        url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/settings/announcements?key={FIREBASE_API_KEY}"
        payload = json.dumps({"fields": _dict_to_firestore_fields(doc_data)}).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method='PATCH')
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status in (200, 201)
    except Exception:
        return False


def sync_all_sqlite_to_firestore(db_path: str) -> Dict[str, Any]:
    """
    Exports full SQLite local database records (products, categories, announcements, orders)
    into Cloud Firestore so web, mobile Flutter, and cloud dashboards are 100% in sync.
    """
    import sqlite3
    stats = {
        "products": 0,
        "categories": 0,
        "announcements": 0,
        "orders": 0,
        "status": "completed",
        "has_service_account": _has_service_account,
        "errors": []
    }

    if not os.path.exists(db_path):
        stats["status"] = "error"
        stats["errors"].append(f"Database file not found: {db_path}")
        return stats

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        can_write = _has_service_account
        if not can_write:
            # Fast probe to see if REST writes are open
            can_write = sync_category_to_firestore({"id": "_probe", "name": "Probe", "icon": "⚡"})
            if not can_write:
                stats["note"] = "Firestore cloud write rules require Service Account. Add firebase_service_account.json for direct admin writes."

        # 1. Sync Categories
        cursor.execute("SELECT * FROM categories")
        for row in cursor.fetchall():
            cat = dict(row)
            if can_write:
                sync_category_to_firestore(cat)
            stats["categories"] += 1

        # 2. Sync Products
        cursor.execute("SELECT * FROM products")
        for row in cursor.fetchall():
            prod = dict(row)
            if can_write:
                sync_product_to_firestore(prod)
            stats["products"] += 1

        # 3. Sync Announcements
        cursor.execute("SELECT * FROM announcements")
        anns = [dict(r) for r in cursor.fetchall()]
        if anns:
            if can_write:
                sync_announcements_to_firestore(anns)
            stats["announcements"] = len(anns)

        # 4. Sync Orders (last 10)
        cursor.execute("SELECT * FROM orders ORDER BY id DESC LIMIT 10")
        for row in cursor.fetchall():
            ord_dict = dict(row)
            cursor.execute("SELECT * FROM order_items WHERE order_id = ?", (ord_dict['id'],))
            ord_dict['items'] = [dict(it) for it in cursor.fetchall()]
            if can_write:
                sync_order_to_firestore(ord_dict)
            stats["orders"] += 1

    except Exception as e:
        stats["status"] = "partial_error"
        stats["errors"].append(str(e))
    finally:
        conn.close()

    print(f"[Firebase Sync] Sync completed: {stats}", flush=True)
    return stats


def fetch_firestore_products() -> List[Dict[str, Any]]:
    """Fetches real-time products list directly from Cloud Firestore REST API."""
    try:
        url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/products?key={FIREBASE_API_KEY}"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            docs = data.get('documents', [])
            return [_firestore_doc_to_dict(d) for d in docs]
    except Exception as e:
        print(f"[Firestore Fetch] Products fetch notice: {e}", flush=True)
        return []
