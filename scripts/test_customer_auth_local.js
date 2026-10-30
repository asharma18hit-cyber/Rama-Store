// scripts/test_customer_auth_local.js
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

async function runCustomerAuthTest() {
  console.log("==================================================");
  console.log("VERIFYING CUSTOMER AUTHENTICATION & LOGIN FLOW");
  console.log("==================================================");

  const serverProc = spawn("node", ["scripts/test_local_server.js"]);
  await new Promise(r => setTimeout(r, 2500));

  const BASE = "http://127.0.0.1:8089/api";

  try {
    // 1. Customer OTP request
    console.log("\n1. Testing Customer Login OTP request...");
    const customerPhone = "98" + String(Date.now()).slice(-8);
    const otpRes = await fetch(`${BASE}/auth/login-otp-request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: customerPhone })
    });
    const otpData = await otpRes.json();
    console.log("Status:", otpRes.status, otpData);
    if (!otpRes.ok || !otpData.success) throw new Error("Customer OTP request failed");
    console.log("[PASS] Customer login OTP request succeeded.");

    // Retrieve generated OTP from Firestore
    const cleanId = customerPhone.toLowerCase();
    const otpDoc = await db.collection("otps").doc(cleanId).get();
    if (!otpDoc.exists) throw new Error("Customer OTP not found in Firestore");
    const realCustomerOtp = otpDoc.data().code;
    console.log(`[SIMULATION] Customer received SMS OTP: ${realCustomerOtp}`);

    // Verify Customer OTP
    console.log("\n2. Testing Customer Login OTP verification...");
    const verifyRes = await fetch(`${BASE}/auth/login-otp-verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email_or_phone: customerPhone, otp: realCustomerOtp })
    });
    const verifyData = await verifyRes.json();
    console.log("Status:", verifyRes.status, verifyData);
    if (!verifyRes.ok || !verifyData.success) throw new Error("Customer OTP verification failed");
    console.log("[PASS] Customer logged in successfully with user profile:", verifyData.user ? verifyData.user.name : "verified");

    // Clean up
    await db.collection("otps").doc(cleanId).delete().catch(() => {});
    const custUid = "u_" + cleanId;
    await db.collection("users").doc(custUid).delete().catch(() => {});

    console.log("\nALL CUSTOMER AUTHENTICATION CHECKS PASSED!");
  } finally {
    serverProc.kill();
  }
}

runCustomerAuthTest().then(() => process.exit(0)).catch(err => {
  console.error("Test failed:", err);
  process.exit(1);
});
