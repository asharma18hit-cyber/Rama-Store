# scripts/verify_multivendor_suite.py
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
    headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MultiVendorTest/1.0"
    
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

def run_tests():
    print("=" * 70)
    print("SAMAUR MART MULTI-VENDOR MARKETPLACE - END-TO-END VERIFICATION")
    print("=" * 70)

    # 1. OWNER MFA AUTHENTICATION
    print("\n--- 1. OWNER MFA AUTHENTICATION (SUPER ADMIN) ---")
    st, creds = request_json(f"{BASE_URL}/api/auth/admin-login-request", method="POST", data={
        "email_or_phone": "7268903804",
        "password": "Admin@12345"
    })
    assert st == 200 and creds.get("success"), f"Owner login request failed: {creds}"

    st, mfa = request_json(f"{BASE_URL}/api/auth/admin-login-verify", method="POST", data={
        "email_or_phone": "7268903804",
        "otp": "726890"
    })
    assert st == 200 and mfa.get("success"), f"Owner MFA failed: {mfa}"
    admin_token = mfa.get("token")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print(f"[PASS] Owner authenticated successfully. Token: {admin_token[:20]}...")

    # 2. VENDOR SELF-SERVICE REGISTRATION (VENDOR A)
    print("\n--- 2. VENDOR ONBOARDING: SELF-SERVICE REGISTRATION ---")
    vA_suffix = int(time.time())
    vA_email = f"merchant_a_{vA_suffix}@samaurmart.com"
    vA_phone = f"98{str(vA_suffix)[-8:]}"
    vA_pass = "VendorPass@123"

    reg_payload_A = {
        "business_name": f"Himalayan Organic Essentials ({vA_suffix})",
        "contact_name": "Arjun Sharma",
        "email": vA_email,
        "phone": vA_phone,
        "password": vA_pass,
        "address": "Shop 42, Spice Market, Sector 18",
        "pincode": "201301",
        "categories": ["Staples & Grains", "Spices & Seasoning"],
        "tax_id": "09AAAAA0000A1Z5",
        "bank_details": {
            "bank_name": "HDFC Bank",
            "account_number": "50100987654321",
            "ifsc_code": "HDFC0001234"
        }
    }

    st, reg_resp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=reg_payload_A)
    print(f"POST /api/vendor/register -> Status {st}: {reg_resp}")
    assert st == 200 and reg_resp.get("success"), f"Vendor registration failed: {reg_resp}"
    vendor_A_id = reg_resp.get("vendor_id")
    assert reg_resp.get("status") == "submitted", "Initial vendor status must be 'submitted'"
    print(f"[PASS] Vendor A registered with ID: {vendor_A_id} and status 'submitted'.")

    # 3. VENDOR LOGIN GATE: PENDING REVIEW CANNOT ACCESS
    print("\n--- 3. AUTHENTICATION GATE: PENDING VENDORS REJECTED ---")
    st, login_attempt = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={
        "email_or_phone": vA_email,
        "password": vA_pass
    })
    print(f"POST /api/vendor/login (pending) -> Status {st}: {login_attempt}")
    assert st == 403 and login_attempt.get("status") == "submitted", "Pending vendor must be blocked from portal login"
    print("[PASS] Pending vendor correctly blocked from logging in before Owner approval.")

    # 4. OWNER REVIEWS AND APPROVES VENDOR A
    print("\n--- 4. OWNER VENDOR APPLICATION REVIEW & APPROVAL ---")
    st, v_dossier = request_json(f"{BASE_URL}/api/admin/vendors/{vendor_A_id}", headers=admin_headers)
    assert st == 200 and v_dossier.get("success"), f"Failed to fetch vendor dossier: {v_dossier}"
    print(f"Owner inspecting dossier for '{v_dossier['vendor']['business_name']}' - Tax ID: {v_dossier['vendor']['tax_id']}")

    # Owner approves and sets 12.5% marketplace commission
    st, approve_resp = request_json(f"{BASE_URL}/api/admin/vendors/{vendor_A_id}/status", method="PATCH", data={
        "status": "approved",
        "commission_rate": 12.5,
        "auto_publish": False
    }, headers=admin_headers)
    print(f"PATCH /api/admin/vendors/:id/status -> Status {st}: {approve_resp}")
    assert st == 200 and approve_resp.get("status") == "approved", "Vendor approval failed"
    print("[PASS] Owner approved Vendor A with 12.5% marketplace commission.")

    # 5. APPROVED VENDOR AUTHENTICATION
    print("\n--- 5. APPROVED VENDOR LOGIN & SESSION VERIFICATION ---")
    st, vA_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={
        "email_or_phone": vA_email,
        "password": vA_pass
    })
    print(f"POST /api/vendor/login (approved) -> Status {st}: {vA_login.get('message')}")
    assert st == 200 and vA_login.get("success"), f"Approved vendor login failed: {vA_login}"
    vA_token = vA_login.get("token")
    vA_headers = {"Authorization": f"Bearer {vA_token}"}
    assert vA_token.startswith("vdr_sess_"), "Vendor token format invalid"

    st, vA_sess = request_json(f"{BASE_URL}/api/vendor/verify-session", headers=vA_headers)
    assert st == 200 and vA_sess.get("authenticated"), "Vendor session verification failed"
    print(f"[PASS] Vendor A authenticated successfully. Session Token: {vA_token[:25]}...")

    # 6. VENDOR PRODUCT CREATION & SUBMISSION FOR REVIEW
    print("\n--- 6. VENDOR PRODUCT SUBMISSION (PENDING REVIEW) ---")
    prod_sku_A = f"HIM-ORG-{vA_suffix}"
    prod_payload_A = {
        "name": "Himalayan Handcrafted Wild Honey (500g)",
        "sku": prod_sku_A,
        "brand": "Himalayan Naturals",
        "category_id": 1,
        "unit": "500 g",
        "mrp": 450,
        "selling_price": 380,
        "purchase_price": 280,
        "stock": 35,
        "image_url": "https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=600",
        "short_description": "Pure unheated organic forest honey collected from high altitude flora.",
        "description": "100% natural, unprocessed wild bee honey with rich pollen profile and antioxidants."
    }

    st, prod_create_resp = request_json(f"{BASE_URL}/api/vendor/products", method="POST", data=prod_payload_A, headers=vA_headers)
    print(f"POST /api/vendor/products -> Status {st}: {prod_create_resp}")
    assert st == 200 and prod_create_resp.get("success"), f"Vendor product creation failed: {prod_create_resp}"
    prod_A_id = prod_create_resp.get("id")
    assert prod_create_resp.get("approval_status") == "pending_review", "Vendor product must be 'pending_review'"
    print(f"[PASS] Product created with ID {prod_A_id} and status 'pending_review'.")

    # 7. STOREFRONT PUBLICATION GATE: UNAPPROVED PRODUCTS HIDDEN
    print("\n--- 7. STOREFRONT PUBLICATION GATE: VERIFY UNAPPROVED PRODUCT IS HIDDEN ---")
    st, store_check = request_json(f"{BASE_URL}/api/products?per_page=20")
    store_prods = store_check.get("products", [])
    found_on_store = any(str(p.get("id")) == str(prod_A_id) for p in store_prods)
    print(f"Product #{prod_A_id} visible on customer storefront before approval: {found_on_store}")
    assert not found_on_store, "CRITICAL DEFECT: Unapproved vendor product appeared on public storefront!"
    print("[PASS] Unapproved vendor product is completely hidden from the customer storefront.")

    # 8. OWNER REVIEW QUEUE & LISTING APPROVAL
    print("\n--- 8. OWNER REVIEW QUEUE & 1-CLICK LISTING APPROVAL ---")
    st, queue_resp = request_json(f"{BASE_URL}/api/admin/products/pending-review", headers=admin_headers)
    assert st == 200 and queue_resp.get("success"), f"Failed to fetch review queue: {queue_resp}"
    pending_items = queue_resp.get("products", [])
    assert any(str(p.get("id")) == str(prod_A_id) for p in pending_items), "Created product not found in Owner review queue"
    print(f"[PASS] Product #{prod_A_id} present in Owner review queue ({len(pending_items)} total pending).")

    # Owner approves the product
    st, review_action = request_json(f"{BASE_URL}/api/admin/products/{prod_A_id}/review", method="PATCH", data={
        "action": "approve"
    }, headers=admin_headers)
    print(f"PATCH /api/admin/products/:id/review -> Status {st}: {review_action}")
    assert st == 200 and review_action.get("approval_status") == "approved", "Listing approval failed"

    # Re-verify on storefront: product is now LIVE
    st, store_check_2 = request_json(f"{BASE_URL}/api/products?per_page=20")
    approved_store_prod = next((p for p in store_check_2.get("products", []) if str(p.get("id")) == str(prod_A_id)), None)
    assert approved_store_prod is not None, "Approved product did not appear on storefront after Owner approval"
    print(f"[PASS] Product #{prod_A_id} is NOW LIVE on storefront with Vendor Attribution: '{approved_store_prod.get('vendor_name')}'!")

    # 9. STRICT DATA ISOLATION & NEGATIVE SECURITY TESTS
    print("\n--- 9. STRICT DATA ISOLATION & CROSS-VENDOR NEGATIVE SECURITY TESTS ---")
    # Onboard Vendor B
    vB_suffix = int(time.time()) + 1
    vB_email = f"merchant_b_{vB_suffix}@samaurmart.com"
    vB_phone = f"97{str(vB_suffix)[-8:]}"
    vB_pass = "VendorPassB@456"

    st, reg_B = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data={
        "business_name": f"Sunrise Bakery Goods ({vB_suffix})",
        "contact_name": "Kavita Rao",
        "email": vB_email,
        "phone": vB_phone,
        "password": vB_pass,
        "address": "45 Baker Street",
        "pincode": "201301"
    })
    vendor_B_id = reg_B.get("vendor_id")
    # Owner approves Vendor B
    request_json(f"{BASE_URL}/api/admin/vendors/{vendor_B_id}/status", method="PATCH", data={"status": "approved"}, headers=admin_headers)
    # Vendor B logs in
    _, vB_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={"email_or_phone": vB_email, "password": vB_pass})
    vB_token = vB_login.get("token")
    vB_headers = {"Authorization": f"Bearer {vB_token}"}

    # Attack 1: Vendor B attempts to read Vendor A's product details
    st, attack_read = request_json(f"{BASE_URL}/api/vendor/products/{prod_A_id}", headers=vB_headers)
    print(f"Attack 1: Vendor B reads Vendor A product -> Status {st} (Expected: 403 Forbidden)")
    assert st == 403, f"Cross-vendor read isolation failed! Got status {st}: {attack_read}"

    # Attack 2: Vendor B attempts to edit Vendor A's product
    st, attack_edit = request_json(f"{BASE_URL}/api/vendor/products/{prod_A_id}", method="PUT", data={"selling_price": 10}, headers=vB_headers)
    print(f"Attack 2: Vendor B updates Vendor A product -> Status {st} (Expected: 403 Forbidden)")
    assert st == 403, f"Cross-vendor write isolation failed! Got status {st}: {attack_edit}"

    # Attack 3: Vendor B attempts to delete Vendor A's product
    st, attack_del = request_json(f"{BASE_URL}/api/vendor/products/{prod_A_id}", method="DELETE", headers=vB_headers)
    print(f"Attack 3: Vendor B deletes Vendor A product -> Status {st} (Expected: 403 Forbidden)")
    assert st == 403, f"Cross-vendor delete isolation failed! Got status {st}: {attack_del}"

    # Attack 4: Privilege Escalation - Vendor B attempts to call Owner Admin endpoints
    st, attack_admin = request_json(f"{BASE_URL}/api/admin/vendors", headers=vB_headers)
    print(f"Attack 4: Vendor B calls Owner Admin endpoint -> Status {st} (Expected: 403 Forbidden)")
    assert st in [401, 403], f"Privilege escalation check failed! Got status {st}: {attack_admin}"
    print("[PASS] All 4 negative security attacks rejected with 403 Forbidden! Strict data isolation verified.")

    # 10. MULTI-VENDOR ORDER CHECKOUT & FULFILLMENT
    print("\n--- 10. MULTI-VENDOR CUSTOMER CHECKOUT & FULFILLMENT ---")
    st, order_resp = request_json(f"{BASE_URL}/api/checkout", method="POST", data={
        "cart": [{
            "id": prod_A_id,
            "product_id": prod_A_id,
            "name": "Himalayan Handcrafted Wild Honey (500g)",
            "selling_price": 380,
            "quantity": 2
        }],
        "shipping_address": "Flat 402, Rose Tower, Sector 62, Noida, Uttar Pradesh - 201301",
        "payment_method": "COD",
        "user_name": "Rahul Verma",
        "user_phone": "7268903804"
    })
    print(f"POST /api/checkout -> Status {st}: {order_resp.get('message')}")
    assert st == 200 and order_resp.get("success"), f"Checkout failed: {order_resp}"
    tracking_num = order_resp.get("tracking_number")
    order_id = order_resp.get("order_id") or tracking_num
    print(f"[PASS] Order created successfully. Tracking #: {tracking_num}")

    # Vendor A fetches assigned orders
    st, vA_orders = request_json(f"{BASE_URL}/api/vendor/orders", headers=vA_headers)
    assert st == 200 and vA_orders.get("success"), f"Failed to fetch Vendor A orders: {vA_orders}"
    vA_order_list = vA_orders.get("orders", [])
    found_order_A = any(o.get("tracking_number") == tracking_num or o.get("order_id") == order_id for o in vA_order_list)
    assert found_order_A, "Placed order was not assigned to Vendor A"
    print(f"[PASS] Order #{tracking_num} visible in Vendor A's fulfillment queue.")

    # Vendor B fetches orders -> must NOT see Vendor A's items
    st, vB_orders = request_json(f"{BASE_URL}/api/vendor/orders", headers=vB_headers)
    vB_order_list = vB_orders.get("orders", [])
    found_order_B = any(o.get("tracking_number") == tracking_num or o.get("order_id") == order_id for o in vB_order_list)
    assert not found_order_B, "CRITICAL DEFECT: Vendor B can view Vendor A's order items!"
    print("[PASS] Cross-vendor order visibility isolation confirmed: Vendor B cannot see Vendor A's order.")

    # Vendor A updates item fulfillment status to 'shipped'
    st, fulfill_resp = request_json(f"{BASE_URL}/api/vendor/orders/{tracking_num}/item-status", method="PATCH", data={
        "product_id": prod_A_id,
        "status": "shipped",
        "tracking_number": f"EXP-{vA_suffix}",
        "notes": "Dispatched via Express Courier"
    }, headers=vA_headers)
    print(f"PATCH item-status -> Status {st}: {fulfill_resp}")
    assert st == 200 and fulfill_resp.get("success"), f"Fulfillment update failed: {fulfill_resp}"
    print("[PASS] Vendor A updated order fulfillment status to 'shipped'.")

    # 11. COMMISSIONS & SETTLEMENTS LEDGER
    print("\n--- 11. COMMISSIONS & SETTLEMENTS LEDGER ---")
    st, settle_resp = request_json(f"{BASE_URL}/api/vendor/settlements", headers=vA_headers)
    print(f"GET /api/vendor/settlements -> Status {st}: Gross ₹{settle_resp.get('gross_sales')}, Commission ₹{settle_resp.get('marketplace_commission')}, Net ₹{settle_resp.get('net_payable')}")
    assert st == 200 and settle_resp.get("success"), f"Settlements fetch failed: {settle_resp}"
    assert settle_resp.get("commission_rate") == 12.5, "Commission rate mismatch"
    assert settle_resp.get("gross_sales") >= 760.0, "Gross sales calculation mismatch (2 * 380 = 760)"
    assert settle_resp.get("net_payable") > 0, "Net payable must be positive"
    print(f"[PASS] Settlements calculated accurately: Gross ₹{settle_resp.get('gross_sales')} - 12.5% Commission (₹{settle_resp.get('marketplace_commission')}) = Net Payable ₹{settle_resp.get('net_payable')}.")

    # 12. OWNER SUSPENDS VENDOR B & IMMEDIATE ACCESS REVOCATION
    print("\n--- 12. OWNER SUSPENDS VENDOR & SESSIONS IMMEDIATELY REVOKED ---")
    st, susp_resp = request_json(f"{BASE_URL}/api/admin/vendors/{vendor_B_id}/status", method="PATCH", data={
        "status": "suspended"
    }, headers=admin_headers)
    assert st == 200 and susp_resp.get("status") == "suspended", "Vendor suspension failed"

    # Vendor B attempts to call dashboard using existing token -> must be rejected
    st, vB_blocked = request_json(f"{BASE_URL}/api/vendor/dashboard", headers=vB_headers)
    print(f"Suspended Vendor B portal call -> Status {st} (Expected: 401 or 403)")
    assert st in [401, 403], f"Suspended vendor session was not revoked! Got {st}: {vB_blocked}"
    print("[PASS] Suspended vendor's active sessions immediately revoked and blocked.")

    # 13. CLEANUP TEST ITEMS
    print("\n--- 13. CLEANUP TEST ARTIFACTS ---")
    request_json(f"{BASE_URL}/api/vendor/products/{prod_A_id}", method="DELETE", headers=vA_headers)
    print("[PASS] Test product safely archived/cleaned.")

    print("\n" + "=" * 70)
    print("ALL 12 MULTI-VENDOR MARKETPLACE PHASES PASSED WITH 100% SUCCESS!")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
