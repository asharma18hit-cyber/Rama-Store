// scripts/test_vendor_routes_local.js
const { spawn } = require("child_process");
const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

async function runLocalTests() {
  console.log("==================================================");
  console.log("TESTING VENDOR AUTHENTICATION & OTP ON LOCAL API");
  console.log("==================================================");

  const serverProc = spawn("node", ["scripts/test_local_server.js"]);
  serverProc.stdout.on("data", d => process.stdout.write("[SERVER] " + d.toString()));
  serverProc.stderr.on("data", d => process.stderr.write("[SERVER ERR] " + d.toString()));

  // Wait 2.5s for server boot
  await new Promise(r => setTimeout(r, 2500));

  const BASE = "http://127.0.0.1:8089/api";
  const testPhone = "9112233445";
  const testEmail = `test_merchant_${Date.now()}@example.com`;

  try {
    // Clean up any test doc from firestore
    const sa = require(path.join(__dirname, "../firebase_service_account.json"));
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(sa),
        projectId: "ma-store-949c7"
      });
    }
    const db = admin.firestore();
    await db.collection("vendor_otps").doc("reg_" + testPhone).delete().catch(() => {});
    const existingSnap = await db.collection("vendors").where("phone", "==", testPhone).get();
    for (const d of existingSnap.docs) await d.ref.delete().catch(() => {});

    // 1. Negative Test: Invalid phone
    console.log("\n1. Testing invalid phone number rejection...");
    const badPhoneRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: testEmail, phone: "123" })
    });
    console.log("Status:", badPhoneRes.status, await badPhoneRes.json());
    if (badPhoneRes.status !== 400) throw new Error("Expected status 400 for bad phone");
    console.log("[PASS] Invalid phone rejected.");

    // 2. Positive Test: Request OTP for valid mobile
    console.log("\n2. Requesting real OTP dispatch for", testPhone, "...");
    const reqRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: testEmail,
        phone: testPhone,
        business_name: "Test Organic Store",
        contact_name: "Test Merchant"
      })
    });
    const reqData = await reqRes.json();
    console.log("Status:", reqRes.status, reqData);
    if (!reqRes.ok || !reqData.success) throw new Error("OTP request failed");
    console.log("[PASS] OTP successfully created and dispatched via carrier engine.");

    // 3. Test Cooldown Rate Limiting (re-requesting within 30s)
    console.log("\n3. Testing 30-second cooldown rate limit...");
    const spamRes = await fetch(`${BASE}/vendor/register-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: testEmail,
        phone: testPhone,
        business_name: "Test Organic Store",
        contact_name: "Test Merchant"
      })
    });
    console.log("Status:", spamRes.status, await spamRes.json());
    if (spamRes.status !== 429) throw new Error("Expected status 429 on rapid resend");
    console.log("[PASS] Cooldown protection successfully blocked rapid spamming.");

    // Read generated OTP from Firestore to simulate user receiving SMS
    const otpDoc = await db.collection("vendor_otps").doc("reg_" + testPhone).get();
    if (!otpDoc.exists) throw new Error("vendor_otps doc missing in Firestore");
    const generatedOtp = otpDoc.data().code;
    console.log("\n[SIMULATION] User received carrier SMS with OTP code:", generatedOtp);

    // 4. Negative Test: Wrong OTP
    console.log("\n4. Testing wrong OTP code rejection...");
    const wrongOtpRes = await fetch(`${BASE}/vendor/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        business_name: "Test Organic Store",
        contact_name: "Test Merchant",
        email: testEmail,
        phone: testPhone,
        password: "VendorPassword123!",
        otp: "000000",
        address: "Shop 1, Main Market",
        pincode: "201301"
      })
    });
    console.log("Status:", wrongOtpRes.status, await wrongOtpRes.json());
    if (wrongOtpRes.status !== 400) throw new Error("Expected status 400 for wrong OTP");
    console.log("[PASS] Wrong OTP correctly rejected.");

    // 5. Positive Test: Complete Registration with received OTP
    console.log("\n5. Submitting registration with correct OTP...");
    const regRes = await fetch(`${BASE}/vendor/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        business_name: "Test Organic Store",
        contact_name: "Test Merchant",
        email: testEmail,
        phone: testPhone,
        password: "VendorPassword123!",
        otp: generatedOtp,
        address: "Shop 1, Main Market",
        pincode: "201301",
        categories: ["Groceries", "Organic Produce"],
        tax_id: "09ABCDE1234F1Z5"
      })
    });
    const regData = await regRes.json();
    console.log("Status:", regRes.status, regData);
    if (!regRes.ok || !regData.success) throw new Error("Registration failed");
    if (regData.status !== "submitted") throw new Error("Status should be submitted");
    const vendorId = regData.vendor_id;
    console.log("[PASS] Vendor registered with ID:", vendorId, "and status 'submitted'!");

    // Verify OTP was burned (single use)
    const burnedDoc = await db.collection("vendor_otps").doc("reg_" + testPhone).get();
    if (burnedDoc.exists) throw new Error("OTP was not burned after registration!");
    console.log("[PASS] OTP single-use burn verified (deleted from Firestore).");

    // 6. Test Login Gate: Pending vendor cannot log in
    console.log("\n6. Testing login gate for pending vendor (should be rejected with review notice)...");
    const pendingLogin = await fetch(`${BASE}/vendor/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email_or_phone: testPhone,
        password: "VendorPassword123!"
      })
    });
    const pendingData = await pendingLogin.json();
    console.log("Status:", pendingLogin.status, pendingData);
    if (pendingLogin.status !== 403 || !pendingData.error.includes("review")) {
      throw new Error("Expected 403 under review notice");
    }
    console.log("[PASS] Pending vendor cleanly prevented from portal login.");

    // 7. Simulate Owner Admin Approval
    console.log("\n7. Simulating Owner approving vendor application...");
    await db.collection("vendors").doc(vendorId).update({
      status: "approved",
      updated_at: new Date().toISOString()
    });
    console.log("[PASS] Vendor status updated to 'approved' in Firestore.");

    // 8. Test Approved Vendor Login
    console.log("\n8. Testing approved vendor login...");
    const approvedLogin = await fetch(`${BASE}/vendor/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email_or_phone: testPhone,
        password: "VendorPassword123!"
      })
    });
    const approvedData = await approvedLogin.json();
    console.log("Status:", approvedLogin.status, approvedData);
    if (!approvedLogin.ok || !approvedData.token) throw new Error("Approved vendor login failed");
    console.log("[PASS] Approved vendor logged in successfully! Session token:", approvedData.token.substring(0, 25) + "...");

    // Clean up
    await db.collection("vendors").doc(vendorId).delete().catch(() => {});
    await db.collection("vendor_sessions").doc(approvedData.token).delete().catch(() => {});
    console.log("\nALL BACKEND VENDOR AUTH & OTP TESTS PASSED CLEANLY!");
  } finally {
    serverProc.kill();
  }
}

runLocalTests().then(() => process.exit(0)).catch(err => {
  console.error("Test failure:", err);
  process.exit(1);
});
