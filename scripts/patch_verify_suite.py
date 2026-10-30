# scripts/patch_verify_suite.py
with open("scripts/verify_deep_production_suite.py", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Add firebase_admin imports at top if not present
if "firebase_admin" not in code:
    code = """import firebase_admin
from firebase_admin import credentials, firestore
cred_path = "firebase_service_account.json"
if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(cred_path), {"projectId": "ma-store-949c7"})
f_db = firestore.client()
""" + code

# 2. Fix stock lookups to handle { success: true, product: { ... } }
code = code.replace(
    'stock_before = int(prod_snap1["stock"])',
    'stock_before = int((prod_snap1.get("product") or prod_snap1)["stock"])'
)
code = code.replace(
    'stock_after = int(prod_snap2["stock"])',
    'stock_after = int((prod_snap2.get("product") or prod_snap2)["stock"])'
)
code = code.replace(
    'stock_restored = int(prod_snap3["stock"])',
    'stock_restored = int((prod_snap3.get("product") or prod_snap3)["stock"])'
)

# 3. In section 7, use real Firestore OTP instead of hardcoded 726890
old_sec_7 = '''    # Register vendor
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
    assert st_new == 200 and new_login.get("success"), f"New password login failed: {new_login}"'''

new_sec_7 = '''    # Register vendor with real carrier OTP from Firestore
    st_req, _ = request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={"email": v_rec_email, "phone": v_rec_phone, "business_name": "Recovery Test Merchant", "contact_name": "Test Contact"})
    assert st_req == 200, "Register OTP request failed"
    real_reg_doc = f_db.collection("vendor_otps").document(f"reg_{v_rec_phone}").get()
    real_reg_otp = real_reg_doc.to_dict()["code"]
    st, reg_rec = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data={
        "business_name": "Recovery Test Merchant",
        "contact_name": "Test Contact",
        "email": v_rec_email,
        "phone": v_rec_phone,
        "password": v_orig_pass,
        "otp": real_reg_otp,
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

    # Step B: Reset Password with real OTP
    real_reset_doc = f_db.collection("vendor_otps").document(f"reset_{v_rec_phone}").get()
    real_reset_otp = real_reset_doc.to_dict()["code"]
    st, reset_exec = request_json(f"{BASE_URL}/api/vendor/reset-password", method="POST", data={
        "email_or_phone": v_rec_email,
        "otp": real_reset_otp,
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

    # Step D: Verify new password succeeds with direct login
    st_new, new_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={"email_or_phone": v_rec_email, "password": v_new_pass})
    assert st_new == 200 and new_login.get("success"), f"New password login failed: {new_login}"'''

if old_sec_7 in code:
    code = code.replace(old_sec_7, new_sec_7)
    print("Replaced section 7 with real OTP verification!")
else:
    print("Notice: old_sec_7 pattern mismatch, checking...")

with open("scripts/verify_deep_production_suite.py", "w", encoding="utf-8") as f:
    f.write(code)

print("Updated scripts/verify_deep_production_suite.py!")
