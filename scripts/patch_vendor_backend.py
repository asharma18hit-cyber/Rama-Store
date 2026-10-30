# scripts/patch_vendor_backend.py - Patches functions/vendor_routes.js
import re

with open("functions/vendor_routes.js", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Add sms_gateway import if not already present
if 'require("./sms_gateway")' not in code and "require('./sms_gateway')" not in code:
    code = code.replace(
        'const crypto = require("crypto");',
        'const crypto = require("crypto");\nconst { dispatchSmsOtp, normalizePhone } = require("./sms_gateway");'
    )

# 2. Replace router.post("/vendor/register-otp-request", ...) up to router.post("/vendor/register", ...)
reg_otp_new = '''  // POST /api/vendor/register-otp-request - Request OTP for Vendor Mobile Verification
  router.post("/vendor/register-otp-request", async (req, res) => {
    try {
      const { email, phone, business_name, contact_name } = req.body;
      if (!email || !email.includes("@")) {
        return res.status(400).json({ error: "A valid business email address is required." });
      }
      if (!phone || String(phone).replace(/\\D/g, "").length < 10) {
        return res.status(400).json({ error: "A valid 10-digit mobile number is required." });
      }

      const cleanEmail = email.trim().toLowerCase();
      const cleanPhone = String(phone).replace(/\\D/g, "").slice(-10);

      // Check for duplicate registered vendor
      const existingEmailSnap = await db.collection("vendors").where("email", "==", cleanEmail).limit(1).get();
      if (!existingEmailSnap.empty) {
        return res.status(400).json({ error: "A vendor account with this email address already exists. Please sign in." });
      }
      const existingPhoneSnap = await db.collection("vendors").where("phone", "==", cleanPhone).limit(1).get();
      if (!existingPhoneSnap.empty) {
        return res.status(400).json({ error: "A vendor account with this mobile number already exists. Please sign in." });
      }

      // Check cooldown (30 seconds)
      const otpDocId = "reg_" + cleanPhone;
      const existingOtpDoc = await db.collection("vendor_otps").doc(otpDocId).get();
      const now = Date.now();
      if (existingOtpDoc.exists) {
        const lastReq = existingOtpDoc.data().lastRequestedAt || 0;
        if (now - lastReq < 30 * 1000) {
          const remaining = Math.ceil((30 * 1000 - (now - lastReq)) / 1000);
          return res.status(429).json({
            error: `Please wait ${remaining} seconds before requesting a new verification code.`,
            cooldown_seconds: remaining
          });
        }
      }

      // Generate cryptographically random 6-digit code
      const otpCode = String(crypto.randomInt(100000, 999999));

      await db.collection("vendor_otps").doc(otpDocId).set({
        code: otpCode,
        phone: cleanPhone,
        email: cleanEmail,
        type: "registration",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastRequestedAt: now,
        expiresAt: now + 10 * 60 * 1000, // 10 minutes
        attempts: 0
      });

      // Dispatch real SMS via carrier gateway
      const smsResult = await dispatchSmsOtp(cleanPhone, otpCode, "Vendor Registration");
      console.log(`[Vendor Registration OTP] Dispatched for ${cleanPhone} via ${smsResult.provider || "gateway"}`);

      const maskedPhone = "+91 " + cleanPhone.slice(0, 2) + "******" + cleanPhone.slice(-2);

      return res.json({
        success: true,
        message: `Verification code sent to ${maskedPhone}.`,
        masked_phone: maskedPhone,
        raw_phone: cleanPhone,
        email: cleanEmail,
        expires_in_seconds: 600
      });
    } catch (err) {
      console.error("vendor register-otp-request error:", err);
      return res.status(500).json({ error: "Failed to send verification code: " + err.message });
    }
  });'''

pattern_reg_otp = re.compile(
    r'  // POST /api/vendor/register-otp-request.*?router\.post\("/vendor/register-otp-request",\s*async\s*\(req,\s*res\)\s*=>\s*\{.*?\n  \}\);',
    re.DOTALL
)

if pattern_reg_otp.search(code):
    code = pattern_reg_otp.sub(lambda m: reg_otp_new, code, count=1)
    print("Replaced register-otp-request successfully!")
else:
    print("WARNING: Could not find register-otp-request pattern!")

# 3. Replace router.post("/vendor/register", ...)
reg_new = '''  // POST /api/vendor/register - Complete Registration with Phone Verification
  router.post("/vendor/register", async (req, res) => {
    try {
      const {
        business_name,
        contact_name,
        email,
        phone,
        password,
        otp, // 6-digit OTP code (if using SMS route)
        idToken, // Firebase ID token (if verified via Firebase Phone Auth)
        firebase_id_token,
        address,
        pincode,
        categories,
        tax_id, // GSTIN or PAN
        bank_details,
        documents
      } = req.body;

      if (!business_name || !business_name.trim()) {
        return res.status(400).json({ error: "Business / Shop name is required." });
      }
      if (!contact_name || !contact_name.trim()) {
        return res.status(400).json({ error: "Contact person's full name is required." });
      }
      if (!email || !email.includes("@")) {
        return res.status(400).json({ error: "A valid business email address is required." });
      }
      if (!phone || String(phone).replace(/\\D/g, "").length < 10) {
        return res.status(400).json({ error: "A valid 10-digit mobile number is required." });
      }
      if (!password || password.length < 6) {
        return res.status(400).json({ error: "Password must be at least 6 characters." });
      }

      const cleanEmail = email.trim().toLowerCase();
      const cleanPhone = String(phone).replace(/\\D/g, "").slice(-10);

      // --- PHONE VERIFICATION (FIREBASE AUTH ID TOKEN OR BACKEND OTP) ---
      let phoneVerified = false;
      const tokenToVerify = idToken || firebase_id_token;

      if (tokenToVerify) {
        try {
          const decoded = await admin.auth().verifyIdToken(tokenToVerify);
          const tokenPhone = decoded.phone_number ? decoded.phone_number.replace(/\\D/g, "").slice(-10) : "";
          if (tokenPhone === cleanPhone) {
            phoneVerified = true;
          } else {
            return res.status(400).json({
              error: "Verified phone number does not match application phone number."
            });
          }
        } catch (tokErr) {
          console.warn("[Vendor Register] Firebase ID token verify failed:", tokErr.message);
        }
      }

      if (!phoneVerified) {
        const inputOtp = otp ? String(otp).trim() : "";
        if (!inputOtp || inputOtp.length !== 6 || !/^\\d{6}$/.test(inputOtp)) {
          return res.status(400).json({
            error: "Please enter the 6-digit verification code sent to your mobile."
          });
        }

        const otpDocId = "reg_" + cleanPhone;
        const otpDoc = await db.collection("vendor_otps").doc(otpDocId).get();

        if (!otpDoc.exists) {
          return res.status(400).json({
            error: "No verification code found. Please click 'Send OTP' to request a new code."
          });
        }

        const otpData = otpDoc.data();
        if (Date.now() > (otpData.expiresAt || 0)) {
          await otpDoc.ref.delete().catch(() => {});
          return res.status(400).json({
            error: "Verification code has expired. Please request a new code."
          });
        }

        const currentAttempts = otpData.attempts || 0;
        if (currentAttempts >= 3) {
          await otpDoc.ref.delete().catch(() => {});
          return res.status(429).json({
            error: "Too many failed attempts. Please request a new verification code."
          });
        }

        if (String(otpData.code).trim() === inputOtp) {
          phoneVerified = true;
          await otpDoc.ref.delete().catch(() => {});
        } else {
          await otpDoc.ref.update({ attempts: currentAttempts + 1 }).catch(() => {});
          return res.status(400).json({
            error: "Invalid verification code. Please check the code sent to your phone and try again."
          });
        }
      }

      if (!phoneVerified) {
        return res.status(400).json({
          error: "Mobile verification failed. Please verify your phone number to continue."
        });
      }

      // Check for duplicate vendor application
      const existingEmailSnap = await db.collection("vendors").where("email", "==", cleanEmail).limit(1).get();
      if (!existingEmailSnap.empty) {
        return res.status(400).json({ error: "A vendor account with this email already exists." });
      }
      const existingPhoneSnap = await db.collection("vendors").where("phone", "==", cleanPhone).limit(1).get();
      if (!existingPhoneSnap.empty) {
        return res.status(400).json({ error: "A vendor account with this phone number already exists." });
      }

      const { salt, hash } = hashPassword(password);
      const vendorId = "vdr_" + Date.now();
      const nowIso = new Date().toISOString();

      const vendorData = {
        id: vendorId,
        business_name: business_name.trim(),
        contact_name: contact_name.trim(),
        email: cleanEmail,
        phone: cleanPhone,
        phone_verified: true,
        email_verified: true,
        password_hash: hash,
        password_salt: salt,
        address: address ? String(address).trim() : "",
        pincode: pincode ? String(pincode).trim() : "",
        categories: Array.isArray(categories) ? categories : (categories ? String(categories).split(",").map(c => c.trim()) : []),
        tax_id: tax_id ? String(tax_id).trim().toUpperCase() : "",
        bank_details: typeof bank_details === "object" ? bank_details : {},
        documents: Array.isArray(documents) ? documents : [],
        status: "submitted", // Initial lifecycle state
        commission_rate: 10.0, // Default 10% marketplace commission
        auto_publish: false, // Default: every product requires Owner review
        rejection_reason: null,
        created_at: nowIso,
        updated_at: nowIso,
        audit_log: [{
          action: "registered_phone_verified",
          timestamp: nowIso,
          changed_by: contact_name.trim(),
          summary: "Vendor application submitted with verified phone number."
        }]
      };

      await db.collection("vendors").doc(vendorId).set(vendorData);

      return res.json({
        success: true,
        message: "Vendor application submitted successfully! Your account will be reviewed by the store owner.",
        vendor_id: vendorId,
        status: "submitted"
      });
    } catch (err) {
      console.error("vendor register error:", err);
      return res.status(500).json({ error: "Vendor registration failed: " + err.message });
    }
  });'''

pattern_reg = re.compile(
    r'  // POST /api/vendor/register - Step 2: Complete Registration.*?router\.post\("/vendor/register",\s*async\s*\(req,\s*res\)\s*=>\s*\{.*?\n  \}\);',
    re.DOTALL
)

if pattern_reg.search(code):
    code = pattern_reg.sub(lambda m: reg_new, code, count=1)
    print("Replaced vendor register successfully!")
else:
    print("WARNING: Could not find vendor register pattern!")

# 4. Clean up /vendor/login to be simple direct login
clean_login = '''  // POST /api/vendor/login - Direct, clean login for vendors
  router.post("/vendor/login", async (req, res) => {
    try {
      const { email_or_phone, password } = req.body;
      if (!email_or_phone || !password) {
        return res.status(400).json({ error: "Email or phone and password are required." });
      }

      const input = String(email_or_phone).trim().toLowerCase();
      const cleanPhone = input.replace(/\\D/g, "").slice(-10);

      let vendorDoc = null;
      if (input.includes("@")) {
        const snap = await db.collection("vendors").where("email", "==", input).limit(1).get();
        if (!snap.empty) vendorDoc = snap.docs[0];
      }
      if (!vendorDoc && cleanPhone.length === 10) {
        const snap = await db.collection("vendors").where("phone", "==", cleanPhone).limit(1).get();
        if (!snap.empty) vendorDoc = snap.docs[0];
      }

      if (!vendorDoc) {
        return res.status(401).json({ error: "No vendor account found with those credentials." });
      }

      const vendor = vendorDoc.data();
      const isValid = verifyPassword(password, vendor.password_salt, vendor.password_hash);
      if (!isValid) {
        return res.status(401).json({ error: "Incorrect password. Please verify and try again." });
      }

      // Check Lifecycle Status
      if (vendor.status === "submitted" || vendor.status === "under_review") {
        return res.status(403).json({
          success: false,
          status: vendor.status,
          error: "Your vendor application is currently under review by the store owner. You will be able to log in once approved."
        });
      }
      if (vendor.status === "rejected") {
        return res.status(403).json({
          success: false,
          status: "rejected",
          error: `Your vendor application was rejected: ${vendor.rejection_reason || "Please contact support."}`
        });
      }
      if (vendor.status === "suspended" || vendor.status === "deactivated") {
        return res.status(403).json({
          success: false,
          status: vendor.status,
          error: "Your vendor account has been suspended or deactivated. Please contact support."
        });
      }
      if (vendor.status !== "approved") {
        return res.status(403).json({
          success: false,
          status: vendor.status,
          error: `Vendor account is in status '${vendor.status}'. Access is restricted to approved vendors.`
        });
      }

      // Create secure session token
      const token = "vdr_sess_" + crypto.randomBytes(32).toString("hex");
      const now = Date.now();
      const sessionData = {
        token,
        vendor_id: vendorDoc.id,
        business_name: vendor.business_name,
        contact_name: vendor.contact_name,
        email: vendor.email,
        phone: vendor.phone,
        role: "vendor",
        createdAt: now,
        lastActivity: now,
        expiresAt: now + 24 * 60 * 60 * 1000
      };

      await db.collection("vendor_sessions").doc(token).set(sessionData);

      return res.json({
        success: true,
        message: "Login successful!",
        token,
        vendor: {
          id: vendorDoc.id,
          business_name: vendor.business_name,
          contact_name: vendor.contact_name,
          email: vendor.email,
          phone: vendor.phone,
          status: vendor.status,
          commission_rate: vendor.commission_rate || 10.0,
          auto_publish: Boolean(vendor.auto_publish)
        }
      });
    } catch (err) {
      console.error("vendor login error:", err);
      return res.status(500).json({ error: "Login failed: " + err.message });
    }
  });'''

pattern_login = re.compile(
    r'  // POST /api/vendor/login - Unified Login.*?router\.post\("/vendor/login",\s*async\s*\(req,\s*res\)\s*=>\s*\{.*?\n  \}\);',
    re.DOTALL
)

if pattern_login.search(code):
    code = pattern_login.sub(lambda m: clean_login, code, count=1)
    print("Replaced vendor login successfully!")
else:
    print("WARNING: Could not find vendor login pattern!")

# 5. Remove any leftover isMasterMfa
code = re.sub(
    r'const isMasterMfa = \["726890", "123456", "949268"\]\.includes\(inputOtp\);',
    'const isMasterMfa = false;',
    code
)

with open("functions/vendor_routes.js", "w", encoding="utf-8") as f:
    f.write(code)

print("functions/vendor_routes.js successfully updated!")
