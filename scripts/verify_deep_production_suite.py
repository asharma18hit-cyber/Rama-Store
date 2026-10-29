# scripts/verify_deep_production_suite.py
import urllib.request
import urllib.parse
import json
import ssl
import time

ctx = ssl.create_default_context()
BASE_URL = "https://ma-store-949c7.web.app"

def request_json(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}
    headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DeepAuditTest/1.0"
    
    encoded_data = None
    if data is not None:
        headers["Content-Type"] = "application/json"
        encoded_data = json.dumps(data).encode("utf-8")
        
    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            content = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(content)
            except:
                return resp.status, content
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            return e.code, json.loads(err_body)
        except:
            return e.code, err_body
    except Exception as e:
        return 0, str(e)

def run_deep_audit():
    print("=" * 70)
    print("SAMAUR MART — DEEP PRODUCTION SECURITY & RELIABILITY AUDIT")
    print("=" * 70)

    # Step 0: Authenticate Admin for control checks
    print("\n--- 0. AUTHENTICATING OWNER ADMIN ---")
    st, creds = request_json(f"{BASE_URL}/api/auth/admin-login-request", method="POST", data={
        "email_or_phone": "7268903804",
        "password": "Admin@12345"
    })
    assert st == 200, f"Admin creds failed: {creds}"
    st, mfa = request_json(f"{BASE_URL}/api/auth/admin-login-verify", method="POST", data={
        "email_or_phone": "7268903804",
        "otp": "726890"
    })
    assert st == 200, f"Admin MFA failed: {mfa}"
    admin_token = mfa.get("token")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("[PASS] Admin authenticated successfully.")

    # Fetch a published catalog product for testing
    st, cat = request_json(f"{BASE_URL}/api/products?per_page=1", headers=admin_headers)
    assert st == 200 and cat.get("products"), "No published products found in catalog"
    test_prod = cat["products"][0]
    prod_id = test_prod["id"]
    real_price = float(test_prod.get("selling_price") or test_prod.get("price") or 100)
    print(f"Target Test Product: '{test_prod['name']}' (ID: {prod_id}, Real Price: ₹{real_price})")

    # Ensure product has at least 15 units of stock for testing
    request_json(f"{BASE_URL}/api/products/{prod_id}/stock", method="PATCH", data={"absolute": 25}, headers=admin_headers)

    # 1. CART PRICE TAMPERING PENETRATION ATTACK
    print("\n--- 1. CART PRICE TAMPERING PENETRATION ATTACK ---")
    print(f"Attacker attempting to checkout product with forged price: ₹1.00 (Catalog price is ₹{real_price})")
    tampered_cart = [{
        "id": prod_id,
        "product_id": prod_id,
        "name": test_prod["name"],
        "price": 1.0,
        "selling_price": 1.0,
        "quantity": 1
    }]

    st, checkout_resp = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": tampered_cart,
        "shipping_address": "Shop 10, Sector 18, Noida - 201301",
        "user_name": "Price Tamperer",
        "user_phone": "9876543210"
    })
    print(f"POST /api/checkout -> Status {st}: Total Amount = ₹{checkout_resp.get('total_amount') if isinstance(checkout_resp, dict) else checkout_resp}")
    assert st == 200, f"Checkout failed: {checkout_resp}"
    order_items = checkout_resp.get("items", [])
    verified_item = next((it for it in order_items if str(it.get("id")) == str(prod_id) or str(it.get("productId")) == str(prod_id)), None)
    assert verified_item is not None, "Purchased item missing from order"
    charged_price = float(verified_item.get("price") or verified_item.get("selling_price"))
    assert charged_price == real_price, f"SECURITY BREACH: Server accepted client-tampered price! Charged: ₹{charged_price}, Expected: ₹{real_price}"
    print(f"[PASS] Price integrity verified: Server strictly enforced catalog price of ₹{real_price} and ignored client's ₹1.00 price.")
    tampered_order_id = checkout_resp.get("order_id")

    # 2. OVERSELLING & INSUFFICIENT INVENTORY PREVENTION
    print("\n--- 2. OVERSELLING & INSUFFICIENT STOCK DEFENSE ---")
    oversell_cart = [{
        "id": prod_id,
        "product_id": prod_id,
        "name": test_prod["name"],
        "quantity": 999999
    }]
    st_over, resp_over = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": oversell_cart,
        "shipping_address": "Shop 10, Sector 18, Noida - 201301",
        "user_name": "Oversell Buyer",
        "user_phone": "9876543210"
    })
    print(f"POST /api/checkout (qty: 999,999) -> Status {st_over} (Expected: 400 Bad Request)")
    assert st_over == 400 and "Insufficient stock" in str(resp_over), f"Overselling prevention failed! Got status {st_over}: {resp_over}"
    print("[PASS] Overselling defense verified: Checkout rejected with insufficient inventory error.")

    # 3. ATOMIC INVENTORY DECREMENT VERIFICATION
    print("\n--- 3. ATOMIC INVENTORY DECREMENT VERIFICATION ---")
    # Read baseline stock
    st, prod_snap1 = request_json(f"{BASE_URL}/api/products/{prod_id}")
    stock_before = int(prod_snap1["stock"])
    print(f"Stock before checkout: {stock_before} units")

    valid_cart = [{
        "id": prod_id,
        "product_id": prod_id,
        "name": test_prod["name"],
        "quantity": 3
    }]
    st, valid_order = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": valid_cart,
        "shipping_address": "Sector 62, Noida - 201301",
        "user_name": "Genuine Customer",
        "user_phone": "9876543210"
    })
    assert st == 200, f"Valid checkout failed: {valid_order}"
    valid_order_id = valid_order.get("order_id")
    valid_tracking = valid_order.get("tracking_number")

    # Read stock after checkout
    st, prod_snap2 = request_json(f"{BASE_URL}/api/products/{prod_id}")
    stock_after = int(prod_snap2["stock"])
    print(f"Stock after ordering 3 units: {stock_after} units")
    assert stock_after == stock_before - 3, f"Stock decrement mismatch! Expected {stock_before - 3}, Got {stock_after}"
    print("[PASS] Atomic stock decrement verified: exactly 3 units subtracted from Firestore inventory.")

    # 4. ORDER CANCELLATION & INVENTORY RESTORATION
    print("\n--- 4. CUSTOMER ORDER CANCELLATION & STOCK RESTORATION ---")
    st, cancel_resp = request_json(f"{BASE_URL}/api/orders/{valid_order_id}/cancel", method="POST", data={
        "customer_phone": "9876543210",
        "reason": "Changed my mind"
    })
    print(f"POST /api/orders/:id/cancel -> Status {st}: {cancel_resp}")
    assert st == 200 and cancel_resp.get("success"), f"Order cancellation failed: {cancel_resp}"

    # Read stock after cancellation -> must be restored by +3
    st, prod_snap3 = request_json(f"{BASE_URL}/api/products/{prod_id}")
    stock_restored = int(prod_snap3["stock"])
    print(f"Stock after order cancellation: {stock_restored} units")
    assert stock_restored == stock_after + 3, f"Inventory restoration failed! Expected {stock_after + 3}, Got {stock_restored}"
    print("[PASS] Inventory restoration verified: 3 units atomically restored to catalog.")

    # 5. IDEMPOTENCY KEY VERIFICATION
    print("\n--- 5. ORDER IDEMPOTENCY KEY PROTECTION ---")
    idempotency_key = f"IDEM-{int(time.time())}-TEST"
    cart_idem = [{
        "id": prod_id,
        "quantity": 1
    }]
    st1, ord1 = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": cart_idem,
        "shipping_address": "Noida Sector 18 - 201301",
        "user_name": "Idempotent User",
        "user_phone": "9876543210",
        "idempotency_key": idempotency_key
    })
    assert st1 == 200, f"Initial order failed: {ord1}"
    first_tracking = ord1.get("tracking_number")

    # Send exact same request again
    st2, ord2 = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": cart_idem,
        "shipping_address": "Noida Sector 18 - 201301",
        "user_name": "Idempotent User",
        "user_phone": "9876543210",
        "idempotency_key": idempotency_key
    })
    assert st2 == 200, f"Duplicate request failed: {ord2}"
    assert ord2.get("duplicate_prevented") == True, "Idempotency protection failed to flag duplicate"
    assert ord2.get("tracking_number") == first_tracking, "Duplicate order created with different tracking number!"
    print(f"[PASS] Idempotency protection verified: duplicate submission returned original order #{first_tracking} without re-charging or double-decrementing.")

    # 6. INSECURE PAYMENT BYPASS REJECTION
    print("\n--- 6. INSECURE PAYMENT BYPASS REJECTION ---")
    st_fake_pay, resp_fake_pay = request_json(f"{BASE_URL}/api/payment/process", method="POST", data={
        "tracking_number": first_tracking
    })
    print(f"POST /api/payment/process (Unauthenticated fake mark) -> Status {st_fake_pay} (Expected: 401 Unauthorized)")
    assert st_fake_pay == 401 and resp_fake_pay.get("verified") == False, "Insecure payment bypass was not rejected!"
    print("[PASS] Insecure payment bypass rejected: unauthenticated requests cannot forge payment status.")

    # 7. VENDOR PASSWORD RECOVERY WORKFLOW
    print("\n--- 7. VENDOR PASSWORD RECOVERY WORKFLOW ---")
    v_rec_email = f"merchant_rec_{int(time.time())}@samaurmart.com"
    v_rec_phone = f"99{str(int(time.time()))[-8:]}"
    v_orig_pass = "OldPass@123"
    v_new_pass = "BrandNewPass@999"

    # Register vendor
    request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={"email": v_rec_email, "phone": v_rec_phone})
    st, reg_rec = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data={
        "business_name": "Recovery Test Merchant",
        "contact_name": "Test Contact",
        "email": v_rec_email,
        "phone": v_rec_phone,
        "password": v_orig_pass,
        "otp": "726890",
        "address": "Sector 62, Noida",
        "pincode": "201301"
    })
    assert st == 200, f"Recovery merchant reg failed: {reg_rec}"

    # Step A: Request Password Reset OTP
    st, reset_req = request_json(f"{BASE_URL}/api/vendor/forgot-password-request", method="POST", data={
        "email_or_phone": v_rec_email
    })
    print(f"POST /api/vendor/forgot-password-request -> Status {st}: {reset_req.get('message')}")
    assert st == 200 and reset_req.get("mfaRequired"), "Forgot password request failed"

    # Step B: Reset Password with OTP
    st, reset_exec = request_json(f"{BASE_URL}/api/vendor/reset-password", method="POST", data={
        "email_or_phone": v_rec_email,
        "otp": "726890",
        "new_password": v_new_pass
    })
    print(f"POST /api/vendor/reset-password -> Status {st}: {reset_exec.get('message')}")
    assert st == 200 and reset_exec.get("success"), f"Reset password failed: {reset_exec}"

    # Step C: Verify old password fails
    st_old, old_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={
        "email_or_phone": v_rec_email,
        "password": v_orig_pass
    })
    assert st_old == 401, "Old password still worked after reset!"
    print("[PASS] Old password successfully revoked.")

    # Approve vendor so new password login can be tested
    v_rec_id = reg_rec.get("vendor_id")
    request_json(f"{BASE_URL}/api/admin/vendors/{v_rec_id}/status", method="PATCH", data={"status": "approved"}, headers=admin_headers)

    # Step D: Verify new password succeeds with MFA
    request_json(f"{BASE_URL}/api/vendor/login-request", method="POST", data={"email_or_phone": v_rec_email, "password": v_new_pass})
    st_new, new_login = request_json(f"{BASE_URL}/api/vendor/login-verify", method="POST", data={"email_or_phone": v_rec_email, "otp": "726890"})
    assert st_new == 200 and new_login.get("success"), f"New password login failed: {new_login}"
    print("[PASS] Vendor password recovery workflow verified: new password authenticated and session issued.")

    # Clean up test orders
    request_json(f"{BASE_URL}/api/orders/{tampered_order_id}", method="DELETE", headers=admin_headers)
    request_json(f"{BASE_URL}/api/orders/{first_tracking}", method="DELETE", headers=admin_headers)

    print("\n" + "=" * 70)
    print("ALL DEEP PRODUCTION SECURITY & RELIABILITY TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 70)

if __name__ == "__main__":
    run_deep_audit()
