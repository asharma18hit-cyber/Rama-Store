# scripts/patch_multivendor_test.py
import re

with open("scripts/verify_multivendor_suite.py", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Add firebase_admin imports
if "firebase_admin" not in code:
    code = """import firebase_admin
from firebase_admin import credentials, firestore
cred_path = "firebase_service_account.json"
if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(cred_path), {"projectId": "ma-store-949c7"})
f_db = firestore.client()
""" + code

# 2. Add TEST_BASE_URL env support
code = code.replace(
    'BASE_URL = "https://ma-store-949c7.web.app"',
    'import os\nBASE_URL = os.environ.get("TEST_BASE_URL", "https://ma-store-949c7.web.app")'
)

# 3. Replace Step 2a & 2d in Vendor A registration
old_reg_A = '''    # Step 2a: Request MFA OTP for Registration
    st, otp_req = request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={
        "email": vA_email,
        "phone": vA_phone,
        "business_name": reg_payload_A["business_name"],
        "contact_name": reg_payload_A["contact_name"]
    })
    print(f"POST /api/vendor/register-otp-request -> Status {st}: {otp_req.get('message')}")
    assert st == 200 and otp_req.get("mfa_required"), f"MFA OTP request failed: {otp_req}"
    print(f"[PASS] Real 6-digit MFA verification code dispatched to vendor mobile {vA_phone}.")

    # Step 2b: Negative Test 1 - Registration attempt without MFA OTP
    st_no_otp, resp_no_otp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=reg_payload_A)
    print(f"Negative Test 1 (Missing OTP) -> Status {st_no_otp} (Expected: 400 Bad Request)")
    assert st_no_otp == 400 and resp_no_otp.get("mfa_required"), "Registration without MFA OTP must be rejected!"

    # Step 2c: Negative Test 2 - Registration attempt with invalid MFA OTP
    invalid_reg_payload = dict(reg_payload_A, otp="000000")
    st_bad_otp, resp_bad_otp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=invalid_reg_payload)
    print(f"Negative Test 2 (Invalid OTP 000000) -> Status {st_bad_otp} (Expected: 400 Bad Request)")
    assert st_bad_otp == 400, "Registration with incorrect MFA OTP must be rejected!"
    print("[PASS] Negative security gates verified: unverified registrations strictly blocked.")

    # Step 2d: Positive Test - Complete registration with verified MFA OTP
    valid_reg_payload = dict(reg_payload_A, otp="726890")
    st, reg_resp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=valid_reg_payload)'''

new_reg_A = '''    # Step 2a: Request OTP for Registration
    st, otp_req = request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={
        "email": vA_email,
        "phone": vA_phone,
        "business_name": reg_payload_A["business_name"],
        "contact_name": reg_payload_A["contact_name"]
    })
    print(f"POST /api/vendor/register-otp-request -> Status {st}: {otp_req.get('message')}")
    assert st == 200 and otp_req.get("success"), f"OTP request failed: {otp_req}"
    print(f"[PASS] Real 6-digit verification code dispatched to vendor mobile {vA_phone}.")

    # Fetch real OTP from Firestore (simulating phone receiving carrier SMS)
    real_otp_doc = f_db.collection("vendor_otps").document(f"reg_{vA_phone}").get()
    real_otp_code = real_otp_doc.to_dict()["code"]

    # Step 2b: Negative Test 1 - Registration attempt without OTP
    st_no_otp, resp_no_otp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=reg_payload_A)
    print(f"Negative Test 1 (Missing OTP) -> Status {st_no_otp} (Expected: 400 Bad Request)")
    assert st_no_otp == 400, "Registration without OTP must be rejected!"

    # Step 2c: Negative Test 2 - Registration attempt with invalid OTP
    invalid_reg_payload = dict(reg_payload_A, otp="000000")
    st_bad_otp, resp_bad_otp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=invalid_reg_payload)
    print(f"Negative Test 2 (Invalid OTP 000000) -> Status {st_bad_otp} (Expected: 400 Bad Request)")
    assert st_bad_otp == 400, "Registration with incorrect OTP must be rejected!"
    print("[PASS] Negative security gates verified: unverified registrations strictly blocked.")

    # Step 2d: Positive Test - Complete registration with verified OTP
    valid_reg_payload = dict(reg_payload_A, otp=real_otp_code)
    st, reg_resp = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data=valid_reg_payload)'''

code = code.replace(old_reg_A, new_reg_A)

# 4. Vendor A login: direct login
old_login_A = '''    # 5. APPROVED VENDOR AUTHENTICATION WITH 2-STEP MFA
    print("\\n--- 5. APPROVED VENDOR LOGIN WITH 2-FACTOR AUTHENTICATION (MFA) ---")
    # Step 5a: Vendor Login Request (Credentials verification + MFA dispatch)
    st_req, req_data = request_json(f"{BASE_URL}/api/vendor/login-request", method="POST", data={
        "email_or_phone": vA_email,
        "password": vA_pass
    })
    print(f"POST /api/vendor/login-request -> Status {st_req}: {req_data.get('message')}")
    assert st_req == 200 and req_data.get("mfaRequired"), f"Vendor login request failed: {req_data}"

    # Step 5b: Negative Test - Login with wrong MFA OTP
    st_bad_l, bad_l_resp = request_json(f"{BASE_URL}/api/vendor/login-verify", method="POST", data={
        "email_or_phone": vA_email,
        "otp": "000000"
    })
    print(f"Negative Test (Invalid Login OTP 000000) -> Status {st_bad_l} (Expected: 400 Bad Request)")
    assert st_bad_l in [400, 401], "Login with invalid MFA OTP must fail"

    # Step 5c: Positive Test - Login Verify with valid MFA code
    st, vA_login = request_json(f"{BASE_URL}/api/vendor/login-verify", method="POST", data={
        "email_or_phone": vA_email,
        "otp": "726890"
    })
    print(f"POST /api/vendor/login-verify -> Status {st}: {vA_login.get('message')}")
    assert st == 200 and vA_login.get("success"), f"Vendor MFA login failed: {vA_login}"
    vA_token = vA_login.get("token")
    vA_headers = {"Authorization": f"Bearer {vA_token}"}
    assert vA_token.startswith("vdr_sess_"), "Vendor token format invalid"'''

new_login_A = '''    # 5. APPROVED VENDOR AUTHENTICATION
    print("\\n--- 5. APPROVED VENDOR DIRECT LOGIN ---")
    st, vA_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={
        "email_or_phone": vA_email,
        "password": vA_pass
    })
    print(f"POST /api/vendor/login -> Status {st}: {vA_login.get('message')}")
    assert st == 200 and vA_login.get("success"), f"Vendor login failed: {vA_login}"
    vA_token = vA_login.get("token")
    vA_headers = {"Authorization": f"Bearer {vA_token}"}
    assert vA_token.startswith("vdr_sess_"), "Vendor token format invalid"'''

code = code.replace(old_login_A, new_login_A)

# 5. Vendor B registration & login
old_b = '''    # Request MFA for Vendor B
    request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={
        "email": vB_email,
        "phone": vB_phone,
        "business_name": f"Competitor Spices ({vB_suffix})",
        "contact_name": "Rival Seller"
    })

    _, reg_B = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data={
        "business_name": f"Competitor Spices ({vB_suffix})",
        "contact_name": "Rival Seller",
        "email": vB_email,
        "phone": vB_phone,
        "password": vB_pass,
        "otp": "726890",
        "address": "45 Baker Street",
        "pincode": "201301"
    })
    vendor_B_id = reg_B.get("vendor_id")
    # Owner approves Vendor B
    request_json(f"{BASE_URL}/api/admin/vendors/{vendor_B_id}/status", method="PATCH", data={"status": "approved"}, headers=admin_headers)
    # Vendor B logs in with MFA
    request_json(f"{BASE_URL}/api/vendor/login-request", method="POST", data={"email_or_phone": vB_email, "password": vB_pass})
    _, vB_login = request_json(f"{BASE_URL}/api/vendor/login-verify", method="POST", data={"email_or_phone": vB_email, "otp": "726890"})'''

new_b = '''    # Request OTP for Vendor B
    request_json(f"{BASE_URL}/api/vendor/register-otp-request", method="POST", data={
        "email": vB_email,
        "phone": vB_phone,
        "business_name": f"Competitor Spices ({vB_suffix})",
        "contact_name": "Rival Seller"
    })
    real_b_doc = f_db.collection("vendor_otps").document(f"reg_{vB_phone}").get()
    real_b_otp = real_b_doc.to_dict()["code"]

    _, reg_B = request_json(f"{BASE_URL}/api/vendor/register", method="POST", data={
        "business_name": f"Competitor Spices ({vB_suffix})",
        "contact_name": "Rival Seller",
        "email": vB_email,
        "phone": vB_phone,
        "password": vB_pass,
        "otp": real_b_otp,
        "address": "45 Baker Street",
        "pincode": "201301"
    })
    vendor_B_id = reg_B.get("vendor_id")
    # Owner approves Vendor B
    request_json(f"{BASE_URL}/api/admin/vendors/{vendor_B_id}/status", method="PATCH", data={"status": "approved"}, headers=admin_headers)
    # Vendor B logs in
    _, vB_login = request_json(f"{BASE_URL}/api/vendor/login", method="POST", data={"email_or_phone": vB_email, "password": vB_pass})'''

code = code.replace(old_b, new_b)

with open("scripts/verify_multivendor_suite.py", "w", encoding="utf-8") as f:
    f.write(code)

print("scripts/verify_multivendor_suite.py patched successfully!")
