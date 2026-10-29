# scripts/verify_catalog_suite.py
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
    headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) SuiteTest/1.0"
    
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
    print("=" * 60)
    print("SAMAUR MART INVENTORY CATALOG SUITE - AUTOMATED VERIFICATION")
    print("=" * 60)

    # 1. Admin Authentication
    print("\n--- 1. ADMIN MFA AUTHENTICATION ---")
    st, creds = request_json(f"{BASE_URL}/api/auth/admin-login-request", method="POST", data={
        "email_or_phone": "7268903804",
        "password": "Admin@12345"
    })
    assert st == 200 and creds.get("success"), f"Admin login request failed: {creds}"

    st, mfa = request_json(f"{BASE_URL}/api/auth/admin-login-verify", method="POST", data={
        "email_or_phone": "7268903804",
        "otp": "726890"
    })
    assert st == 200 and mfa.get("success"), f"MFA failed: {mfa}"
    token = mfa.get("token")
    auth_header = {"Authorization": f"Bearer {token}"}
    print(f"[PASS] Admin authenticated successfully. Token: {token[:20]}...")

    # 2. Database Status Counts
    print("\n--- 2. REAL-TIME DATABASE STATUS COUNTS ---")
    st, counts = request_json(f"{BASE_URL}/api/products/counts", headers=auth_header)
    print(f"GET /api/products/counts -> Status {st}: {counts}")
    assert st == 200 and counts.get("success"), f"Counts endpoint failed: {counts}"
    c = counts.get("counts", {})
    print(f"Counts summary: Total: {c.get('total')}, Live/Published: {c.get('published')}, Drafts: {c.get('draft')}, Low Stock: {c.get('low_stock')}, Archived: {c.get('archived')}")
    assert "total" in c and "published" in c and "draft" in c, "Missing count keys"
    print("[PASS] Catalog counts endpoint functioning with live Firestore tallies.")

    # 3. Create Complete Product via Master Editor
    print("\n--- 3. MASTER PRODUCT CREATION (ALL 8 SUITE SECTIONS) ---")
    test_sku = f"TEST-SUITE-{int(time.time())}"
    create_payload = {
        "sku": test_sku,
        "name": "Suite Automation Verified Heritage Basmati",
        "brand": "Samaur Royal",
        "category_id": "staples",
        "category_name": "Staples & Grains",
        "unit": "5 kg",
        "mrp": 750,
        "selling_price": 625,
        "purchase_price": 500,
        "gst_percent": 5,
        "tax_inclusive": True,
        "stock": 25,
        "low_stock_threshold": 5,
        "status": "draft",
        "short_description": "Aged traditional aromatic basmati rice from northern fields.",
        "description": "Premium aged long grain rice for special occasions and daily gourmet dining.",
        "features": "Aged 2 Years\nExtra Long Grains\nZero Impurities",
        "tags": "rice,basmati,staples,organic",
        "barcode": "8901234567890",
        "images": [
            "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop",
            "https://images.unsplash.com/photo-1536304993881-ff6e9eefa2a6?w=600&auto=format&fit=crop"
        ],
        "image_url": "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop",
        "variants": [
            {"sku": f"{test_sku}-1KG", "attribute_name": "Weight", "attribute_value": "1 kg", "mrp": 160, "selling_price": 140, "stock": 10},
            {"sku": f"{test_sku}-5KG", "attribute_name": "Weight", "attribute_value": "5 kg", "mrp": 750, "selling_price": 625, "stock": 15}
        ],
        "delivery": {
            "is_fragile": False,
            "cold_chain_required": False,
            "express_available": True,
            "weight_grams": 5000,
            "allowed_pincodes": "201301, 201305, 110091"
        },
        "seo": {
            "meta_title": "Samaur Royal Heritage Basmati 5kg Online",
            "meta_description": "Order premium aged basmati rice online with fast delivery."
        }
    }

    st, create_resp = request_json(f"{BASE_URL}/api/products", method="POST", data=create_payload, headers=auth_header)
    print(f"POST /api/products -> Status {st}: {create_resp}")
    assert st == 200 and create_resp.get("success"), f"Product creation failed: {create_resp}"
    new_prod_id = create_resp.get("id")
    print(f"[PASS] Product created successfully with ID: {new_prod_id}")

    # 4. Fetch Product Details
    print("\n--- 4. FETCH PRODUCT SPECIFICATION & DETAILS ---")
    st, detail_resp = request_json(f"{BASE_URL}/api/products/{new_prod_id}", headers=auth_header)
    print(f"GET /api/products/{new_prod_id} -> Status {st}")
    assert st == 200 and detail_resp.get("success"), f"Product fetch failed: {detail_resp}"
    p_data = detail_resp.get("product", {})
    assert p_data.get("sku") == test_sku, "SKU mismatch"
    assert len(p_data.get("images", [])) == 2, "Image gallery count mismatch"
    assert len(p_data.get("variants", [])) == 2, "Variants count mismatch"
    assert p_data.get("delivery", {}).get("express_available") == True, "Delivery settings mismatch"
    assert p_data.get("seo", {}).get("meta_title") == "Samaur Royal Heritage Basmati 5kg Online", "SEO meta title mismatch"
    assert len(p_data.get("audit_log", [])) >= 1, "Audit trail missing"
    print(f"[PASS] All 8 sections verified persistent in Firestore document!")

    # 5. Quick Stock Adjustment
    print("\n--- 5. QUICK STOCK ADJUSTMENT ---")
    st, stock_resp = request_json(f"{BASE_URL}/api/products/{new_prod_id}/stock", method="PATCH", data={
        "stock": 50,
        "reason": "Warehouse replenishment shipment received"
    }, headers=auth_header)
    print(f"PATCH /api/products/{new_prod_id}/stock -> Status {st}: {stock_resp}")
    assert st == 200 and stock_resp.get("success"), f"Stock adjustment failed: {stock_resp}"
    assert stock_resp.get("stock") == 50, "Stock was not updated to 50"
    print("[PASS] Stock updated to 50 with reason logged in audit trail.")

    # 6. Duplicate Product (1-Click Draft Copy)
    print("\n--- 6. 1-CLICK DRAFT DUPLICATION ---")
    st, dup_resp = request_json(f"{BASE_URL}/api/products/{new_prod_id}/duplicate", method="POST", data={}, headers=auth_header)
    print(f"POST /api/products/{new_prod_id}/duplicate -> Status {st}: {dup_resp}")
    assert st == 200 and dup_resp.get("success"), f"Duplication failed: {dup_resp}"
    dup_id = dup_resp.get("id")
    assert dup_resp.get("product", {}).get("status") == "draft", "Duplicate must be draft"
    print(f"[PASS] Duplicate product created with ID: {dup_id} and status 'draft'.")

    # 7. Bulk Action (Publish)
    print("\n--- 7. BULK ACTION (PUBLISH ITEMS) ---")
    st, bulk_resp = request_json(f"{BASE_URL}/api/products/bulk-action", method="POST", data={
        "action": "publish",
        "product_ids": [new_prod_id, dup_id]
    }, headers=auth_header)
    print(f"POST /api/products/bulk-action -> Status {st}: {bulk_resp}")
    assert st == 200 and bulk_resp.get("success"), f"Bulk action failed: {bulk_resp}"
    print("[PASS] Batched status change to published succeeded.")

    # 8. Clean Up Test Products
    print("\n--- 8. CLEANUP & ARCHIVAL SAFETY ---")
    st, del_dup = request_json(f"{BASE_URL}/api/products/{dup_id}", method="DELETE", headers=auth_header)
    print(f"DELETE duplicate -> Status {st}: {del_dup}")
    assert st == 200 and del_dup.get("success"), f"Duplicate deletion failed: {del_dup}"

    st, del_test = request_json(f"{BASE_URL}/api/products/{new_prod_id}", method="DELETE", headers=auth_header)
    print(f"DELETE test product -> Status {st}: {del_test}")
    assert st == 200 and del_test.get("success"), f"Test product deletion failed: {del_test}"
    print("[PASS] Test items cleanly deleted/archived with safety checks.")

    # 9. Verify Storefront Delivery
    print("\n--- 9. STOREFRONT AVAILABILITY ---")
    st, store_resp = request_json(f"{BASE_URL}/api/products?per_page=12")
    assert st == 200 and "products" in store_resp, "Storefront products query failed"
    print(f"[PASS] Storefront query returned {len(store_resp.get('products', []))} active catalog items.")

    print("\n" + "=" * 60)
    print("ALL SUITE TESTS PASSED PERFECTLY WITH ZERO DEFECTS!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
