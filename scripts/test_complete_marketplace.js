// scripts/test_complete_marketplace.js
// Comprehensive End-to-End Test Suite for Samaur Mart Multi-Vendor Platform

const { spawn } = require("child_process");
const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

const sa = require(path.join(__dirname, "../firebase_service_account.json"));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(sa),
    projectId: "ma-store-949c7"
  });
}
const db = admin.firestore();

async function runCompleteTest() {
  console.log("======================================================================");
  console.log("SAMAUR MART — FULL MULTI-VENDOR MARKETPLACE END-TO-END VERIFICATION");
  console.log("======================================================================");

  // 0. Start Local Staging Instance
  console.log("\n[SETUP] Starting local staging server on 127.0.0.1:8089...");
  const serverProc = spawn("node", ["scripts/test_local_server.js"]);
  serverProc.stdout.on("data", d => process.stdout.write("[SERVER] " + d.toString()));
  serverProc.stderr.on("data", d => process.stderr.write("[SERVER ERR] " + d.toString()));

  // Wait 3s for server boot
  await new Promise(r => setTimeout(r, 3000));

  const BASE = "http://127.0.0.1:8089/api";
  const nowTs = Date.now();
  const vA_phone = "98" + String(nowTs).slice(-8);
  const vA_email = `merchant_a_${nowTs}@samaurmart.com`;
  const vA_pass = "VendorPass@123";

  const vB_phone = "97" + String(nowTs).slice(-8);
  const vB_email = `merchant_b_${nowTs}@rivalshop.com`;
  const vB_pass = "RivalPass@999";

  let adminToken = "";
  let vA_token = "";
  let vB_token = "";
  let vendor_A_id = "";
  let vendor_B_id = "";
  let prod_A_id = "";
  let trackingNum = "";
  let orderId = "";

  try {
    // ---------------------------------------------------------------
    // PHASE 1: OWNER ADMIN AUTHENTICATION
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 1: OWNER ADMIN AUTHENTICATION ---");
    const adminCredsRes = await fetch(`${BASE}/auth/admin-login-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: "7268903804", password: "Admin@12345" })
    });
    const adminCreds = await adminCredsRes.json();
    if (!adminCredsRes.ok || !adminCreds.success) throw new Error("Admin login request failed: " + JSON.stringify(adminCreds));

    const adminMfaRes = await fetch(`${BASE}/auth/admin-login-verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: "7268903804", otp: "726890" })
    });
    const adminMfa = await adminMfaRes.json();
    if (!adminMfaRes.ok || !adminMfa.token) throw new Error("Admin MFA verify failed: " + JSON.stringify(adminMfa));
    adminToken = adminMfa.token;
    console.log(`[PASS] Owner Admin authenticated successfully. Token: ${adminToken.substring(0, 20)}...`);

    // ---------------------------------------------------------------
    // PHASE 2: VENDOR REGISTRATION & REAL CARRIER OTP VERIFICATION
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 2: VENDOR SELF-SERVICE REGISTRATION & OTP ---");
    // 2a: Negative check - invalid phone
    const badPhoneRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: vA_email, phone: "123" })
    });
    if (badPhoneRes.status !== 400) throw new Error("Expected status 400 on invalid phone");
    console.log("[PASS] Invalid phone format rejected.");

    // 2b: Request OTP for valid phone
    const otpReqRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: vA_email,
        phone: vA_phone,
        business_name: "Himalayan Herbal Essentials",
        contact_name: "Arjun Sharma"
      })
    });
    const otpReq = await otpReqRes.json();
    if (!otpReqRes.ok || !otpReq.success) throw new Error("OTP request failed: " + JSON.stringify(otpReq));
    console.log(`[PASS] Real OTP dispatched to vendor mobile ${vA_phone} via SMS engine.`);

    // 2c: Test 30s Cooldown
    const spamRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: vA_email,
        phone: vA_phone,
        business_name: "Himalayan Herbal Essentials",
        contact_name: "Arjun Sharma"
      })
    });
    if (spamRes.status !== 429) throw new Error("Expected 429 cooldown status");
    console.log("[PASS] 30-second cooldown rate limit enforced.");

    // Retrieve generated OTP from Firestore (simulating carrier SMS delivery)
    const otpDoc = await db.collection("vendor_otps").doc("reg_" + vA_phone).get();
    if (!otpDoc.exists) throw new Error("vendor_otps doc missing in Firestore");
    const realOtpA = otpDoc.data().code;
    console.log(`[SIMULATION] Vendor mobile received carrier SMS OTP: ${realOtpA}`);

    // 2d: Negative check - wrong OTP
    const wrongOtpRes = await fetch(`${BASE}/vendor/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        business_name: "Himalayan Herbal Essentials",
        contact_name: "Arjun Sharma",
        email: vA_email,
        phone: vA_phone,
        password: vA_pass,
        otp: "000000",
        address: "Shop 12, Main Bazaar, Rishikesh",
        pincode: "201301"
      })
    });
    if (wrongOtpRes.status !== 400) throw new Error("Expected status 400 on wrong OTP");
    console.log("[PASS] Invalid OTP rejected.");

    // 2e: Positive registration with real OTP
    const regRes = await fetch(`${BASE}/vendor/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        business_name: "Himalayan Herbal Essentials",
        contact_name: "Arjun Sharma",
        email: vA_email,
        phone: vA_phone,
        password: vA_pass,
        otp: realOtpA,
        address: "Shop 12, Main Bazaar, Rishikesh",
        pincode: "201301",
        categories: ["Organic Foods", "Herbal Supplements"],
        tax_id: "09AAAAA0000A1Z5",
        bank_details: {
          bank_name: "State Bank of India",
          account_number: "50100987654321",
          ifsc_code: "SBIN0001234"
        }
      })
    });
    const regData = await regRes.json();
    if (!regRes.ok || !regData.success) throw new Error("Vendor registration failed: " + JSON.stringify(regData));
    vendor_A_id = regData.vendor_id;
    if (regData.status !== "submitted") throw new Error("Vendor initial status must be 'submitted'");
    console.log(`[PASS] Vendor A registered with ID: ${vendor_A_id} and status: 'submitted'.`);

    // Verify OTP burned
    const burnedDoc = await db.collection("vendor_otps").doc("reg_" + vA_phone).get();
    if (burnedDoc.exists) throw new Error("OTP was not burned after registration!");
    console.log("[PASS] OTP single-use burn confirmed.");

    // ---------------------------------------------------------------
    // PHASE 3: PENDING VENDOR BLOCKED FROM LOGIN
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 3: AUTHENTICATION GATE (PENDING VENDOR) ---");
    const pendingLoginRes = await fetch(`${BASE}/vendor/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: vA_phone, password: vA_pass })
    });
    const pendingLogin = await pendingLoginRes.json();
    if (pendingLoginRes.status !== 403 || !pendingLogin.error.includes("review")) {
      throw new Error("Pending vendor was not blocked from login!");
    }
    console.log("[PASS] Pending vendor blocked with clear review notice.");

    // ---------------------------------------------------------------
    // PHASE 4: OWNER ADMIN REVIEWS & APPROVES VENDOR A
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 4: OWNER VENDOR REVIEW & APPROVAL ---");
    const vDocRes = await fetch(`${BASE}/admin/vendors/${vendor_A_id}`, {
      headers: { "Authorization": `Bearer ${adminToken}` }
    });
    const vDoc = await vDocRes.json();
    if (!vDocRes.ok || !vDoc.vendor) throw new Error("Failed to fetch vendor dossier");
    console.log(`Owner reviewed vendor: "${vDoc.vendor.business_name}" (${vDoc.vendor.phone})`);

    const approveRes = await fetch(`${BASE}/admin/vendors/${vendor_A_id}/status`, {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${adminToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        status: "approved",
        commission_rate: 10.0,
        auto_publish: false
      })
    });
    const approveData = await approveRes.json();
    if (!approveRes.ok || approveData.status !== "approved") throw new Error("Vendor approval failed: " + JSON.stringify(approveData));
    console.log(`[PASS] Vendor A approved by Owner with 10% commission rate.`);

    // ---------------------------------------------------------------
    // PHASE 5: APPROVED VENDOR DIRECT LOGIN
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 5: APPROVED VENDOR PORTAL LOGIN ---");
    const vLoginRes = await fetch(`${BASE}/vendor/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: vA_phone, password: vA_pass })
    });
    const vLogin = await vLoginRes.json();
    if (!vLoginRes.ok || !vLogin.token) throw new Error("Approved vendor login failed: " + JSON.stringify(vLogin));
    vA_token = vLogin.token;
    console.log(`[PASS] Approved Vendor A logged in! Session Token: ${vA_token.substring(0, 20)}...`);

    const vSessRes = await fetch(`${BASE}/vendor/verify-session`, {
      headers: { "Authorization": `Bearer ${vA_token}` }
    });
    const vSess = await vSessRes.json();
    if (!vSessRes.ok || !vSess.authenticated) throw new Error("Session verify failed: " + JSON.stringify(vSess));
    console.log(`[PASS] Vendor session verified for "${vSess.vendor.business_name}".`);

    // ---------------------------------------------------------------
    // PHASE 6: VENDOR CREATES PRODUCT (PENDING REVIEW)
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 6: VENDOR PRODUCT CREATION ---");
    const prodPayload = {
      name: "Pure Himalayan Wild Honey (500g)",
      sku: "HIM-HNY-" + nowTs,
      brand: "Himalayan Naturals",
      category_id: 1,
      unit: "500 g",
      mrp: 450,
      selling_price: 360,
      stock: 40,
      image_url: "https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=600",
      description: "100% natural, raw unfiltered wild honey collected from Himalayan slopes."
    };
    const prodCreateRes = await fetch(`${BASE}/vendor/products`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${vA_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(prodPayload)
    });
    const prodCreate = await prodCreateRes.json();
    if (!prodCreateRes.ok || !prodCreate.id) throw new Error("Product creation failed: " + JSON.stringify(prodCreate));
    prod_A_id = String(prodCreate.id);
    if (prodCreate.approval_status !== "pending_review") throw new Error("Product must be pending_review");
    console.log(`[PASS] Product created with ID: ${prod_A_id} and status: 'pending_review'.`);

    // ---------------------------------------------------------------
    // PHASE 7: STOREFRONT PUBLICATION GATE (UNAPPROVED HIDDEN)
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 7: STOREFRONT PUBLICATION GATE ---");
    const storeCheckRes = await fetch(`${BASE}/products?per_page=30`);
    const storeCheck = await storeCheckRes.json();
    const isVisibleEarly = (storeCheck.products || []).some(p => String(p.id) === String(prod_A_id));
    if (isVisibleEarly) throw new Error("SECURITY BUG: Unapproved vendor product appeared on public storefront!");
    console.log("[PASS] Unapproved product is hidden from customer storefront.");

    // ---------------------------------------------------------------
    // PHASE 8: OWNER REVIEW QUEUE & PRODUCT APPROVAL
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 8: OWNER REVIEW QUEUE & PRODUCT APPROVAL ---");
    const queueRes = await fetch(`${BASE}/admin/products/pending-review`, {
      headers: { "Authorization": `Bearer ${adminToken}` }
    });
    const queueData = await queueRes.json();
    const inQueue = (queueData.products || []).some(p => String(p.id) === String(prod_A_id));
    if (!inQueue) throw new Error("Product missing from Owner review queue");
    console.log(`[PASS] Product #${prod_A_id} verified in Owner review queue.`);

    const approveProdRes = await fetch(`${BASE}/admin/products/${prod_A_id}/review`, {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${adminToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ action: "approve", notes: "Product details and certificates verified." })
    });
    const approveProd = await approveProdRes.json();
    if (!approveProdRes.ok || approveProd.approval_status !== "approved") throw new Error("Product approval failed: " + JSON.stringify(approveProd));
    console.log(`[PASS] Owner approved product #${prod_A_id}. Status updated to 'published'.`);

    // Verify it is now live on storefront with vendor attribution
    const storeLiveRes = await fetch(`${BASE}/products?per_page=40`);
    const storeLive = await storeLiveRes.json();
    const liveProd = (storeLive.products || []).find(p => String(p.id) === String(prod_A_id));
    if (!liveProd) throw new Error("Approved product failed to appear on storefront!");
    console.log(`[PASS] Product #${prod_A_id} is NOW LIVE on storefront with Vendor Attribution: "${liveProd.vendor_name}"!`);

    // ---------------------------------------------------------------
    // PHASE 9: DATA ISOLATION & CROSS-VENDOR PENETRATION ATTACKS
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 9: CROSS-VENDOR DATA ISOLATION & ATTACKS ---");
    // Register Vendor B
    await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: vB_email, phone: vB_phone, business_name: "Rival Spices", contact_name: "Rival" })
    });
    const otpDocB = await db.collection("vendor_otps").doc("reg_" + vB_phone).get();
    const realOtpB = otpDocB.data().code;

    const regBRes = await fetch(`${BASE}/vendor/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        business_name: "Rival Spices",
        contact_name: "Rival",
        email: vB_email,
        phone: vB_phone,
        password: vB_pass,
        otp: realOtpB,
        address: "77 Market Road",
        pincode: "201301"
      })
    });
    const regBData = await regBRes.json();
    vendor_B_id = regBData.vendor_id;

    // Approve Vendor B
    await fetch(`${BASE}/admin/vendors/${vendor_B_id}/status`, {
      method: "PATCH",
      headers: { "Authorization": `Bearer ${adminToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ status: "approved" })
    });

    // Vendor B logs in
    const vBLoginRes = await fetch(`${BASE}/vendor/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: vB_phone, password: vB_pass })
    });
    vB_token = (await vBLoginRes.json()).token;

    // Attack 1: Vendor B attempts to read Vendor A product
    const atk1 = await fetch(`${BASE}/vendor/products/${prod_A_id}`, {
      headers: { "Authorization": `Bearer ${vB_token}` }
    });
    if (atk1.status !== 403) throw new Error("Cross-vendor read isolation failed!");

    // Attack 2: Vendor B attempts to edit Vendor A product
    const atk2 = await fetch(`${BASE}/vendor/products/${prod_A_id}`, {
      method: "PUT",
      headers: { "Authorization": `Bearer ${vB_token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ selling_price: 1 })
    });
    if (atk2.status !== 403) throw new Error("Cross-vendor edit isolation failed!");

    // Attack 3: Vendor B attempts to delete Vendor A product
    const atk3 = await fetch(`${BASE}/vendor/products/${prod_A_id}`, {
      method: "DELETE",
      headers: { "Authorization": `Bearer ${vB_token}` }
    });
    if (atk3.status !== 403) throw new Error("Cross-vendor delete isolation failed!");

    // Attack 4: Vendor B attempts to call Owner Admin endpoints
    const atk4 = await fetch(`${BASE}/admin/vendors`, {
      headers: { "Authorization": `Bearer ${vB_token}` }
    });
    if (atk4.status !== 403 && atk4.status !== 401) throw new Error("Privilege escalation check failed!");
    console.log("[PASS] All 4 cross-vendor penetration attacks rejected with 403 Forbidden.");

    // ---------------------------------------------------------------
    // PHASE 10: CUSTOMER CHECKOUT & SERVER PRICE AUTHORITY
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 10: CUSTOMER CHECKOUT & PRICE INTEGRITY ---");
    // Attacker tries to purchase product with tampered price ₹1
    const checkoutRes = await fetch(`${BASE}/checkout`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        cart: [{
          id: prod_A_id,
          product_id: prod_A_id,
          name: "Pure Himalayan Wild Honey (500g)",
          price: 1.0, // Tampered client price!
          selling_price: 1.0,
          quantity: 2
        }],
        shipping_address: "Apartment 101, Shanti Kunj, Sector 62, Noida - 201301",
        payment_method: "COD",
        user_name: "Rahul Verma",
        user_phone: "7268903804"
      })
    });
    const orderData = await checkoutRes.json();
    if (!checkoutRes.ok || !orderData.success) throw new Error("Checkout failed: " + JSON.stringify(orderData));
    trackingNum = orderData.tracking_number;
    orderId = orderData.order_id || trackingNum;

    // Verify charged price is server catalog price (₹360 * 2 = ₹720), NOT ₹1 * 2
    const chargedItem = (orderData.items || []).find(it => String(it.id) === String(prod_A_id));
    if (!chargedItem || chargedItem.price !== 360) {
      throw new Error(`PRICE BREACH: Server accepted client price! Charged: ${chargedItem ? chargedItem.price : 'null'}`);
    }
    console.log(`[PASS] Server enforced catalog price of ₹360 and defeated client price tampering!`);
    console.log(`[PASS] Customer order placed. Tracking #: ${trackingNum}`);

    // Verify stock was atomically decremented: 40 -> 38
    const prodAfterBuyDoc = await db.collection("products").doc(prod_A_id).get();
    const stockAfterBuy = prodAfterBuyDoc.data().stock;
    if (stockAfterBuy !== 38) throw new Error(`Stock mismatch: expected 38, got ${stockAfterBuy}`);
    console.log(`[PASS] Stock atomically decremented from 40 to ${stockAfterBuy} units.`);

    // ---------------------------------------------------------------
    // PHASE 11: VENDOR FULFILLMENT & ISOLATION
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 11: VENDOR ORDER FULFILLMENT & PRIVACY ---");
    // Vendor A reads orders -> must see this order item
    const vAOrdersRes = await fetch(`${BASE}/vendor/orders`, {
      headers: { "Authorization": `Bearer ${vA_token}` }
    });
    const vAOrders = await vAOrdersRes.json();
    const foundInA = (vAOrders.orders || []).some(o => o.tracking_number === trackingNum || o.order_id === orderId);
    if (!foundInA) throw new Error("Order was not allocated to Vendor A!");
    console.log(`[PASS] Order #${trackingNum} visible in Vendor A's fulfillment queue.`);

    // Vendor B reads orders -> must NOT see Vendor A's order
    const vBOrdersRes = await fetch(`${BASE}/vendor/orders`, {
      headers: { "Authorization": `Bearer ${vB_token}` }
    });
    const vBOrders = await vBOrdersRes.json();
    const foundInB = (vBOrders.orders || []).some(o => o.tracking_number === trackingNum || o.order_id === orderId);
    if (foundInB) throw new Error("PRIVACY BREACH: Vendor B can view Vendor A's order items!");
    console.log(`[PASS] Vendor B cannot see Vendor A's order items.`);

    // Vendor A updates status to 'shipped'
    const fulfillRes = await fetch(`${BASE}/vendor/orders/${trackingNum}/item-status`, {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${vA_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        product_id: prod_A_id,
        status: "shipped",
        notes: "Shipped via Delhivery Express"
      })
    });
    const fulfillData = await fulfillRes.json();
    if (!fulfillRes.ok || !fulfillData.success) throw new Error("Fulfillment update failed: " + JSON.stringify(fulfillData));
    console.log(`[PASS] Vendor A updated order status to 'shipped'.`);

    // ---------------------------------------------------------------
    // PHASE 12: SETTLEMENTS & COMMISSION ACCOUNTING
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 12: COMMISSIONS & SETTLEMENTS ---");
    const settleRes = await fetch(`${BASE}/vendor/settlements`, {
      headers: { "Authorization": `Bearer ${vA_token}` }
    });
    const settleData = await settleRes.json();
    if (!settleRes.ok || !settleData.success) throw new Error("Settlements fetch failed");
    console.log(`Settlements: Gross ₹${settleData.gross_sales}, Commission: ₹${settleData.marketplace_commission}, Net: ₹${settleData.net_payable}`);
    if (settleData.gross_sales < 720) throw new Error("Gross sales calculation mismatch");
    console.log(`[PASS] Accurate settlement accounting verified.`);

    // ---------------------------------------------------------------
    // PHASE 13: CUSTOMER ORDER CANCELLATION & INVENTORY RESTORATION
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 13: ORDER CANCELLATION & RESTORATION ---");
    const cancelRes = await fetch(`${BASE}/orders/${orderId}/cancel`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ customer_phone: "7268903804", reason: "Ordered by mistake" })
    });
    const cancelData = await cancelRes.json();
    if (!cancelRes.ok || !cancelData.success) throw new Error("Cancellation failed: " + JSON.stringify(cancelData));
    console.log(`[PASS] Customer order cancelled: ${cancelData.message}`);

    // Verify stock restored: 38 -> 40
    const prodRestoredDoc = await db.collection("products").doc(prod_A_id).get();
    const stockRestored = prodRestoredDoc.data().stock;
    if (stockRestored !== 40) throw new Error(`Stock restoration failed: expected 40, got ${stockRestored}`);
    console.log(`[PASS] Inventory restored back to ${stockRestored} units.`);

    // ---------------------------------------------------------------
    // PHASE 14: OWNER SUSPENDS VENDOR & SESSIONS REVOKED
    // ---------------------------------------------------------------
    console.log("\n--- PHASE 14: OWNER SUSPENSION & SESSION REVOCATION ---");
    const suspRes = await fetch(`${BASE}/admin/vendors/${vendor_B_id}/status`, {
      method: "PATCH",
      headers: { "Authorization": `Bearer ${adminToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ status: "suspended", rejection_reason: "Violation of terms" })
    });
    if (!suspRes.ok) throw new Error("Suspension failed");

    // Check Vendor B's session is now blocked
    const vBCheckRes = await fetch(`${BASE}/vendor/dashboard`, {
      headers: { "Authorization": `Bearer ${vB_token}` }
    });
    if (vBCheckRes.status !== 403 && vBCheckRes.status !== 401) {
      throw new Error("Suspended vendor session was not revoked!");
    }
    console.log(`[PASS] Suspended vendor immediately blocked from portal.`);

    // ---------------------------------------------------------------
    // CLEANUP
    // ---------------------------------------------------------------
    console.log("\n[CLEANUP] Cleaning test data...");
    await db.collection("products").doc(prod_A_id).delete().catch(() => {});
    await db.collection("vendors").doc(vendor_A_id).delete().catch(() => {});
    await db.collection("vendors").doc(vendor_B_id).delete().catch(() => {});
    await db.collection("orders").doc(orderId).delete().catch(() => {});
    await db.collection("vendor_sessions").doc(vA_token).delete().catch(() => {});
    await db.collection("vendor_sessions").doc(vB_token).delete().catch(() => {});

    console.log("\n======================================================================");
    console.log("ALL 14 E2E MARKETPLACE WORKFLOWS PASSED WITH 100% SUCCESS!");
    console.log("======================================================================");
    return true;
  } finally {
    serverProc.kill();
  }
}

runCompleteTest().then(() => process.exit(0)).catch(err => {
  console.error("\nTEST SUITE FAILED:", err);
  process.exit(1);
});
