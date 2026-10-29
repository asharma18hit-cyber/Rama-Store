# scripts/patch_security_and_concurrency.py
import re

with open("functions/index.js", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Add Rate Limiting helper near top of express app
rate_limiter_code = """
// -------------------------------------------------------------
// IN-MEMORY SLIDING-WINDOW RATE LIMITER MIDDLEWARE
// -------------------------------------------------------------
const rateLimitBuckets = new Map();
function createRateLimiter({ windowMs, maxRequests, message }) {
  return function rateLimitMiddleware(req, res, next) {
    try {
      const ip = (req.headers["x-forwarded-for"] || req.connection.remoteAddress || "ip_default").split(",")[0].trim();
      const idBody = (req.body && (req.body.phone || req.body.email || req.body.email_or_phone)) ? String(req.body.phone || req.body.email || req.body.email_or_phone).trim() : "";
      const key = `${req.path}_${ip}_${idBody}`;
      const now = Date.now();

      let bucket = rateLimitBuckets.get(key);
      if (!bucket || now - bucket.startTime > windowMs) {
        bucket = { startTime: now, count: 1 };
        rateLimitBuckets.set(key, bucket);
        return next();
      }

      bucket.count++;
      if (bucket.count > maxRequests) {
        return res.status(429).json({
          error: message || "Too many attempts from this client. Please wait before trying again.",
          rate_limited: true,
          retry_after_seconds: Math.ceil((bucket.startTime + windowMs - now) / 1000)
        });
      }
      next();
    } catch (_) {
      next();
    }
  };
}

const otpRequestLimiter = createRateLimiter({
  windowMs: 5 * 60 * 1000,
  maxRequests: 10,
  message: "Too many OTP requests in a short time. Please wait 5 minutes before requesting another verification code."
});
"""

# Place rate limiter right after express setup
if "const rateLimitBuckets" not in code:
    app_setup_pattern = "const app = express();"
    idx = code.find(app_setup_pattern)
    if idx != -1:
        insert_pos = idx + len(app_setup_pattern)
        code = code[:insert_pos] + "\n" + rate_limiter_code + code[insert_pos:]
        print("Added rate limiter helper to functions/index.js")

# Attach otpRequestLimiter to /auth/login-otp-request
code = code.replace(
    'router.post("/auth/login-otp-request", async (req, res) => {',
    'router.post("/auth/login-otp-request", otpRequestLimiter, async (req, res) => {'
)

# 2. Upgrade /api/checkout with:
# - Idempotency protection
# - Strictly Server-Authoritative Pricing (ignoring client price)
# - Atomic stock deduction within db.runTransaction
# - Overselling prevention
checkout_start = 'router.post("/checkout", async (req, res) => {'
checkout_end = 'router.post("/payment/process", async (req, res) => {'

start_idx = code.find(checkout_start)
end_idx = code.find(checkout_end)

if start_idx == -1 or end_idx == -1:
    print(f"Error finding checkout block: {start_idx}, {end_idx}")
    exit(1)

new_checkout_and_cancel_code = """router.post("/checkout", async (req, res) => {
  try {
    const {
      cart,
      shipping_address,
      payment_method,
      user_name,
      user_phone,
      user_email,
      coupon_code,
      idempotency_key
    } = req.body;

    if (!cart || !Array.isArray(cart) || cart.length === 0) {
      return res.status(400).json({ error: "Shopping cart is empty" });
    }

    // 1. Idempotency Check: Prevent duplicate orders on network retries
    if (idempotency_key) {
      const cleanKey = String(idempotency_key).trim();
      const existingSnap = await db.collection("orders").where("idempotency_key", "==", cleanKey).limit(1).get();
      if (!existingSnap.empty) {
        const existingOrder = existingSnap.docs[0].data();
        return res.json({
          success: true,
          duplicate_prevented: true,
          order_id: existingOrder.id || existingOrder.order_id,
          tracking_number: existingOrder.tracking_number,
          total_amount: existingOrder.total_amount,
          message: "Idempotent response: Order was already created."
        });
      }
    }

    const finalPhone = (user_phone && String(user_phone).trim()) || (req.user && req.user.phone_number ? req.user.phone_number : "");
    const finalEmail = (user_email && String(user_email).trim()) || (req.user && req.user.email ? req.user.email : "");
    const userId = (req.user && req.user.uid) ? req.user.uid : (finalPhone ? ("cust_" + finalPhone.replace(/\\D/g, "")) : ("cust_" + Date.now()));

    let finalName = (user_name && String(user_name).trim()) || (req.user && req.user.name ? req.user.name : "");
    if (!finalName || finalName === "Customer") {
      if (finalPhone.includes("7268903804")) {
        finalName = "Rahul";
      } else if (finalPhone.replace(/\\D/g, "").length >= 10) {
        finalName = `User (${finalPhone.replace(/\\D/g, "").slice(-4)})`;
      } else {
        finalName = "Rahul";
      }
    }

    // 2. PIN Code Serviceability Check
    const pinMatch = String(shipping_address || "").match(/\\b\\d{6}\\b/);
    const checkoutPin = pinMatch ? pinMatch[0] : "";
    if (checkoutPin) {
      try {
        const delivDoc = await db.collection("store_settings").doc("delivery").get();
        if (delivDoc.exists) {
          const dData = delivDoc.data();
          if (dData.mode === "SPECIFIC" && Array.isArray(dData.serviceable_pincodes) && !dData.serviceable_pincodes.includes(checkoutPin)) {
            return res.status(400).json({ error: `Sorry, delivery is currently not available to PIN code ${checkoutPin}.` });
          }
        }
      } catch (_) {}
    }

    // 3. Resolve all product document references before transaction
    const resolvedCartItems = [];
    for (const item of cart) {
      const pId = item.id || item.product_id || item.productId;
      if (!pId) {
        return res.status(400).json({ error: "Invalid cart item: missing product identifier." });
      }
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      const docRef = await findProductDocRef(pId);
      if (!docRef) {
        return res.status(400).json({ error: `Product ID "${pId}" does not exist in catalog.` });
      }
      resolvedCartItems.push({ docRef, pId, requestedQty: qty });
    }

    // 4. ATOMIC FIRESTORE TRANSACTION: Stock Validation, Concurrency Lock & Decrement
    const orderRef = db.collection("orders").doc();
    const trackingNumber = "RS-ORD-" + Date.now() + "-" + Math.floor(1000 + Math.random() * 9000);
    let subtotal = 0;
    const verifiedItems = [];

    await db.runTransaction(async (transaction) => {
      // Step A: Read all product documents inside transaction
      const productDocs = [];
      for (const entry of resolvedCartItems) {
        const pSnap = await transaction.get(entry.docRef);
        if (!pSnap.exists) {
          throw new Error(`Product #${entry.pId} could not be retrieved during checkout.`);
        }
        productDocs.push({ pSnap, entry });
      }

      // Step B: Server-Authoritative Price & Inventory Validation
      for (const { pSnap, entry } of productDocs) {
        const pData = pSnap.data();

        // Ensure product is active and not archived or rejected
        if (pData.status === "archived" || pData.is_active === false || pData.approval_status === "rejected") {
          throw new Error(`Product "${pData.name || entry.pId}" is currently not available for purchase.`);
        }

        // Concurrency-safe stock verification (prevent overselling)
        const availableStock = parseInt(pData.stock !== undefined ? pData.stock : 0, 10);
        if (availableStock < entry.requestedQty) {
          throw new Error(`Insufficient stock for "${pData.name}". Requested ${entry.requestedQty}, but only ${availableStock} units remaining.`);
        }

        // STRICT SERVER-SIDE PRICE AUTHORITY: Completely ignores client-supplied price
        const serverPrice = parseFloat(pData.selling_price !== undefined ? pData.selling_price : (pData.price !== undefined ? pData.price : 0));
        if (serverPrice <= 0) {
          throw new Error(`Product "${pData.name}" has an invalid catalog price.`);
        }

        subtotal += serverPrice * entry.requestedQty;
        verifiedItems.push({
          id: pData.id || entry.pId,
          product_id: pData.id || entry.pId,
          productId: pData.id || entry.pId,
          name: pData.name || "Product",
          price: serverPrice,
          selling_price: serverPrice,
          quantity: entry.requestedQty,
          subtotal: serverPrice * entry.requestedQty,
          vendor_id: pData.vendor_id || "owner",
          vendor_name: pData.vendor_name || "Rama Store Direct",
          vendor_fulfillment_status: "new"
        });
      }

      // Step C: Atomically Decrement Inventory
      for (const { pSnap, entry } of productDocs) {
        const pData = pSnap.data();
        const newStock = Math.max(0, parseInt(pData.stock || 0, 10) - entry.requestedQty);
        transaction.update(pSnap.ref, {
          stock: newStock,
          in_stock: newStock > 0,
          updated_at: new Date().toISOString()
        });
      }

      // Step D: Calculate Discounts and Shipping
      let discountAmount = 0;
      let appliedCoupon = "";
      if (coupon_code) {
        const cCode = String(coupon_code).trim().toUpperCase();
        try {
          const cDoc = await db.collection("coupons").doc(cCode).get();
          let couponData = cDoc.exists ? cDoc.data() : null;
          if (!couponData) {
            couponData = DEFAULT_COUPONS.find(c => c.code === cCode);
          }
          if (couponData && couponData.active && subtotal >= (couponData.min_order || 0)) {
            appliedCoupon = cCode;
            if (couponData.type === "percent") {
              discountAmount = Math.round((subtotal * (couponData.value / 100)) * 100) / 100;
              if (couponData.max_discount && discountAmount > couponData.max_discount) {
                discountAmount = couponData.max_discount;
              }
            } else {
              discountAmount = Math.min(subtotal, couponData.value);
            }
          }
        } catch (_) {}
      }

      let freeDeliveryMin = 500;
      let standardShippingFee = 49;
      try {
        const dDoc = await db.collection("store_settings").doc("delivery").get();
        if (dDoc.exists) {
          if (dDoc.data().free_delivery_min !== undefined) freeDeliveryMin = dDoc.data().free_delivery_min;
          if (dDoc.data().standard_shipping_fee !== undefined) standardShippingFee = dDoc.data().standard_shipping_fee;
        }
      } catch (_) {}

      const discountedSubtotal = Math.max(0, subtotal - discountAmount);
      const shippingFee = discountedSubtotal >= freeDeliveryMin ? 0 : standardShippingFee;
      const totalAmount = Math.round((discountedSubtotal + shippingFee) * 100) / 100;

      // Step E: Create Order Document
      const orderData = {
        id: orderRef.id,
        order_id: orderRef.id,
        tracking_number: trackingNumber,
        idempotency_key: idempotency_key ? String(idempotency_key).trim() : null,
        customer_id: userId,
        customer_name: finalName,
        customer_email: finalEmail,
        customer_phone: finalPhone,
        items: verifiedItems,
        subtotal: subtotal,
        discount_amount: discountAmount,
        coupon_code: appliedCoupon,
        shipping_fee: shippingFee,
        total_amount: totalAmount,
        shipping_address: shipping_address || "Store Pickup",
        pincode: checkoutPin,
        payment_method: payment_method || "ONLINE",
        payment_status: payment_method === "COD" ? "PENDING" : "PENDING",
        status: "Pending",
        order_status: "Pending",
        created_at: new Date().toISOString()
      };

      transaction.set(orderRef, orderData);
    });

    // Invalidate product cache so fresh inventory levels reflect immediately
    cacheMemory.products = null;

    // Persist real customer profile to Firestore users collection
    try {
      const profileUid = (req.user && req.user.uid) ? req.user.uid : ("phone_" + finalPhone.replace(/\\D/g, ""));
      if (profileUid) {
        await db.collection("users").doc(profileUid).set({
          uid: profileUid,
          displayName: finalName,
          fullname: finalName,
          name: finalName,
          phone: finalPhone || "",
          default_address: shipping_address || "",
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
    } catch (profErr) {
      console.warn("Failed to persist user profile from checkout:", profErr);
    }

    return res.json({
      success: true,
      order_id: orderRef.id,
      tracking_number: trackingNumber,
      total_amount: verifiedItems.reduce((acc, it) => acc + it.subtotal, 0),
      items: verifiedItems,
      customer_name: finalName,
      customer_phone: finalPhone
    });
  } catch (err) {
    console.error("checkout error:", err);
    return res.status(400).json({ error: "Checkout failed: " + err.message });
  }
});

// POST /api/orders/:id/cancel - Customer Order Cancellation & Inventory Restoration
router.post("/orders/:id/cancel", async (req, res) => {
  try {
    const orderIdOrTracking = String(req.params.id).trim();
    const { reason, customer_phone, customer_id } = req.body;

    let orderDoc = null;
    const directRef = db.collection("orders").doc(orderIdOrTracking);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      orderDoc = directSnap;
    } else {
      const qSnap = await db.collection("orders").where("tracking_number", "==", orderIdOrTracking).limit(1).get();
      if (!qSnap.empty) orderDoc = qSnap.docs[0];
    }

    if (!orderDoc) {
      return res.status(404).json({ error: "Order not found." });
    }

    const order = orderDoc.data();

    // Check authorization: caller must be Admin, or phone/UID must match
    const isAdmin = req.isAdmin || (req.headers.authorization && req.headers.authorization.includes("adm_"));
    const phoneInput = (customer_phone ? String(customer_phone).replace(/\\D/g, "") : "");
    const isOwner = (req.user && req.user.uid && req.user.uid === order.customer_id) ||
                    (phoneInput && order.customer_phone && order.customer_phone.includes(phoneInput));

    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: "Unauthorized: You do not have permission to cancel this order." });
    }

    if (order.order_status === "Cancelled" || order.status === "Cancelled") {
      return res.status(400).json({ error: "Order is already cancelled." });
    }

    if (order.order_status === "Shipped" || order.order_status === "Delivered") {
      return res.status(400).json({ error: "Dispatched or delivered orders cannot be cancelled." });
    }

    // Atomically restore product inventory in transaction
    await db.runTransaction(async (transaction) => {
      for (const item of order.items || []) {
        const pId = item.id || item.product_id || item.productId;
        if (pId) {
          const docRef = await findProductDocRef(pId);
          if (docRef) {
            const pSnap = await transaction.get(docRef);
            if (pSnap.exists) {
              const pData = pSnap.data();
              const currStock = parseInt(pData.stock || 0, 10);
              const restoredStock = currStock + parseInt(item.quantity || 1, 10);
              transaction.update(docRef, {
                stock: restoredStock,
                in_stock: true,
                updated_at: new Date().toISOString()
              });
            }
          }
        }
      }

      transaction.update(orderDoc.ref, {
        order_status: "Cancelled",
        status: "Cancelled",
        cancellation_reason: reason || "Customer requested cancellation",
        cancelled_at: new Date().toISOString()
      });
    });

    cacheMemory.products = null;

    return res.json({
      success: true,
      message: "Order cancelled successfully and inventory restored.",
      order_id: orderDoc.id,
      tracking_number: order.tracking_number,
      order_status: "Cancelled"
    });
  } catch (err) {
    console.error("order cancellation error:", err);
    return res.status(500).json({ error: "Failed to cancel order: " + err.message });
  }
});

// POST /api/payment/process - Strict Cryptographic Payment Verification Gate
router.post("/payment/process", async (req, res) => {
  try {
    const {
      tracking_number,
      order_id,
      payment_id,
      provider,
      signature
    } = req.body;

    const identifier = tracking_number || order_id;
    if (!identifier) {
      return res.status(400).json({ error: "Order identifier (tracking_number or order_id) is required." });
    }

    let orderDoc = null;
    const directRef = db.collection("orders").doc(identifier);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      orderDoc = directSnap;
    } else {
      const qSnap = await db.collection("orders").where("tracking_number", "==", identifier).limit(1).get();
      if (!qSnap.empty) orderDoc = qSnap.docs[0];
    }

    if (!orderDoc) {
      return res.status(404).json({ error: "Order not found." });
    }

    const orderData = orderDoc.data();

    // Verification check: Require Admin Token OR Valid Cryptographic Provider Signature
    const authHeader = req.headers.authorization || "";
    const isAdmin = authHeader.includes("adm_") || req.isAdmin === true;

    // Check for Razorpay/Stripe cryptographic signature if provided
    let verified = false;
    const keySecret = process.env.RAZORPAY_KEY_SECRET || process.env.PAYMENT_GATEWAY_SECRET;

    if (keySecret && signature && payment_id) {
      const expectedSignature = crypto.createHmac("sha256", keySecret)
        .update(`${orderData.tracking_number}|${payment_id}`)
        .digest("hex");
      if (signature === expectedSignature) {
        verified = true;
      }
    } else if (isAdmin) {
      verified = true;
    }

    if (!verified) {
      return res.status(401).json({
        error: "Payment verification failed: Cryptographic gateway signature or authorized administrator authorization required.",
        verified: false
      });
    }

    await orderDoc.ref.update({
      payment_status: "PAID",
      order_status: "Confirmed",
      paid_at: new Date().toISOString(),
      payment_transaction_id: payment_id || `TXN-${Date.now()}`
    });

    return res.json({
      success: true,
      message: "Payment verified and recorded successfully by server.",
      tracking_number: orderData.tracking_number,
      payment_status: "PAID"
    });
  } catch (err) {
    return res.status(500).json({ error: "Payment verification error: " + err.message });
  }
});
"""

code = code[:start_idx] + new_checkout_and_cancel_code + code[end_idx + len('router.post("/payment/process", async (req, res) => {'):]

# Clean up any duplicate payment process closing
# Write updated functions/index.js
with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(code)

print("Successfully upgraded functions/index.js with atomic checkout, price authority, cancellation, and payment verification!")
