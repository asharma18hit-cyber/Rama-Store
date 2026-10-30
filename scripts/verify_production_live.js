// scripts/verify_production_live.js
// Live Non-Destructive Production Smoke Test Suite for Samaur Mart
// Target: https://ma-store-949c7.web.app

async function runLiveSmokeTests() {
  const BASE_URL = "https://ma-store-949c7.web.app";
  console.log("======================================================================");
  console.log("SAMAUR MART — LIVE PRODUCTION SMOKE TESTING");
  console.log("Target:", BASE_URL);
  console.log("Timestamp:", new Date().toISOString());
  console.log("======================================================================");

  let passed = 0;
  let failed = 0;

  async function checkUrl(name, url, expectedStatus = 200) {
    try {
      const res = await fetch(url, { headers: { "User-Agent": "ProductionSmokeTest/1.0" } });
      if (res.status === expectedStatus) {
        console.log(`[PASS] ${name}: Status ${res.status} OK`);
        passed++;
        return res;
      } else {
        console.error(`[FAIL] ${name}: Expected ${expectedStatus}, got ${res.status}`);
        failed++;
        return res;
      }
    } catch (err) {
      console.error(`[FAIL] ${name}: Network error:`, err.message);
      failed++;
      return null;
    }
  }

  // 1. Static Web Hosting Pages
  console.log("\n--- 1. STATIC STOREFRONT & DASHBOARD ROUTES ---");
  await checkUrl("Customer Storefront", `${BASE_URL}/store`);
  await checkUrl("Owner Admin Console", `${BASE_URL}/admin`);
  await checkUrl("Owner Admin Login", `${BASE_URL}/admin/login`);
  await checkUrl("Vendor Registration Portal", `${BASE_URL}/vendor/register`);
  await checkUrl("Vendor Login Portal", `${BASE_URL}/vendor/login`);
  await checkUrl("Vendor Dashboard Portal", `${BASE_URL}/vendor`);

  // 2. Public Catalog APIs
  console.log("\n--- 2. LIVE CATALOG & CATEGORY APIs ---");
  const prodRes = await checkUrl("Live Products API", `${BASE_URL}/api/products`);
  if (prodRes && prodRes.ok) {
    const prodData = await prodRes.json();
    const count = (prodData.products || prodData).length || 0;
    console.log(`       Verified ${count} live products available in production catalog.`);
  }

  const catRes = await checkUrl("Live Categories API", `${BASE_URL}/api/categories`);
  if (catRes && catRes.ok) {
    const catData = await catRes.json();
    const catCount = (catData.categories || catData).length || 0;
    console.log(`       Verified ${catCount} live categories.`);
  }

  // 3. Security Gates on Live Cloud Functions
  console.log("\n--- 3. LIVE BACKEND SECURITY GATES ---");
  // Negative check on OTP request (invalid phone)
  const otpRes = await fetch(`${BASE_URL}/api/vendor/register-otp-request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: "security_probe@samaurmart.com", phone: "123" })
  });
  if (otpRes.status === 400) {
    console.log("[PASS] Live Vendor OTP validation gate active: rejected invalid phone with 400 Bad Request.");
    passed++;
  } else {
    console.error("[FAIL] Unexpected status on invalid phone probe:", otpRes.status);
    failed++;
  }

  // Negative check on unauthenticated vendor portal access
  const vdrSessRes = await fetch(`${BASE_URL}/api/vendor/verify-session`, {
    headers: { "Authorization": "Bearer vdr_sess_invalid_token_probe" }
  });
  if (vdrSessRes.status === 401) {
    console.log("[PASS] Live Vendor Auth Gate active: rejected forged token with 401 Unauthorized.");
    passed++;
  } else {
    console.error("[FAIL] Unexpected status on forged token probe:", vdrSessRes.status);
    failed++;
  }

  // Negative check on unauthenticated admin endpoint
  const admRes = await fetch(`${BASE_URL}/api/admin/vendors`, {
    headers: { "Authorization": "Bearer forged_admin_token" }
  });
  if (admRes.status === 401 || admRes.status === 403) {
    console.log(`[PASS] Live Admin Gate active: rejected unauthorized probe with ${admRes.status}.`);
    passed++;
  } else {
    console.error("[FAIL] Unexpected status on admin probe:", admRes.status);
    failed++;
  }

  // 4. Live Owner Admin Credential Gate (Non-destructive check)
  console.log("\n--- 4. LIVE OWNER AUTHENTICATION VERIFICATION ---");
  const adminLoginReq = await fetch(`${BASE_URL}/api/auth/admin-login-request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email_or_phone: "7268903804", password: "Admin@12345" })
  });
  const adminLoginData = await adminLoginReq.json();
  if (adminLoginReq.ok && adminLoginData.success) {
    console.log("[PASS] Live Owner credentials verified and phone verification challenge issued!");
    passed++;
  } else {
    console.error("[FAIL] Live Owner login request failed:", adminLoginData);
    failed++;
  }

  console.log("\n======================================================================");
  console.log(`PRODUCTION SMOKE TESTS: ${passed} PASSED, ${failed} FAILED.`);
  console.log("======================================================================");

  if (failed > 0) process.exit(1);
}

runLiveSmokeTests().catch(err => {
  console.error("Smoke test suite crashed:", err);
  process.exit(1);
});
